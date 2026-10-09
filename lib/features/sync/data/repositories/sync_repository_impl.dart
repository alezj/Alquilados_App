import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/sync_status.dart';
import '../datasources/local_database_service.dart';

abstract interface class SyncRepository {
  Future<SyncStatus> syncNow();
}

class SyncRepositoryImpl implements SyncRepository {
  SyncRepositoryImpl(this._databaseService, [this._apiClient]);

  final LocalDatabaseService _databaseService;
  final ApiClient? _apiClient;

  static const _remoteTables = <String, String>{
    'propiedades': ApiEndpoints.propiedades,
    'inquilinos': ApiEndpoints.inquilinos,
    'pagos': ApiEndpoints.pagos,
    'alquileres': ApiEndpoints.alquileres,
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
        final path = _remoteTables[entry.key]!;
        final method = remoteIds[entry.key]?.contains(id) == true
            ? 'put'
            : 'post';
        try {
          final response = method == 'put'
              ? await _apiClient!.put<dynamic>(
                  '$path/$id',
                  data: _localToRemote(entry.key, row),
                )
              : await _apiClient!.post<dynamic>(
                  path,
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

  Future<List<Map<String, dynamic>>> _getRemoteRows(String path) async {
    final body = (await _apiClient!.get<dynamic>(path)).data;
    if (body is Map<String, dynamic> && body['data'] is List) {
      return (body['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Map<String, dynamic> _localToRemote(String table, Map<String, dynamic> row) {
    switch (table) {
      case 'propiedades':
        return {
          'nombre': row['nombre'],
          'direccion': row['direccion'],
          'precioMensual': row['precio_mensual'],
          'notas': row['notas'],
          'estado': row['estado'],
        };
      case 'inquilinos':
        return {
          'nombreApellido': row['nombre_apellido'],
          'correo': row['correo'],
          'fechaInicioContrato': row['fecha_inicio_contrato'],
          'fechaPagos': row['fecha_pagos'],
        };
      case 'pagos':
        return {
          'idInquilino': row['id_inquilino'],
          'fechaPago': row['fecha_pago'],
          'monto': row['monto'],
        };
      case 'alquileres':
        return {
          'propiedadID': row['propiedad_id'],
          'inquilinoID': row['inquilino_id'],
          'fechaInicio': row['fecha_inicio'],
          'fechaFin': row['fecha_fin'],
          'importe': row['importe'],
          'montoPago': row['montoPago'],
          'cantidadDepositos': row['cantidadDepositos'],
          'diaPago': row['diaPago'],
          'estado': row['estado'],
        };
      default:
        return {
          'propiedadID': row['propiedad_id'],
          'descripcion': row['descripcion'],
          'fecha': row['fecha'],
          'costo': row['costo'],
          'estado': row['estado'],
        };
    }
  }

  Map<String, dynamic>? _remoteToLocal(String table, Map<String, dynamic> row) {
    final id = _asInt(row['id']);
    if (id <= 0) return null;
    switch (table) {
      case 'propiedades':
        return {
          'id': id,
          'nombre': row['nombre']?.toString() ?? '',
          'direccion': row['direccion']?.toString() ?? '',
          'estado': _asInt(row['estado']),
          'precio_mensual': _asDouble(row['precioMensual']),
          'notas': row['notas']?.toString() ?? '',
        };
      case 'inquilinos':
        return {
          'id': id,
          'nombre_apellido': row['nombreApellido']?.toString() ?? '',
          'correo': row['correo']?.toString(),
          'fecha_inicio_contrato': row['fechaInicioContrato']?.toString() ?? '',
          'fecha_pagos': _asInt(row['fechaPagos']),
        };
      case 'pagos':
        return {
          'id': id,
          'id_inquilino': row['idInquilino']?.toString() ?? '',
          'fecha_pago': row['fechaPago']?.toString() ?? '',
          'monto': _asDouble(row['monto']),
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
          'estado': row['estado']?.toString() ?? 'Pendiente',
        };
      default:
        return {
          'id': id,
          'propiedad_id': _asInt(row['propiedadID']),
          'descripcion': row['descripcion']?.toString() ?? '',
          'fecha': row['fecha']?.toString() ?? '',
          'costo': _asDouble(row['costo']),
          'estado': row['estado']?.toString() ?? 'Pendiente',
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
}
