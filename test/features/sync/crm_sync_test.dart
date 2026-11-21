import 'package:alquilados_app/core/network/api_client.dart';
import 'package:alquilados_app/features/sync/data/datasources/local_database_service.dart';
import 'package:alquilados_app/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  test(
    'descarga el cobro del CRM, conserva ediciones locales y aplica bajas',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final local = LocalDatabaseService.forTesting(inMemoryDatabasePath);
      addTearDown(local.close);
      final db = await local.database;
      final api = MockApiClient();
      final repository = SyncRepositoryImpl(local, api);
      final requestedCursors = <String>[];

      Map<String, dynamic> change(
        String table,
        int id,
        int revision,
        Map<String, dynamic>? record,
      ) => {
        'resource': table,
        'remote_id': id,
        'revision': revision,
        'record': record == null
            ? null
            : {'id': id, 'Origen': 'web', 'usuario': 'crm', ...record},
      };

      Map<String, dynamic> pago(String estado) => {
        'idAlquiler': 1,
        'idInquilino': 1,
        'estado': estado,
        'fechaPago': estado == 'Pagado' ? '2026-11-19' : '',
        'fechaVencimiento': '2026-11-22',
        'monto': 100,
      };

      await db.insert('propiedades', {'id': 1, 'nombre': 'Edición local'});
      var rows = [
        change('pagos', 1, 1, pago('Pendiente')),
        change('alquileres', 1, 2, {
          'propiedadID': 1,
          'inquilinoID': 1,
          'fechaInicio': '2026-11-01',
          'fechaFin': '2027-11-01',
          'montoPago': 100,
        }),
        change('inquilinos', 1, 3, {'nombreApellido': 'Inquilino CRM'}),
        change('propiedades', 1, 4, {
          'nombre': 'Propiedad CRM',
          'direccion': 'Calle de prueba',
        }),
      ];
      when(
        () => api.get<List<dynamic>>(
          'mobile_crm_change_feed',
          queryParameters: any(named: 'queryParameters'),
        ),
      ).thenAnswer((invocation) async {
        final params = invocation.namedArguments[#queryParameters] as Map;
        expect(params['company_id'], 'eq.test-company');
        requestedCursors.add(params['revision'] as String);
        return Response(requestOptions: RequestOptions(), data: rows);
      });

      Future<void> pull() async {
        await repository.pullCrm(tenant: 'admin', companyId: 'test-company');
      }

      await pull();
      expect((await local.getDashboardSummary())['pagosPendientes'], 1);
      expect((await db.query('pagos')).single['fecha_pago'], '2026-11-22');
      expect((await db.query('alquileres')).single['propiedad_id'], 2);
      expect(
        (await local.getRowById('propiedades', 1))!['nombre'],
        'Edición local',
      );

      rows = [
        change('pagos', 1, 5, pago('Pagado')),
        change('pagos', 2, 6, pago('Pagado')),
      ];
      await pull();
      expect((await local.getDashboardSummary())['pagosPendientes'], 0);
      expect((await local.getDashboardSummary())['pagosRealizados'], 2);
      expect((await local.getRowById('pagos', 1))!['fecha_pago'], '2026-11-19');

      await local.updatePago(
        id: 1,
        idInquilino: '1',
        fechaPago: '2026-11-19',
        monto: 150,
        estado: 'pagado',
      );
      rows = [
        change('pagos', 1, 7, pago('Pendiente')),
        change('pagos', 2, 8, null),
      ];
      final last = await repository.pullCrm(
        tenant: 'admin',
        companyId: 'test-company',
      );
      expect(last.localChanges, 1);
      expect(last.message, contains('1 en espera'));
      expect((await local.getRowById('pagos', 1))!['monto'], 150);
      expect(await local.getRowById('pagos', 2), isNull);

      rows = [];
      await pull();
      expect(requestedCursors, ['gt.0', 'gt.4', 'gt.6', 'gt.8']);
      expect((await local.getRowById('pagos', 1))!['sync_state'], 'pending');
    },
  );
}
