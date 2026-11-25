import 'package:alquilados_app/core/config/app_config.dart';
import 'package:alquilados_app/core/errors/app_exception.dart';
import 'package:alquilados_app/core/network/api_client.dart';
import 'package:alquilados_app/core/storage/secure_storage_service.dart';
import 'package:alquilados_app/features/pagos/data/repositories/online_payment_repository.dart';
import 'package:alquilados_app/features/pagos/domain/entities/pago.dart';
import 'package:alquilados_app/features/pagos/presentation/providers/payment_mutations_provider.dart';
import 'package:alquilados_app/features/sync/data/datasources/crm_sync_store.dart';
import 'package:alquilados_app/features/sync/data/datasources/local_database_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockPaymentApi extends Mock implements ApiClient {}

class MockPaymentStorage extends Mock implements SecureStorageService {}

void main() {
  test('confirms a new payment online using the CRM tenant ID', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final previousBackend = AppConfig.backend;
    AppConfig.backend = BackendEnvironment.test;
    addTearDown(() => AppConfig.backend = previousBackend);
    final local = LocalDatabaseService.forTesting(inMemoryDatabasePath);
    addTearDown(local.close);
    await local.switchTenant('test_pagos');
    final db = await local.database;
    await db.insert('inquilinos', {'id': 41, 'nombre_apellido': 'Solo local'});
    await CrmSyncStore().apply(db, [
      (
        resource: 'inquilinos',
        remoteId: 41,
        revision: 1,
        values: {'nombre_apellido': 'En el CRM', 'sync_state': 'synced'},
      ),
    ]);

    final api = MockPaymentApi();
    final storage = MockPaymentStorage();
    when(storage.getSessionContext).thenAnswer(
      (_) async => {
        'environment': 'test',
        'tenant': 'test_pagos',
        'companyId': 'company',
      },
    );
    when(storage.hasToken).thenAnswer((_) async => true);
    var refreshes = 0;
    final payments = PaymentMutations(
      local,
      storage,
      OnlinePaymentRepository(api),
      refreshAfterWrite: () async {
        refreshes++;
      },
    );
    when(
      () => api.post<int>('rpc/mobile_write_payment', data: any(named: 'data')),
    ).thenAnswer((invocation) async {
      final command =
          (invocation.namedArguments[#data] as Map)['p_command'] as Map;
      expect(command['tenant_id'], 41);
      expect(command['amount'], 125);
      return Response(requestOptions: RequestOptions(), data: 77);
    });

    final selectableTenants = await payments.availableTenants();
    expect(selectableTenants.single['id'], 42);
    await expectLater(
      payments.create(
        idInquilino: '41',
        fechaPago: '2026-11-19',
        monto: 125,
        estado: 'pendiente',
      ),
      throwsA(isA<BadRequestException>()),
    );
    expect(
      await payments.create(
        idInquilino: '42',
        fechaPago: '2026-11-19',
        monto: 125,
        estado: 'pendiente',
      ),
      'Pago guardado en el CRM.',
    );
    expect(refreshes, 1);
    expect(await db.query('pagos'), isEmpty);
  });

  test(
    'retries an uncertain online payment with the same operation ID',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final local = LocalDatabaseService.forTesting(inMemoryDatabasePath);
      addTearDown(local.close);
      final db = await local.database;
      final api = MockPaymentApi();
      final repository = OnlinePaymentRepository(api);
      final submittedIds = <String>[];
      const command = {
        'action': 'create',
        'tenant_id': 5,
        'date': '2026-11-19',
        'amount': 100,
        'status': 'pendiente',
      };

      when(
        () =>
            api.post<int>('rpc/mobile_write_payment', data: any(named: 'data')),
      ).thenAnswer((invocation) async {
        final data = invocation.namedArguments[#data] as Map;
        expect(data['p_company_id'], 'company');
        expect(data['p_command'], command);
        submittedIds.add(data['p_operation_id'] as String);
        if (submittedIds.length == 1) throw const TimeoutException();
        return Response(requestOptions: RequestOptions(), data: 21);
      });

      await expectLater(
        PaymentRequestStore().submit(db, repository, 'company', command),
        throwsA(isA<TimeoutException>()),
      );
      expect(await db.query('pagos'), isEmpty);
      expect(await db.query('online_payment_requests'), hasLength(1));

      expect(
        await PaymentRequestStore().submit(db, repository, 'company', command),
        21,
      );
      expect(submittedIds, [submittedIds.first, submittedIds.first]);
      expect(await db.query('online_payment_requests'), isEmpty);
      expect(await db.query('pagos'), isEmpty);
    },
  );

  test(
    'registra en SQLite el usuario que crea y el que modifica un pago',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final previousBackend = AppConfig.backend;
      AppConfig.backend = BackendEnvironment.production;
      addTearDown(() => AppConfig.backend = previousBackend);
      final local = LocalDatabaseService.forTesting(inMemoryDatabasePath);
      addTearDown(local.close);
      final storage = MockPaymentStorage();
      var operator = 'usuario.alta';
      when(storage.getSessionContext).thenAnswer(
        (_) async => {
          'environment': 'production',
          'tenant': 'admin',
          'username': operator,
        },
      );
      final payments = PaymentMutations(
        local,
        storage,
        OnlinePaymentRepository(MockPaymentApi()),
        refreshAfterWrite: () async {},
      );
      await payments.create(
        idInquilino: '1',
        fechaPago: '2026-11-25',
        monto: 125,
        estado: 'pendiente',
      );
      final db = await local.database;
      final original = (await db.query('pagos')).single;
      expect(original['creado_por'], 'usuario.alta');
      expect(original['editado_por'], isNull);

      operator = 'usuario.edicion';
      final pago = Pago(
        id: original['id'] as int,
        idInquilino: '1',
        inquilinoNombre: 'Cliente',
        fechaPago: '2026-11-25',
        monto: 125,
      );
      await payments.update(
        pago,
        idInquilino: '1',
        fechaPago: '2026-11-25',
        monto: 130,
        estado: 'pendiente',
      );
      final edited = (await db.query('pagos')).single;
      expect(edited['creado_por'], 'usuario.alta');
      expect(edited['editado_por'], 'usuario.edicion');
    },
  );
}
