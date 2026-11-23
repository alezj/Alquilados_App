import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/sync_status.dart';
import '../datasources/crm_sync_store.dart';
import '../datasources/local_database_service.dart';

abstract interface class SyncRepository {
  Future<SyncStatus> syncNow({String? tenant, String? companyId});
  Future<SyncStatus> pullCrm({required String tenant, String? companyId});
  Future<SyncStatus> pullProductionTenants({
    required String tenant,
    String? companyId,
  });
}

class _CompanyTenants {
  _CompanyTenants(
    this.tenant,
    this.companyId,
    this.remoteIds,
    this.localByRemote,
    this.status,
  ) : remoteByLocal = localByRemote.map(
        (remote, local) => MapEntry(local, remote),
      );

  final String tenant;
  final String companyId;
  final Set<int> remoteIds;
  final Map<int, int> localByRemote;
  final Map<int, int> remoteByLocal;
  final SyncStatus status;
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
  Future<SyncStatus> pullProductionTenants({
    required String tenant,
    String? companyId,
  }) async => (await _loadProductionTenants(tenant, companyId)).status;

  Future<_CompanyTenants> _loadProductionTenants(
    String tenant,
    String? companyId,
  ) async {
    final client = _apiClient!;
    if (_databaseService.tenantKey != tenant) {
      throw StateError('La empresa activa cambió.');
    }
    final db = await _databaseService.database;
    final company = companyId ?? await _resolveCompany(client, tenant);
    final snapshot = <int, Map<String, Object?>>{};
    const pageSize = 100;
    var lastId = 0;
    while (true) {
      final response = await client.get<List<dynamic>>(
        'inquilinos',
        queryParameters: {
          'select': 'id,nombreApellido,correo,telefono,fechaInicioContrato,fechaPagos,created_at,Origen,usuario,company_id',
          'company_id': 'eq.$company',
          'id': 'gt.$lastId',
          'order': 'id.asc',
          'limit': pageSize,
        },
      );
      final rows = response.data!;
      for (final item in rows) {
        final row = item as Map<String, dynamic>;
        final id = _asInt(row['id']);
        if (id <= lastId || row['company_id'] != company) {
          throw const FormatException(
            'El servidor devolvió un inquilino fuera de la consulta.',
          );
        }
        lastId = id;
        final values = _remoteToLocal('inquilinos', row)!..remove('id');
        snapshot[id] = {...values, 'sync_state': 'synced'};
      }
      if (rows.length < pageSize) break;
    }
    if (_databaseService.tenantKey != tenant) {
      throw StateError('La empresa activa cambió.');
    }
    final result = await CrmSyncStore().applyTenantSnapshot(db, snapshot);
    if (result.applied > 0) _databaseService.notifyCrmChanges();
    return _CompanyTenants(
      tenant,
      company,
      snapshot.keys.toSet(),
      result.localByRemote,
      SyncStatus(
        isRunning: false,
        message: result.pending > 0
            ? 'Inquilinos: ${result.applied} cambios aplicados y ${result.pending} pendientes de revisar.'
            : result.applied > 0
            ? 'Inquilinos: ${result.applied} cambios aplicados.'
            : 'Inquilinos al día.',
        lastUpdatedAt: DateTime.now(),
        localChanges: result.applied,
      ),
    );
  }

  @override
  Future<SyncStatus> pullCrm({
    required String tenant,
    String? companyId,
  }) async {
    final client = _apiClient!;
    final store = CrmSyncStore();
    if (_databaseService.tenantKey != tenant) {
      throw StateError('La empresa activa cambió.');
    }
    final db = await _databaseService.database;
    final company = companyId ?? await _resolveCrmCompany(client, tenant);
    const pageSize = 100;
    var applied = 0;
    var pending = 0;
    var interrupted = false;
    try {
      while (true) {
        final cursor = await store.cursor(db);
        final response = await client.get<List<dynamic>>(
          'mobile_crm_change_feed',
          queryParameters: {
            'select': 'resource,remote_id,revision,record',
            'company_id': 'eq.$company',
            'revision': 'gt.$cursor',
            'order': 'revision.asc',
            'limit': pageSize,
          },
        );
        if (_databaseService.tenantKey != tenant) {
          throw StateError('La empresa activa cambió.');
        }
        final rows = response.data!;
        final result = await store.apply(db, rows.map(_crmChange).toList());
        applied += result.applied;
        pending = result.pending;
        if (rows.length < pageSize) break;
      }
    } catch (_) {
      if (applied == 0) rethrow;
      interrupted = true;
    } finally {
      if (applied > 0) _databaseService.notifyCrmChanges();
    }

    return SyncStatus(
      isRunning: false,
      message: interrupted
          ? 'CRM: $applied cambios aplicados. La descarga continuará en el próximo intento.'
          : pending > 0
          ? 'CRM: $applied cambios aplicados. $pending en espera por ediciones locales o registros relacionados.'
          : applied == 0
          ? 'CRM al día. No hay cambios nuevos.'
          : 'CRM: $applied cambios aplicados.',
      lastUpdatedAt: interrupted ? null : DateTime.now(),
      localChanges: applied,
    );
  }

