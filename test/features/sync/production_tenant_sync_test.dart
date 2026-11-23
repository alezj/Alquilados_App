import 'package:alquilados_app/core/network/api_client.dart';
import 'package:alquilados_app/features/sync/data/datasources/local_database_service.dart';
import 'package:alquilados_app/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockTenantApi extends Mock implements ApiClient {}

void main() {
  test('imports scoped tenants without overwriting local work or linking the wrong ID', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final local = LocalDatabaseService.forTesting(inMemoryDatabasePath);
    addTearDown(local.close);
    final db = await local.database;
    await db.insert('inquilinos', {
      'id': 1,
      'nombre_apellido': 'Pendiente local',
    });
    final api = MockTenantApi();
    final repo = SyncRepositoryImpl(local, api);
    var remoteName = 'Inquilino del CRM';
    when(
      () => api.get<List<dynamic>>(
        'inquilinos',
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((request) async {
      final params = request.namedArguments[#queryParameters] as Map;
      expect(params['company_id'], 'eq.company-a');
      expect(params.containsKey('Origen'), isFalse);
      return Response(
        requestOptions: RequestOptions(),
        data: [
          {
            'id': 1,
            'company_id': 'company-a',
            'Origen': 'web',
            'usuario': 'author-a',
            'created_at': '2026-11-19T00:00:00+00:00',
            'nombreApellido': remoteName,
            'telefono': '8095550101',
          },
        ],
      );
    });
    when(() => api.get<dynamic>(any())).thenAnswer((request) async {
      final path = request.positionalArguments.single as String;
      if (path.startsWith('pagos?')) {
        expect(path, contains('company_id=eq.company-a'));
        return Response(
          requestOptions: RequestOptions(),
          data: [
            {
              'id': 10,
              'monto': 100,
              'idInquilino': 1,
              'fechaPago': '2026-11-19',
            },
          ],
        );
      }
      return Response(requestOptions: RequestOptions(), data: []);
    });

    final first = await repo.pullProductionTenants(
      tenant: 'admin',
      companyId: 'company-a',
    );
    expect(first.localChanges, 1);
    expect(
      (await local.getRowById('inquilinos', 1))!['nombre_apellido'],
      'Pendiente local',
    );
    expect(
      (await local.getRowById('inquilinos', 2))!['nombre_apellido'],
      remoteName,
    );
    expect(
      (await repo.pullProductionTenants(
        tenant: 'admin',
        companyId: 'company-a',
      )).localChanges,
      0,
    );

    remoteName = 'Editado desde el CRM';
    await repo.syncNow(tenant: 'admin', companyId: 'company-a');
    expect(
      (await local.getRowById('inquilinos', 2))!['nombre_apellido'],
      remoteName,
    );
    expect(
      (await local.getRowById('pagos', 10))!['id_inquilino'].toString(),
      '2',
    );
    expect((await local.getRowById('inquilinos', 1))!['sync_state'], 'pending');
    verifyNever(() => api.post<dynamic>(any(), data: any(named: 'data')));

    await db.update(
      'inquilinos',
      {'nombre_apellido': 'Cambio móvil', 'sync_state': 'pending'},
      where: 'id = ?',
      whereArgs: [2],
    );
    remoteName = 'Otro cambio del CRM';
    final conflict = await repo.pullProductionTenants(
      tenant: 'admin',
      companyId: 'company-a',
    );
    expect(conflict.message, contains('1 pendientes'));
    expect(
      (await local.getRowById('inquilinos', 2))!['nombre_apellido'],
      'Cambio móvil',
    );
  });
}
