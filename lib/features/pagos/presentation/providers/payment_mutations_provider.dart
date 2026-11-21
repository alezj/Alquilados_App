import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../inquilinos/presentation/providers/inquilinos_provider.dart';
import '../../../sync/data/datasources/local_database_service.dart';
import '../../../sync/presentation/providers/sync_provider.dart';
import '../../data/repositories/online_payment_repository.dart';
import '../../domain/entities/pago.dart';
import 'pagos_provider.dart';

final paymentMutationsProvider = Provider<PaymentMutations>((ref) {
  return PaymentMutations(
    LocalDatabaseService(),
    ref.watch(secureStorageProvider),
    OnlinePaymentRepository(ref.watch(apiClientProvider)),
    refreshAfterWrite: () async {
      if (!ref.mounted) return;
      if (AppConfig.backend == BackendEnvironment.test) {
        await ref.read(syncStateProvider.notifier).refreshAfterCrmWrite();
      }
      if (!ref.mounted) return;
      ref.invalidate(pagosProvider);
      ref.invalidate(pagoDetalleProvider);
      ref.invalidate(pagosDeInquilinoProvider);
      ref.invalidate(dashboardSummaryProvider);
    },
  );
});

class PaymentMutations {
  PaymentMutations(
    this._database,
    this._storage,
    this._online, {
    required this.refreshAfterWrite,
  });

  final LocalDatabaseService _database;
  final SecureStorageService _storage;
  final OnlinePaymentRepository _online;
  final Future<void> Function() refreshAfterWrite;
  final _requests = PaymentRequestStore();
  bool _saving = false;

  bool get isOnline => AppConfig.backend == BackendEnvironment.test;

  Future<List<Map<String, Object?>>> availableTenants() async {
    if (!isOnline) return _database.getAllRows('inquilinos');
    final db = await _database.database;
    return db.rawQuery('''
      SELECT i.* FROM inquilinos i
      JOIN crm_sync_records r ON r.resource = 'inquilinos' AND r.local_id = i.id
      WHERE r.needs_apply = 0
      ORDER BY i.nombre_apellido
    ''');
  }

  Future<String?> create({
    required String idInquilino,
    required String fechaPago,
    required double monto,
    required String estado,
  }) => _write(
    local: () => _database.insertPago(
      idInquilino: idInquilino,
      fechaPago: fechaPago,
      monto: monto,
      estado: estado,
    ),
    online: (db) async {
      final tenantId = int.tryParse(idInquilino);
      final tenant = await _mapped(db, 'inquilinos', tenantId);
      final rental = tenantId == null
          ? null
          : await _database.getAlquilerActivoByInquilinoId(tenantId);
      final mappedRental = await _mapped(
        db,
        'alquileres',
        rental?['id'] as int?,
      );
      return {
        'action': 'create',
        'tenant_id': _requireTenant(tenant),
        'rental_id': mappedRental?['remote_id'],
        'date': fechaPago,
        'amount': monto,
        'status': estado,
      };
    },
    onlineMessage: 'Pago guardado en el CRM.',
    localMessage: 'Pago guardado localmente.',
  );

  Future<String?> update(
    Pago pago, {
    required String idInquilino,
    required String fechaPago,
    required double monto,
    required String estado,
  }) => _write(
    local: () => _database.updatePago(
      id: pago.id,
      idInquilino: idInquilino,
      fechaPago: fechaPago,
      monto: monto,
      estado: estado,
    ),
    online: (db) async => {
      'action': 'update',
      ...await _paymentIdentity(db, pago),
      'tenant_id': _requireTenant(
        await _mapped(db, 'inquilinos', int.tryParse(idInquilino)),
      ),
      'date': fechaPago,
      'amount': monto,
      'status': estado,
    },
    onlineMessage: 'Pago actualizado en el CRM.',
    localMessage: 'Pago actualizado localmente.',
  );

  Future<String?> changeStatus(Pago pago, String estado) => _write(
    local: () => _database.updatePago(
      id: pago.id,
      idInquilino: pago.idInquilino,
      fechaPago: pago.fechaPago,
      monto: pago.monto,
      estado: estado,
    ),
    online: (db) async => {
      'action': 'status',
      ...await _paymentIdentity(db, pago),
      'status': estado,
      'date': DateTime.now().toIso8601String().substring(0, 10),
    },
    onlineMessage: 'Estado actualizado en el CRM.',
    localMessage: 'Estado actualizado.',
  );

  Future<String?> delete(Pago pago) => _write(
    local: () => _database.deletePago(pago.id),
    online: (db) async => {
      'action': 'delete',
      ...await _paymentIdentity(db, pago),
    },
    onlineMessage: 'Pago eliminado del CRM.',
    localMessage: 'Pago eliminado.',
  );

  Future<String?> _write({
    required Future<int> Function() local,
    required Future<Map<String, Object?>> Function(Database db) online,
    required String onlineMessage,
    required String localMessage,
  }) async {
    if (_saving) return null;
    _saving = true;
    try {
      final useOnline = isOnline;
      if (useOnline) {
        final session = await _storage.getSessionContext();
        final companyId = session?['companyId'] as String?;
        final tenant = session?['tenant'] as String?;
        if (companyId == null ||
            session?['environment'] != 'test' ||
            tenant != _database.tenantKey ||
            !await _storage.hasToken()) {
          throw const UnauthorizedException(
            userMessage:
                'Inicia sesión en Pruebas para guardar pagos en el CRM.',
          );
        }
        final db = await _database.database;
        final command = await online(db);
        if (!isOnline || tenant != _database.tenantKey) {
          throw const UnauthorizedException();
        }
        await _requests.submit(db, _online, companyId, command);
      } else {
        await local();
      }
      await refreshAfterWrite();
      return useOnline ? onlineMessage : localMessage;
    } finally {
      _saving = false;
    }
  }

  Future<Map<String, Object?>?> _mapped(
    Database db,
    String resource,
    int? localId,
  ) async {
    if (localId == null) return null;
    final rows = await db.query(
      'crm_sync_records',
      columns: ['remote_id', 'revision'],
      where: 'resource = ? AND local_id = ? AND needs_apply = 0',
      whereArgs: [resource, localId],
      limit: 1,
    );
    return rows.firstOrNull;
  }

  int _requireTenant(Map<String, Object?>? row) {
    if (row == null) {
      throw const BadRequestException(
        userMessage: 'Selecciona un inquilino sincronizado con el CRM.',
      );
    }
    return row['remote_id']! as int;
  }

  Future<Map<String, Object?>> _paymentIdentity(Database db, Pago pago) async {
    final row = await _mapped(db, 'pagos', pago.id);
    if (pago.syncState != 'synced' || pago.crmRevision == null) {
      throw const BadRequestException(
        userMessage: 'Este pago tiene datos guardados solo en el teléfono.',
      );
    }
    if (row == null || row['revision'] != pago.crmRevision) {
      throw const ConflictException(
        userMessage: 'El pago cambió. Vuelve a abrirlo antes de editarlo.',
      );
    }
    return {'payment_id': row['remote_id'], 'revision': pago.crmRevision};
  }
}