  Future<String> _resolveCrmCompany(ApiClient client, String tenant) async {
    const prefix = 'test_';
    if (!tenant.startsWith(prefix)) {
      throw StateError('Empresa de pruebas inválida.');
    }
    return _resolveCompany(client, tenant.substring(prefix.length));
  }

  Future<String> _resolveCompany(ApiClient client, String slug) async {
    final response = await client.get<List<dynamic>>(
      'companies',
      queryParameters: {
        'select': 'id',
        'slug': 'eq.$slug',
        'status': 'eq.active',
        'limit': 1,
      },
    );
    final company = (response.data?.firstOrNull as Map?)?['id'] as String?;
    if (company == null) {
      throw StateError('No se pudo resolver la empresa activa.');
    }
    return company;
  }

  CrmChange _crmChange(dynamic item) {
    final change = item as Map<String, dynamic>;
    final resource = change['resource'] as String;
    final remoteId = _asInt(change['remote_id']);
    final revision = _asInt(change['revision']);
    if (!CrmSyncStore.resources.contains(resource) ||
        remoteId <= 0 ||
        revision <= 0) {
      throw const FormatException('Cambio del CRM inválido.');
    }

    final record = change['record'] as Map<String, dynamic>?;
    Map<String, dynamic>? values;
    if (record != null) {
      values = _remoteToLocal(resource, record)!..remove('id');
      if (resource == 'inquilinos' && values['correo'] == null) {
        values['correo'] = record['email']?.toString();
      }
      if (resource == 'alquileres') {
        values['importe'] = _asDouble(record['importe'] ?? record['montoPago']);
        values['estado'] = _crmRentalStatus(record);
      }
      if (resource == 'pagos') {
        final paidDate = record['fechaPago']?.toString().trim() ?? '';
        values['fecha_pago'] = paidDate.isEmpty
            ? record['fechaVencimiento']
            : paidDate;
        values['estado'] = switch (record['estado']
            ?.toString()
            .trim()
            .toLowerCase()) {
          'pagado' || 'paid' || 'completado' || 'completada' => 'pagado',
          'vencido' || 'atrasado' || 'overdue' => 'vencido',
          null || '' => 'pendiente',
          final estado => estado,
        };
      }
      values['sync_state'] = 'synced';
      values['synced_at'] = DateTime.now().toUtc().toIso8601String();
    }
    return (
      resource: resource,
      remoteId: remoteId,
      revision: revision,
      values: values,
    );
  }

  String _crmRentalStatus(Map<String, dynamic> record) {
    switch (record['estado']?.toString().trim().toLowerCase()) {
      case 'activo':
        return 'Activo';
      case 'finalizado':
        return 'Finalizado';
      case 'cancelado':
        return 'Cancelado';
      case 'pendiente':
        return 'Pendiente';
    }
    final start = DateTime.tryParse(record['fechaInicio']?.toString() ?? '');
    final end = DateTime.tryParse(record['fechaFin']?.toString() ?? '');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (end != null && end.isBefore(today)) return 'Finalizado';
    return start == null || start.isAfter(today) ? 'Pendiente' : 'Activo';
  }

