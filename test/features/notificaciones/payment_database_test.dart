import 'dart:io';

import 'package:alquilados_app/features/sync/data/datasources/local_database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  late Directory folder;
  late LocalDatabaseService service;
  setUp(() async {
    folder = await Directory.systemTemp.createTemp(
      'alquilados_reminders_test_',
    );
    service = LocalDatabaseService.forTesting('${folder.path}/local.db');
  });
  tearDown(() async {
    await service.close();
    await folder.delete(recursive: true);
  });

  test(
    'migra SQLite v6 sin modificar datos de contratos o inquilinos',
    () async {
      final legacy = await openDatabase(
        '${folder.path}/local.db',
        version: 6,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE alquileres (id INTEGER PRIMARY KEY, importe REAL)',
          );
          await db.execute(
            'CREATE TABLE inquilinos (id INTEGER PRIMARY KEY, nombre_apellido TEXT)',
          );
          await db.execute(
            'CREATE TABLE pagos (id INTEGER PRIMARY KEY, monto REAL)',
          );
          await db.insert('pagos', {'id': 1, 'monto': 12000});
          await db.insert('alquileres', {'id': 1, 'importe': 12000});
          await db.insert('inquilinos', {'id': 1, 'nombre_apellido': 'José'});
        },
      );
      await legacy.close();
      final migrated = await service.database;
      expect((await migrated.query('alquileres')).single, {
        'id': 1,
        'importe': 12000.0,
        'diasProrroga': 0,
        'solo_lectura': 0,
        'nombre_propiedad_web': null,
      });
      expect(
        (await migrated.query('inquilinos')).single['nombre_apellido'],
        'José',
      );
      expect((await migrated.query('inquilinos')).single['telefono'], isNull);
      expect((await migrated.query('pagos')).single, {
        'id': 1,
        'monto': 12000.0,
        'metodo_pago': null,
        'banco': null,
        'creado_por': null,
        'editado_por': null,
      });
      expect(await migrated.getVersion(), 12);
    },
  );

  test(
    'conserva la forma de pago y limpia el banco y el alquiler al editar',
    () async {
      final payment = await service.insertPago(
        idInquilino: '1',
        fechaPago: '2026-11-25',
        monto: 250,
        estado: 'pendiente',
        alquilerId: 7,
        method: (name: 'Transferencia', bank: 'Banco de prueba'),
        creadoPor: 'operador.alta',
      );
      await service.updatePago(
        id: payment,
        idInquilino: '1',
        fechaPago: '2026-11-25',
        monto: 250,
        estado: 'pagado',
      );
      final paid = (await service.getPagoById(payment))!;
      expect(paid['metodo_pago'], 'Transferencia');
      expect(paid['banco'], 'Banco de prueba');
      expect(paid['id_alquiler'], 7);
      expect(paid['creado_por'], 'operador.alta');
      expect(paid['editado_por'], isNull);

      await service.updatePago(
        id: payment,
        idInquilino: '2',
        fechaPago: '2026-11-25',
        monto: 250,
        estado: 'pagado',
        method: (name: 'Efectivo', bank: null),
        editadoPor: 'operador.edicion',
      );
      final updated = (await service.getPagoById(payment))!;
      expect(updated['id_inquilino'], '2');
      expect(updated['id_alquiler'], isNull);
      expect(updated['alquiler_id'], isNull);
      expect(updated['metodo_pago'], 'Efectivo');
      expect(updated['banco'], isNull);
      expect(updated['creado_por'], 'operador.alta');
      expect(updated['editado_por'], 'operador.edicion');
    },
  );

  test('el detalle usa la propiedad del contrato vinculado al pago', () async {
    final property = await service.insertPropiedad(
      nombre: 'Residencial Las Palmas',
      direccion: '',
      estado: 1,
      precioMensual: 250,
      notas: '',
    );
    final tenant = await service.insertInquilino(nombreApellido: 'Ana');
    final rental = await service.insertAlquiler(
      propiedadId: property,
      inquilinoId: tenant,
      fechaInicio: '2026-11-01',
      importe: 250,
      estado: 'Activo',
      generarPagosPendientes: false,
    );
    final payment = await service.insertPago(
      idInquilino: '$tenant',
      fechaPago: '2026-11-25',
      monto: 250,
      estado: 'pagado',
      alquilerId: rental,
    );
    final db = await service.database;
    await db.update(
      'pagos',
      {'id_alquiler': null},
      where: 'id = ?',
      whereArgs: [payment],
    );
    final detail = (await service.getPagoByIdConDetalle(payment))!;
    expect(detail['propiedad_nombre'], 'Residencial Las Palmas');

    await db.update(
      'alquileres',
      {'nombre_propiedad_web': 'Residencial Las Palmas II'},
      where: 'id = ?',
      whereArgs: [rental],
    );
    final webDetail = (await service.getPagoByIdConDetalle(payment))!;
    expect(webDetail['propiedad_nombre'], 'Residencial Las Palmas II');
  });

  test(
    'incluye solo deudas activas y elimina avisos al pagar o cerrar contrato',
    () async {
      await service.ensureDatabaseReady();
      final tenant = await service.insertInquilino(
        nombreApellido: 'José',
        telefono: '+18095550123',
      );
      final property = await service.insertPropiedad(
        nombre: 'A',
        direccion: 'Calle A',
        estado: 1,
        precioMensual: 12000,
        notas: '',
      );
      final lease = await service.insertAlquiler(
        propiedadId: property,
        inquilinoId: tenant,
        fechaInicio: '2026-11-01',
        importe: 12000,
        cantidadMeses: 1,
        diaPago: 15,
        diasProrroga: 3,
        estado: 'Activo',
      );
      final rows = await service.getPaymentReminderRows();
      expect(rows, hasLength(1));
      expect(rows.single['diasProrroga'], 3);
      final payment = rows.single['id'] as int;
      expect(
        (await service.getWhatsAppPayment(payment))!['telefono'],
        '+18095550123',
      );
      await service.updatePago(
        id: payment,
        idInquilino: '$tenant',
        fechaPago: '2026-11-15',
        monto: 12000,
        estado: 'pagado',
      );
      expect(await service.getPaymentReminderRows(), isEmpty);
      await service.updatePago(
        id: payment,
        idInquilino: '$tenant',
        fechaPago: '2026-11-15',
        monto: 12000,
        estado: 'pendiente',
      );
      await service.updateAlquiler(
        id: lease,
        propiedadId: property,
        inquilinoId: tenant,
        fechaInicio: '2026-11-01',
        importe: 12000,
        diasProrroga: 3,
        estado: 'Finalizado',
      );
      expect(await service.getPaymentReminderRows(), isEmpty);
      await service.updateInquilino(
        id: tenant,
        nombreApellido: 'José actualizado',
      );
      expect(
        (await service.getInquilinoById(tenant))!['telefono'],
        '+18095550123',
      );
    },
  );
}
