import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/sync_status.dart';
import '../datasources/local_database_service.dart';

abstract interface class SyncRepository {
  Future<SyncStatus> syncNow();
}

class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl(this._databaseService, [this._apiClient]);

  static const _anonymousUserId = '00000000-0000-0000-0000-000000000000';

  final LocalDatabaseService _databaseService;
  final ApiClient? _apiClient;

  static const _remoteTables = <String, String>{
    'estados': ApiEndpoints.estados,
    'propiedades': ApiEndpoints.propiedades,
    'inquilinos': ApiEndpoints.inquilinos,
    'alquileres': ApiEndpoints.alquileres,
    'pagos': ApiEndpoints.pagos,
    'mantenimientos': ApiEndpoints.mantenimientos,
  };

  @override
  Future<SyncStatus> syncNow() async {
    final tables = _apiClient == null
        ? const ['propiedades', 'inquilinos', 'pagos']
        : _remoteTables.keys.toList(growable: false);
    final pending = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      pending[table] = await _databaseService.getPendingRows(table);
    }

    final syncErrors = _apiClient == null
        ? const <String>[]
        : await _syncRemote(tables, pending);

    if (_apiClient == null) {
      for (final entry in pending.entries) {
        for (final row in entry.value) {
          await _databaseService.logSync(
            entry.key,
            'sync',
            'success',
            'Fila ${row['id']} marcada como sincronizada localmente.',
          );
          await _databaseService.markSynced(entry.key, row['id'] as int);
        }
      }
    }

    final total = pending.values.fold<int>(0, (sum, rows) => sum + rows.length);

    if (total == 0) {
      return SyncStatus(
        isRunning: false,
        message: syncErrors.isEmpty
            ? 'Todo está sincronizado.'
            : 'Consulta remota con incidencias: ${syncErrors.join('; ')}',
        lastUpdatedAt: syncErrors.isEmpty ? null : DateTime.now(),
      );
    }

    return SyncStatus(
      isRunning: false,
      message: syncErrors.isEmpty
          ? 'Se sincronizaron $total registros locales.'
          : 'Se procesaron $total registros con incidencias: ${syncErrors.join('; ')}',
      lastUpdatedAt: DateTime.now(),
    );
  }

  Future<List<String>> _syncRemote(
    List<String> tables,
    Map<String, List<Map<String, dynamic>>> pending,
  ) async {
    final errors = <String>[];
    final remoteIds = <String, Set<int>>{};
    final dependencyUploads = <String, Set<int>>{};
    for (final table in tables) {
      late final List<Map<String, dynamic>> rows;
      try {
        rows = await _getRemoteRows(_remoteTables[table]!);
      } catch (error) {
        errors.add('$table (lectura: $error)');
        continue;
      }
      final pendingIds = pending[table]!
          .map((row) => _asInt(row['id']))
          .where((id) => id > 0)
          .toSet();
      remoteIds[table] = rows
          .map((row) => _asInt(row['id']))
          .where((id) => id > 0)
          .toSet();
      for (final row in rows) {
        final values = _remoteToLocal(table, row);
        if (values != null &&
            values['id'] is int &&
            values['id'] > 0 &&
            !pendingIds.contains(values['id'])) {
          try {
            await _databaseService.upsertSyncedRow(table, values);
          } catch (error) {
            errors.add('$table (guardado: $error)');
          }
        }
      }
    }

    for (final entry in pending.entries) {
      for (final row in entry.value) {
        final id = _asInt(row['id']);
        final dependencies = _parentReferences(entry.key, row);
        var dependenciesReady = true;
        for (final dependency in dependencies.entries) {
          final dependencyId = dependency.value ?? 0;
          if (dependencyId <= 0) continue;
          final ready = await _ensureRemoteParent(
            dependency.key,
            dependencyId,
            remoteIds,
            dependencyUploads,
            errors,
          );
          if (!ready) dependenciesReady = false;
        }
        if (!dependenciesReady) {
          errors.add('${entry.key}/$id (no se envió: faltan registros relacionados)');
          continue;
        }
        if (dependencyUploads[entry.key]?.contains(id) == true) continue;

        final path = _remoteTables[entry.key]!;
        final method = remoteIds[entry.key]?.contains(id) == true
            ? 'patch'
            : 'post';
        try {
          final response = method == 'patch'
              ? await _apiClient!.patch<dynamic>(
                  '${path.split('?').first}?id=eq.$id&Origen=eq.movil&usuario=eq.${row['usuario']}',
                  data: _localToRemote(entry.key, row),
                )
              : await _apiClient!.post<dynamic>(
                  '${path.split('?').first}?select=*',
                  data: _localToRemote(entry.key, row),
                );
          if (response.statusCode != null && response.statusCode! < 300) {
            await _databaseService.markSynced(entry.key, id);
            await _databaseService.logSync(
              entry.key,
              method,
              'success',
              'Fila $id enviada al API.',
            );
          }
        } catch (error) {
          errors.add('${entry.key}/$id ($method: $error)');
        }
      }
    }
    return errors;
  }

  Map<String, int?> _parentReferences(
    String table,
    Map<String, dynamic> row,
  ) => switch (table) {
    'alquileres' => {
      'propiedades': _asInt(row['propiedad_id']),
      'inquilinos': _asInt(row['inquilino_id']),
    },
    'pagos' => {
      'inquilinos': _asInt(row['id_inquilino']),
      'alquileres': _asInt(row['id_alquiler'] ?? row['alquiler_id']),
    },
    'mantenimientos' => {'propiedades': _asInt(row['propiedad_id'])},
    _ => const {},
  };

  Future<bool> _ensureRemoteParent(
    String table,
    int id,
    Map<String, Set<int>> remoteIds,
    Map<String, Set<int>> dependencyUploads,
    List<String> errors,
  ) async {
    if (remoteIds[table]?.contains(id) == true) return true;

    final localRow = await _databaseService.getRowById(table, id);
    if (localRow == null) {
      errors.add('$table/$id (no existe localmente y Supabase lo requiere)');
      return false;
    }

    for (final dependency in _parentReferences(table, localRow).entries) {
      final dependencyId = dependency.value ?? 0;
      if (dependencyId <= 0) continue;
      final ready = await _ensureRemoteParent(
        dependency.key,
        dependencyId,
        remoteIds,
        dependencyUploads,
        errors,
      );
      if (!ready) return false;
    }

    try {
      final response = await _apiClient!.post<dynamic>(
        _remoteTables[table]!.split('?').first,
        data: _localToRemote(table, localRow),
      );
      if (response.statusCode == null || response.statusCode! >= 300) {
        errors.add('$table/$id (no se pudo crear el registro relacionado)');
        return false;
      }
      remoteIds.putIfAbsent(table, () => <int>{}).add(id);
      dependencyUploads.putIfAbsent(table, () => <int>{}).add(id);
      await _databaseService.markSynced(table, id);
      await _databaseService.logSync(
        table,
        'post',
        'success',
        'Fila $id enviada como dependencia de otro registro.',
      );
      return true;
    } catch (error) {
      errors.add('$table/$id (dependencia: $error)');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _getRemoteRows(String path) async {
    final body = (await _apiClient!.get<dynamic>(path)).data;
    if (body is List) return body.whereType<Map<String, dynamic>>().toList();
    if (body is Map<String, dynamic> && body['data'] is List) {
      return (body['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Map<String, dynamic> _localToRemote(String table, Map<String, dynamic> row) {
    switch (table) {
      case 'estados':
        return {
          if (_asInt(row['id']) > 0) 'id': _asInt(row['id']),
          'Descripcion': row['Descripcion'],
          'tabla': row['tabla'],
          'Origen': row['Origen'] ?? 'movil',
          'usuario': row['usuario'] ?? _anonymousUserId,
        };
      case 'propiedades':
        return {
          if (_asInt(row['id']) > 0) 'id': _asInt(row['id']),
          'nombre': row['nombre'],
          'direccion': row['direccion'],
          'precioMensual': row['precio_mensual'],
          'notas': row['notas'],
          'estado': row['estado'],
          'Origen': row['Origen'] ?? 'movil',
          'usuario': row['usuario'] ?? _anonymousUserId,
        };
      case 'inquilinos':
        return {
          if (_asInt(row['id']) > 0) 'id': _asInt(row['id']),
          'nombreApellido': row['nombre_apellido'],
          'correo': row['correo'],
          'fechaInicioContrato': row['fecha_inicio_contrato'],
          'fechaPagos': row['fecha_pagos'],
          'Origen': row['Origen'] ?? 'movil',
          'usuario': row['usuario'] ?? _anonymousUserId,
        };
      case 'pagos':
        return {
          if (_asInt(row['id']) > 0) 'id': _asInt(row['id']),
          'idInquilino': _asInt(row['id_inquilino']),
          'fechaPago': row['fecha_pago'],
          'monto': row['monto'],
          'idAlquiler': _asNullableInt(
            row['id_alquiler'] ?? row['alquiler_id'],
          ),
          'periodo': row['periodo'],
          'estado': row['estado'],
          'Origen': row['Origen'] ?? 'movil',
          'usuario': row['usuario'] ?? _anonymousUserId,
        };
      case 'alquileres':
        return {
          if (_asInt(row['id']) > 0) 'id': _asInt(row['id']),
          'propiedadID': row['propiedad_id'],
          'inquilinoID': row['inquilino_id'],
          'fechaInicio': row['fecha_inicio'],
          'fechaFin': row['fecha_fin'],
          'importe': row['importe'],
          'montoPago': row['montoPago'],
          'cantidadDepositos': row['cantidadDepositos'],
          'diaPago': row['diaPago'],
          'cantidadMeses': row['cantidadMeses'],
          'estado': row['estado'],
          'Origen': row['Origen'] ?? 'movil',
          'usuario': row['usuario'] ?? _anonymousUserId,
        };
      default:
        return {
          if (_asInt(row['id']) > 0) 'id': _asInt(row['id']),
          'propiedadID': row['propiedad_id'],
          'descripcion': row['descripcion'],
          'fecha': row['fecha'],
          'costo': row['costo'],
          'estado': _maintenanceStatusId(row['estado']),
          'Origen': row['Origen'] ?? 'movil',
          'usuario': row['usuario'] ?? _anonymousUserId,
        };
    }
  }

  Map<String, dynamic>? _remoteToLocal(String table, Map<String, dynamic> row) {
    final id = _asInt(row['id']);
    if (id <= 0) return null;
    switch (table) {
      case 'estados':
        return {
          'id': id,
          'Descripcion': row['Descripcion']?.toString() ?? '',
          'tabla': row['tabla']?.toString() ?? '',
          'Origen': row['Origen']?.toString() ?? 'movil',
          'usuario': row['usuario']?.toString() ?? _anonymousUserId,
          'created_at': row['created_at']?.toString(),
        };
      case 'propiedades':
        return {
          'id': id,
          'nombre': row['nombre']?.toString() ?? '',
          'direccion': row['direccion']?.toString() ?? '',
          'estado': _asInt(row['estado']),
          'precio_mensual': _asDouble(row['precioMensual']),
          'notas': row['notas']?.toString() ?? '',
          'Origen': row['Origen']?.toString() ?? 'movil',
          'usuario': row['usuario']?.toString() ?? _anonymousUserId,
          'created_at': row['created_at']?.toString(),
        };
      case 'inquilinos':
        return {
          'id': id,
          'nombre_apellido': row['nombreApellido']?.toString() ?? '',
          'correo': row['correo']?.toString(),
          'fecha_inicio_contrato': row['fechaInicioContrato']?.toString() ?? '',
          'fecha_pagos': _asInt(row['fechaPagos']),
          'Origen': row['Origen']?.toString() ?? 'movil',
          'usuario': row['usuario']?.toString() ?? _anonymousUserId,
          'created_at': row['created_at']?.toString(),
        };
      case 'pagos':
        return {
          'id': id,
          'id_inquilino': row['idInquilino']?.toString() ?? '',
          'id_alquiler': row['idAlquiler'],
          'alquiler_id': row['idAlquiler'],
          'periodo': row['periodo']?.toString(),
          'fecha_pago': row['fechaPago']?.toString() ?? '',
          'monto': _asDouble(row['monto']),
          'estado': row['estado']?.toString() ?? 'Pendiente',
          'Origen': row['Origen']?.toString() ?? 'movil',
          'usuario': row['usuario']?.toString() ?? _anonymousUserId,
          'created_at': row['created_at']?.toString(),
        };
      case 'alquileres':
        return {
          'id': id,
          'propiedad_id': _asInt(row['propiedadID']),
          'inquilino_id': _asInt(row['inquilinoID']),
          'fecha_inicio': row['fechaInicio']?.toString() ?? '',
          'fecha_fin': row['fechaFin']?.toString(),
          'importe': _asDouble(row['importe']),
          'montoPago': _asDouble(row['montoPago']),
          'cantidadDepositos': _asInt(row['cantidadDepositos']),
          'diaPago': _asInt(row['diaPago'], fallback: 1),
          'cantidadMeses': _asInt(row['cantidadMeses']),
          'estado': row['estado']?.toString() ?? 'Pendiente',
          'Origen': row['Origen']?.toString() ?? 'movil',
          'usuario': row['usuario']?.toString() ?? _anonymousUserId,
          'created_at': row['created_at']?.toString(),
        };
      default:
        return {
          'id': id,
          'propiedad_id': _asInt(row['propiedadID']),
          'descripcion': row['descripcion']?.toString() ?? '',
          'fecha': row['fecha']?.toString() ?? '',
          'costo': _asDouble(row['costo']),
          'estado': _maintenanceStatusName(row['estado']),
          'Origen': row['Origen']?.toString() ?? 'movil',
          'usuario': row['usuario']?.toString() ?? _anonymousUserId,
          'created_at': row['created_at']?.toString(),
        };
    }
  }

  static int _asInt(dynamic value, {int fallback = 0}) => switch (value) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value) ?? fallback,
    _ => fallback,
  };

  static double _asDouble(dynamic value) => switch (value) {
    final num value => value.toDouble(),
    final String value => double.tryParse(value) ?? 0,
    _ => 0,
  };

  static int? _asNullableInt(dynamic value) => switch (value) {
    null => null,
    final int value => value,
    final num value => value.toInt(),
    final String value when value.trim().isEmpty => null,
    final String value => int.tryParse(value),
    _ => null,
  };

  static int _maintenanceStatusId(dynamic value) => switch (
    value?.toString().toLowerCase()
  ) {
    'en proceso' => 6,
    'finalizado' || 'completado' => 7,
    'cancelado' => 8,
    _ => 5,
  };

  static String _maintenanceStatusName(dynamic value) => switch (
    _asInt(value)
  ) {
    6 => 'En proceso',
    7 => 'Finalizado',
    8 => 'Cancelado',
    _ => 'Pendiente',
  };
}
