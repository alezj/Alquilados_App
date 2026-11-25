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

  test(
    'downloads read-only web contracts and preserves colliding mobile rentals',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final local = LocalDatabaseService.forTesting(inMemoryDatabasePath);
      addTearDown(local.close);
      final db = await local.database;
      await db.insert('inquilinos', {
        'id': 1,
        'nombre_apellido': 'Inquilino local',
      });
      await db.insert('alquileres', {
        'id': 3,
        'propiedad_id': 9,
        'inquilino_id': 1,
        'fecha_inicio': '2026-01-01',
        'importe': 100,
      });
      final api = MockTenantApi();
      final repo = SyncRepositoryImpl(local, api);
      when(
        () => api.get<List<dynamic>>(
          'inquilinos',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(),
          data: [
            {
              'id': 1,
              'company_id': 'company-a',
              'Origen': 'web',
              'nombreApellido': 'Inquilino web',
            },
          ],
        ),
      );
      var remoteCompany = 'company-a';
      var amount = 200;
      when(
        () => api.get<List<dynamic>>(
          'alquileres',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((call) async {
        final params = call.namedArguments[#queryParameters] as Map;
        expect(params['company_id'], 'eq.company-a');
        expect(params['Origen'], 'eq.web');
        expect(params.containsKey('usuario'), isFalse);
        return Response(
          requestOptions: RequestOptions(),
          data: [
            {
              'id': 3,
              'company_id': remoteCompany,
              'Origen': 'web',
              'propiedadID': 9,
              'propiedad': {'id': 9, 'nombre': 'Propiedad web'},
              'inquilinoID': 1,
              'fechaInicio': '2026-11-01',
              'importe': amount,
              'estado': 'pendiente',
            },
          ],
        );
      });

      Future<int> pull() async => (await repo.pullProduction(
        tenant: 'admin',
        companyId: 'company-a',
      )).localChanges;

      expect(await pull(), 2);
      expect(await pull(), 0);
      final contracts = await local.getAlquileresConDetalles();
      final mobile = contracts.singleWhere((row) => row['id'] == 3);
      final web = contracts.singleWhere((row) => row['solo_lectura'] == 1);
      final webId = web['id'] as int;
      expect(mobile['sync_state'], 'pending');
      expect(mobile['importe'], 100);
      expect(webId, isNegative);
      expect(web['propiedad_nombre'], 'Propiedad web');
      expect(web['inquilino_nombre'], 'Inquilino web');
      expect(web['estado'], 'Pendiente');
      expect(await local.deleteAlquiler(webId), 0);
      expect(
        await local.updateAlquiler(
          id: webId,
          propiedadId: 9,
          inquilinoId: 1,
          fechaInicio: '2026-11-01',
          importe: 999,
          estado: 'Activo',
        ),
        0,
      );
      expect(await local.getPendingRows('alquileres'), hasLength(1));

      amount = 300;
      expect(await pull(), 1);
      expect((await local.getAlquilerById(webId))!['importe'], 300);
      remoteCompany = 'company-b';
      amount = 400;
      expect(await pull(), 0);
      expect((await local.getAlquilerById(webId))!['importe'], 300);
      verifyNever(() => api.post<dynamic>(any(), data: any(named: 'data')));
      verifyNever(() => api.patch<dynamic>(any(), data: any(named: 'data')));
    },
  );
}