  @override
  Future<SyncStatus> syncNow({String? tenant, String? companyId}) async {
    final scope = tenant == null
        ? null
        : await _loadProductionTenants(tenant, companyId);
    final tables = _apiClient == null
        ? const ['propiedades', 'inquilinos', 'pagos']
        : _remoteTables.keys.toList(growable: false);
    final pending = <String, List<Map<String, dynamic>>>{};
    for (final table in tables) {
      _checkScope(scope);
      pending[table] = await _databaseService.getPendingRows(table);
    }

    final syncErrors = _apiClient == null
        ? const <String>[]
        : await _syncRemote(tables, pending, scope: scope);

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
            ? scope?.status.message ?? 'Todo está sincronizado.'
            : 'Consulta remota con incidencias: ${syncErrors.join('; ')}',
        lastUpdatedAt: syncErrors.isEmpty ? null : DateTime.now(),
        localChanges: scope?.status.localChanges ?? 0,
      );
    }

    return SyncStatus(
      isRunning: false,
      message: syncErrors.isEmpty
          ? 'Se sincronizaron $total registros locales.'
          : 'Se procesaron $total registros con incidencias: ${syncErrors.join('; ')}',
      lastUpdatedAt: DateTime.now(),
      localChanges: scope?.status.localChanges ?? 0,
    );
  }

  Future<List<String>> _syncRemote(
    List<String> tables,
    Map<String, List<Map<String, dynamic>>> pending, {
    _CompanyTenants? scope,
  }) async {
    final errors = <String>[];
    final remoteIds = <String, Set<int>>{};
    final dependencyUploads = <String, Set<int>>{};
    for (final table in tables) {
      if (scope != null && table == 'inquilinos') {
        remoteIds[table] = {...scope.remoteIds};
        continue;
      }
      late final List<Map<String, dynamic>> rows;
      try {
        rows = await _getRemoteRows(
          _withCompany(_remoteTables[table]!, table, scope),
        );
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
          final reference = _tenantReferenceKey(table);
          final remoteTenant = _asInt(values[reference]);
          if (scope != null && reference != null && remoteTenant > 0) {
            final localTenant = scope.localByRemote[remoteTenant];
            if (localTenant == null) {
              errors.add(
                '$table/${values['id']} (falta el inquilino autorizado)',
              );
              continue;
            }
            values[reference] = localTenant;
          }
          try {
            _checkScope(scope);
            await _databaseService.upsertSyncedRow(table, values);
          } catch (error) {
            errors.add('$table (guardado: $error)');
          }
        }
      }
    }

    for (final entry in pending.entries) {
      for (final row in entry.value) {
        _checkScope(scope);
        final id = _asInt(row['id']);
        if (scope != null &&
            entry.key == 'inquilinos' &&
            (scope.remoteByLocal.containsKey(id) ||
                scope.remoteIds.contains(id))) {
          errors.add('inquilinos/$id (se conservó el cambio local)');
          continue;
        }
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
            scope: scope,
          );
          if (!ready) dependenciesReady = false;
        }
        if (!dependenciesReady) {
          errors.add(
            '${entry.key}/$id (no se envió: faltan registros relacionados)',
          );
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
                  _withCompany(
                    '${path.split('?').first}?id=eq.$id&Origen=eq.movil&usuario=eq.${row['usuario']}',
                    entry.key,
                    scope,
                  ),
                  data: _scopedRemotePayload(entry.key, row, scope),
                )
              : await _apiClient!.post<dynamic>(
                  '${path.split('?').first}?select=*',
                  data: _scopedRemotePayload(entry.key, row, scope),
                );
          if (response.statusCode != null && response.statusCode! < 300) {
            _checkScope(scope);
            if (scope != null &&
                method == 'patch' &&
                response.data is List &&
                (response.data as List).isEmpty) {
              errors.add(
                '${entry.key}/$id (el servidor no confirmó el cambio)',
              );
              continue;
            }
            remoteIds.putIfAbsent(entry.key, () => <int>{}).add(id);
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

  void _checkScope(_CompanyTenants? scope) {
    if (scope != null && _databaseService.tenantKey != scope.tenant) {
      throw StateError('La empresa activa cambió.');
    }
  }

  String? _tenantReferenceKey(String table) => switch (table) {
    'alquileres' => 'inquilino_id',
    'pagos' => 'id_inquilino',
    _ => null,
  };

  String _withCompany(String path, String table, _CompanyTenants? scope) =>
      scope == null || table == 'estados'
      ? path
      : '$path&company_id=eq.${scope.companyId}';

  Map<String, dynamic> _scopedRemotePayload(
    String table,
    Map<String, dynamic> row,
    _CompanyTenants? scope,
  ) {
    if (scope == null || table == 'estados') return _localToRemote(table, row);
    final reference = _tenantReferenceKey(table);
    final remoteTenant = scope.remoteByLocal[_asInt(row[reference])];
    return {
      ..._localToRemote(table, {
        ...row,
        if (reference != null && remoteTenant != null) reference: remoteTenant,
      }),
      'company_id': scope.companyId,
    };
  }

  Map<String, int?> _parentReferences(String table, Map<String, dynamic> row) =>
      switch (table) {
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
    List<String> errors, {
    _CompanyTenants? scope,
  }) async {
    _checkScope(scope);
    if (scope != null && table == 'inquilinos') {
      if (scope.remoteByLocal.containsKey(id)) return true;
      if (scope.remoteIds.contains(id)) return false;
    }
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
        scope: scope,
      );
      if (!ready) return false;
    }

    try {
      final response = await _apiClient!.post<dynamic>(
        _remoteTables[table]!.split('?').first,
        data: _scopedRemotePayload(table, localRow, scope),
      );
      if (response.statusCode == null || response.statusCode! >= 300) {
        errors.add('$table/$id (no se pudo crear el registro relacionado)');
        return false;
      }
      remoteIds.putIfAbsent(table, () => <int>{}).add(id);
      dependencyUploads.putIfAbsent(table, () => <int>{}).add(id);
      _checkScope(scope);
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
          'telefono': row['telefono'],
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
          'diasProrroga': row['diasProrroga'] ?? 0,
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
          'telefono': row['telefono']?.toString(),
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
          'diasProrroga': _asInt(row['diasProrroga']),
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

  static int _maintenanceStatusId(dynamic value) =>
      switch (value?.toString().toLowerCase()) {
        'en proceso' => 6,
        'finalizado' || 'completado' => 7,
        'cancelado' => 8,
        _ => 5,
      };

  static String _maintenanceStatusName(dynamic value) =>
      switch (_asInt(value)) {
        6 => 'En proceso',
        7 => 'Finalizado',
        8 => 'Cancelado',
        _ => 'Pendiente',
      };
}
