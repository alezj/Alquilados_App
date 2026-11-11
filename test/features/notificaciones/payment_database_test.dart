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
      });
      expect(
        (await migrated.query('inquilinos')).single['nombre_apellido'],
        'José',
      );
      expect((await migrated.query('inquilinos')).single['telefono'], isNull);
      expect(await migrated.getVersion(), 7);
    },
  );

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
