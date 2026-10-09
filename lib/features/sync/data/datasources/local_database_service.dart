import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();

  factory LocalDatabaseService() => _instance;

  LocalDatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> ensureDatabaseReady() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alquileres (
        id INTEGER PRIMARY KEY,
        propiedad_id INTEGER NOT NULL,
        inquilino_id INTEGER NOT NULL,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT,
        importe REAL NOT NULL,
        montoPago REAL NOT NULL DEFAULT 0,
        cantidadDepositos INTEGER NOT NULL DEFAULT 0,
        diaPago INTEGER NOT NULL DEFAULT 1,
        estado TEXT DEFAULT 'Pendiente' CHECK(estado IN ('Activo', 'Finalizado', 'Pendiente', 'Cancelado')),
        updated_at TEXT DEFAULT (datetime('now')),
        synced_at TEXT,
        sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
      )
    ''');

    await _addColumnIfNotExists(
      db,
      'alquileres',
      'montoPago',
      'REAL DEFAULT 0',
    );
    await db.rawUpdate(
      'UPDATE alquileres SET montoPago = importe WHERE montoPago IS NULL OR montoPago = 0',
    );
    await _addColumnIfNotExists(
      db,
      'alquileres',
      'cantidadDepositos',
      'INTEGER DEFAULT 0',
    );
    await _addColumnIfNotExists(
      db,
      'alquileres',
      'diaPago',
      'INTEGER DEFAULT 1',
    );
    await _addColumnIfNotExists(db, 'pagos', 'id_alquiler', 'INTEGER');
    await _addColumnIfNotExists(db, 'pagos', 'alquiler_id', 'INTEGER');
    await _addColumnIfNotExists(db, 'pagos', 'periodo', 'TEXT');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mantenimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        propiedad_id INTEGER NOT NULL,
        descripcion TEXT NOT NULL,
        fecha TEXT NOT NULL,
        costo REAL NOT NULL DEFAULT 0,
        estado TEXT NOT NULL DEFAULT 'Pendiente',
        updated_at TEXT DEFAULT (datetime('now')),
        synced_at TEXT,
        sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
      )
    ''');
  }

  Future<Database> _initDatabase() async {
    final path = kIsWeb
        ? 'alquilados_local.db3'
        : '${(await getDownloadsDirectory())!.path}/alquilados_local.db3';

    return openDatabase(
      path,
      version: 5,
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE propiedades (
        id INTEGER PRIMARY KEY,
        nombre TEXT NOT NULL,
        direccion TEXT,
        estado INTEGER,
        precio_mensual REAL,
        notas TEXT,
        updated_at TEXT DEFAULT (datetime('now')),
        synced_at TEXT,
        sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
      )
    ''');

    await db.execute('''
      CREATE TABLE inquilinos (
        id INTEGER PRIMARY KEY,
        nombre_apellido TEXT NOT NULL,
        correo TEXT,
        fecha_inicio_contrato TEXT,
        fecha_pagos INTEGER,
        updated_at TEXT DEFAULT (datetime('now')),
        synced_at TEXT,
        sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
      )
    ''');

    await db.execute('''
      CREATE TABLE pagos (
        id INTEGER PRIMARY KEY,
        id_inquilino TEXT,
        id_alquiler INTEGER,
        alquiler_id INTEGER,
        periodo TEXT,
        fecha_pago TEXT,
        monto REAL,
        estado TEXT,
        updated_at TEXT DEFAULT (datetime('now')),
        synced_at TEXT,
        sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
      )
    ''');

    await db.execute('''
      CREATE TABLE alquileres (
        id INTEGER PRIMARY KEY,
        propiedad_id INTEGER NOT NULL,
        inquilino_id INTEGER NOT NULL,
        fecha_inicio TEXT NOT NULL,
        fecha_fin TEXT,
        importe REAL NOT NULL,
        montoPago REAL NOT NULL DEFAULT 0,
        cantidadDepositos INTEGER NOT NULL DEFAULT 0,
        diaPago INTEGER NOT NULL DEFAULT 1,
        estado TEXT DEFAULT 'Pendiente' CHECK(estado IN ('Activo', 'Finalizado', 'Pendiente', 'Cancelado')),
        updated_at TEXT DEFAULT (datetime('now')),
        synced_at TEXT,
        sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
      )
    ''');

    await db.execute('''
      CREATE TABLE mantenimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        propiedad_id INTEGER NOT NULL,
        descripcion TEXT NOT NULL,
        fecha TEXT NOT NULL,
        costo REAL NOT NULL DEFAULT 0,
        estado TEXT NOT NULL DEFAULT 'Pendiente',
        updated_at TEXT DEFAULT (datetime('now')),
        synced_at TEXT,
        sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_name TEXT NOT NULL,
        action TEXT NOT NULL,
        status TEXT NOT NULL,
        message TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS alquileres (
          id INTEGER PRIMARY KEY,
          propiedad_id INTEGER NOT NULL,
          inquilino_id INTEGER NOT NULL,
          fecha_inicio TEXT NOT NULL,
          fecha_fin TEXT,
          importe REAL NOT NULL,
          montoPago REAL NOT NULL DEFAULT 0,
          cantidadDepositos INTEGER NOT NULL DEFAULT 0,
          diaPago INTEGER NOT NULL DEFAULT 1,
          estado TEXT DEFAULT 'Pendiente' CHECK(estado IN ('Activo', 'Finalizado', 'Pendiente', 'Cancelado')),
          updated_at TEXT DEFAULT (datetime('now')),
          synced_at TEXT,
          sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
        )
      ''');

      await _addColumnIfNotExists(db, 'pagos', 'id_alquiler', 'INTEGER');
      await _addColumnIfNotExists(db, 'pagos', 'alquiler_id', 'INTEGER');
      await _addColumnIfNotExists(db, 'pagos', 'periodo', 'TEXT');
    }

    if (oldVersion < 3) {
      await _addColumnIfNotExists(
        db,
        'alquileres',
        'montoPago',
        'REAL DEFAULT 0',
      );
      await db.rawUpdate(
        'UPDATE alquileres SET montoPago = importe WHERE montoPago IS NULL OR montoPago = 0',
      );
    }

    if (oldVersion < 4) {
      await _addColumnIfNotExists(
        db,
        'alquileres',
        'cantidadDepositos',
        'INTEGER DEFAULT 0',
      );
      await _addColumnIfNotExists(
        db,
        'alquileres',
        'diaPago',
        'INTEGER DEFAULT 1',
      );
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mantenimientos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          propiedad_id INTEGER NOT NULL,
          descripcion TEXT NOT NULL,
          fecha TEXT NOT NULL,
          costo REAL NOT NULL DEFAULT 0,
          estado TEXT NOT NULL DEFAULT 'Pendiente',
          updated_at TEXT DEFAULT (datetime('now')),
          synced_at TEXT,
          sync_state TEXT DEFAULT 'pending' CHECK(sync_state IN ('pending', 'synced', 'error'))
        )
      ''');
    }
  }

  Future<void> _addColumnIfNotExists(
    Database db,
    String tableName,
    String columnName,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = columns.any(
      (column) => (column['name'] as String?) == columnName,
    );
    if (!exists) {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $columnName $definition',
      );
    }
  }

  Future<void> insertSeedProperty() async {
    final db = await database;

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM propiedades'),
    );

    if (count != null && count > 0) {
      return;
    }

    await db.insert('propiedades', {
      'id': 1,
      'nombre': 'Apartamento Demo',
      'direccion': 'Calle Falsa 123',
      'estado': 1,
      'precio_mensual': 1250.0,
      'notas': 'Propiedad de ejemplo sincronizada localmente.',
      'sync_state': 'synced',
      'synced_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> ensureSeedData() async {
    final db = await database;
    await ensureDatabaseReady();

    final propertyCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM propiedades'),
    );

    if (propertyCount == null || propertyCount == 0) {
      await db.insert('propiedades', {
        'id': 1,
        'nombre': 'Apartamento Centro',
        'direccion': 'Calle Principal 123',
        'estado': 2,
        'precio_mensual': 1650.0,
        'notas': 'Inquilino vigente con pago mensual.',
        'sync_state': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      });

      await db.insert('propiedades', {
        'id': 2,
        'nombre': 'Casa Residencial',
        'direccion': 'Avenida del Sol 45',
        'estado': 1,
        'precio_mensual': 2100.0,
        'notas': 'Disponible para nueva ocupación.',
        'sync_state': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      });
    }

    final tenantCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM inquilinos'),
    );

    if (tenantCount == null || tenantCount == 0) {
      await db.insert('inquilinos', {
        'id': 1,
        'nombre_apellido': 'Carlos Mendoza',
        'correo': 'carlos@test.com',
        'fecha_inicio_contrato': '2024-01-15',
        'fecha_pagos': 15,
        'sync_state': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      });

      await db.insert('inquilinos', {
        'id': 2,
        'nombre_apellido': 'Ana López',
        'correo': 'ana@test.com',
        'fecha_inicio_contrato': '2024-02-20',
        'fecha_pagos': 20,
        'sync_state': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      });
    }

    final alquilerCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM alquileres'),
    );

    if (alquilerCount == null || alquilerCount == 0) {
      await db.insert('alquileres', {
        'id': 1,
        'propiedad_id': 1,
        'inquilino_id': 1,
        'fecha_inicio': '2026-09-01',
        'fecha_fin': '2027-08-31',
        'importe': 25000.0,
        'montoPago': 6000.0,
        'cantidadDepositos': 2,
        'diaPago': 15,
        'estado': 'Activo',
        'sync_state': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      });

      await db.insert('alquileres', {
        'id': 2,
        'propiedad_id': 2,
        'inquilino_id': 2,
        'fecha_inicio': '2026-09-15',
        'fecha_fin': '2027-09-14',
        'importe': 35000.0,
        'montoPago': 7000.0,
        'cantidadDepositos': 1,
        'diaPago': 20,
        'estado': 'Activo',
        'sync_state': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      });
    }

    final paymentCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM pagos'),
    );

    if (paymentCount == null || paymentCount == 0) {
      await db.insert('pagos', {
        'id': 1,
        'id_inquilino': '1',
        'id_alquiler': 1,
        'alquiler_id': 1,
        'periodo': 'Septiembre',
        'fecha_pago': '2026-09-01',
        'monto': 7000.0,
        'estado': 'pagado',
        'sync_state': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      });

      await db.insert('pagos', {
        'id': 2,
        'id_inquilino': '2',
        'id_alquiler': 2,
        'alquiler_id': 2,
        'periodo': 'Septiembre',
        'fecha_pago': '2026-09-15',
        'monto': 6000.0,
        'estado': 'pendiente',
        'sync_state': 'pending',
        'synced_at': null,
      });
    } else {
      final existingRows = await db.query(
        'pagos',
        where: 'id_alquiler IS NULL AND alquiler_id IS NULL',
      );
      for (final row in existingRows) {
        final id = row['id'] as int;
        final inquilinoId = row['id_inquilino'];
        final alquilerId = inquilinoId == '1'
            ? 1
            : (inquilinoId == '2' ? 2 : null);
        if (alquilerId != null) {
          await db.update(
            'pagos',
            {
              'id_alquiler': alquilerId,
              'alquiler_id': alquilerId,
              'periodo': 'Mensual',
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAllRows(String tableName) async {
    final db = await database;
    return db.query(tableName, orderBy: 'id ASC');
  }

  Future<Map<String, int>> getDashboardSummary() async {
    final db = await database;
    await ensureDatabaseReady();

    final totalPropiedades =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM propiedades'),
        ) ??
        0;

    final ocupadas =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM propiedades WHERE estado = 2',
          ),
        ) ??
        0;

    final disponibles =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM propiedades WHERE estado = 1',
          ),
        ) ??
        0;

    final inquilinos =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM inquilinos'),
        ) ??
        0;

    final alquileresActivos =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM alquileres WHERE estado = 'Activo'",
          ),
        ) ??
        0;

    final pagosPendientes =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM pagos WHERE estado = 'pendiente'",
          ),
        ) ??
        0;

    final pagosRealizados =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM pagos WHERE estado = 'pagado'",
          ),
        ) ??
        0;

    return {
      'totalPropiedades': totalPropiedades,
      'ocupadas': ocupadas,
      'disponibles': disponibles,
      'inquilinos': inquilinos,
      'alquileresActivos': alquileresActivos,
      'pagosPendientes': pagosPendientes,
      'pagosRealizados': pagosRealizados,
    };
  }

  Future<int> insertPropiedad({
    required String nombre,
    required String direccion,
    required int estado,
    required double precioMensual,
    required String notas,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return db.insert('propiedades', {
      'nombre': nombre,
      'direccion': direccion,
      'estado': estado,
      'precio_mensual': precioMensual,
      'notas': notas,
      'updated_at': now,
      'sync_state': 'pending',
      'synced_at': null,
    });
  }

  Future<int> insertInquilino({
    required String nombreApellido,
    required String? correo,
    required String fechaInicioContrato,
    required int fechaPagos,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return db.insert('inquilinos', {
      'nombre_apellido': nombreApellido,
      'correo': correo,
      'fecha_inicio_contrato': fechaInicioContrato,
      'fecha_pagos': fechaPagos,
      'updated_at': now,
      'sync_state': 'pending',
      'synced_at': null,
    });
  }

  Future<int> insertPago({
    required String idInquilino,
    required String fechaPago,
    required double monto,
    required String estado,
    int? alquilerId,
    String? periodo,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return db.insert('pagos', {
      'id_inquilino': idInquilino,
      'id_alquiler': alquilerId,
      'alquiler_id': alquilerId,
      'periodo': periodo,
      'fecha_pago': fechaPago,
      'monto': monto,
      'estado': estado,
      'updated_at': now,
      'sync_state': 'pending',
      'synced_at': null,
    });
  }

  Future<List<Map<String, dynamic>>> getPagosConDetalles() async {
    final db = await database;
    await ensureDatabaseReady();
    return db.rawQuery('''
      SELECT p.*, i.nombre_apellido AS inquilino_nombre
      FROM pagos p
      LEFT JOIN inquilinos i ON i.id = CAST(p.id_inquilino AS INTEGER)
      ORDER BY p.fecha_pago DESC, p.id DESC
    ''');
  }

  Future<Map<String, dynamic>?> getAlquilerActivoByInquilinoId(
    int inquilinoId,
  ) async {
    final db = await database;
    await ensureDatabaseReady();
    final rows = await db.query(
      'alquileres',
      where: 'inquilino_id = ? AND estado = ?',
      whereArgs: [inquilinoId, 'Activo'],
      orderBy: 'fecha_inicio DESC, id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> insertAlquiler({
    required int propiedadId,
    required int inquilinoId,
    required String fechaInicio,
    String? fechaFin,
    required double importe,
    double? montoPago,
    int cantidadDepositos = 0,
    int diaPago = 1,
    required String estado,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final pago = montoPago ?? importe;

    return db.insert('alquileres', {
      'propiedad_id': propiedadId,
      'inquilino_id': inquilinoId,
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
      'importe': importe,
      'montoPago': pago,
      'cantidadDepositos': cantidadDepositos,
      'diaPago': diaPago,
      'estado': estado,
      'updated_at': now,
      'sync_state': 'pending',
      'synced_at': null,
    });
  }

  Future<int> updateAlquiler({
    required int id,
    required int propiedadId,
    required int inquilinoId,
    required String fechaInicio,
    String? fechaFin,
    required double importe,
    double? montoPago,
    int cantidadDepositos = 0,
    int diaPago = 1,
    required String estado,
  }) async {
    final db = await database;
    final pago = montoPago ?? importe;
    return db.update(
      'alquileres',
      {
        'propiedad_id': propiedadId,
        'inquilino_id': inquilinoId,
        'fecha_inicio': fechaInicio,
        'fecha_fin': fechaFin,
        'importe': importe,
        'montoPago': pago,
        'cantidadDepositos': cantidadDepositos,
        'diaPago': diaPago,
        'estado': estado,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_state': 'pending',
        'synced_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updatePropiedad({
    required int id,
    required String nombre,
    required String direccion,
    required int estado,
    required double precioMensual,
    required String notas,
  }) async {
    final db = await database;
    return db.update(
      'propiedades',
      {
        'nombre': nombre,
        'direccion': direccion,
        'estado': estado,
        'precio_mensual': precioMensual,
        'notas': notas,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_state': 'pending',
        'synced_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getPropiedadById(int id) async {
    final db = await database;
    final results = await db.query(
      'propiedades',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updatePropiedadEstado(int id, int nuevoEstado) async {
    final db = await database;
    return db.update(
      'propiedades',
      {
        'estado': nuevoEstado,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_state': 'pending',
        'synced_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getMantenimientosByPropiedadId(
    int propiedadId,
  ) async {
    final db = await database;
    await ensureDatabaseReady();
    return db.query(
      'mantenimientos',
      where: 'propiedad_id = ?',
      whereArgs: [propiedadId],
      orderBy: 'fecha DESC, id DESC',
    );
  }

  Future<int> countMantenimientosPendientesByPropiedadId(
    int propiedadId,
  ) async {
    final db = await database;
    await ensureDatabaseReady();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(1) AS cantidad
      FROM mantenimientos
      WHERE propiedad_id = ? AND estado IN (?, ?)
      ''',
      [propiedadId, 'Pendiente', 'En proceso'],
    );
    return (result.first['cantidad'] as int?) ?? 0;
  }

  Future<int> insertMantenimiento({
    required int propiedadId,
    required String descripcion,
    required String fecha,
    required double costo,
    required String estado,
  }) async {
    final db = await database;
    return db.insert('mantenimientos', {
      'propiedad_id': propiedadId,
      'descripcion': descripcion,
      'fecha': fecha,
      'costo': costo,
      'estado': estado,
      'updated_at': DateTime.now().toIso8601String(),
      'sync_state': 'pending',
      'synced_at': null,
    });
  }

  Future<int> updateMantenimiento({
    required int id,
    required int propiedadId,
    required String descripcion,
    required String fecha,
    required double costo,
    required String estado,
  }) async {
    final db = await database;
    return db.update(
      'mantenimientos',
      {
        'propiedad_id': propiedadId,
        'descripcion': descripcion,
        'fecha': fecha,
        'costo': costo,
        'estado': estado,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_state': 'pending',
        'synced_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMantenimiento(int id) async {
    final db = await database;
    return db.delete('mantenimientos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateInquilino({
    required int id,
    required String nombreApellido,
    required String? correo,
    required String fechaInicioContrato,
    required int fechaPagos,
  }) async {
    final db = await database;
    return db.update(
      'inquilinos',
      {
        'nombre_apellido': nombreApellido,
        'correo': correo,
        'fecha_inicio_contrato': fechaInicioContrato,
        'fecha_pagos': fechaPagos,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_state': 'pending',
        'synced_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> getInquilinoById(int id) async {
    final db = await database;
    final results = await db.query(
      'inquilinos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAlquileresConDetalles() async {
    final db = await database;
    await ensureDatabaseReady();
    return db.rawQuery('''
      SELECT a.*, p.nombre AS propiedad_nombre, i.nombre_apellido AS inquilino_nombre
      FROM alquileres a
      LEFT JOIN propiedades p ON p.id = a.propiedad_id
      LEFT JOIN inquilinos i ON i.id = a.inquilino_id
      ORDER BY a.fecha_inicio DESC, a.id DESC
    ''');
  }

  Future<Map<String, dynamic>?> getAlquilerById(int id) async {
    final db = await database;
    await ensureDatabaseReady();
    final results = await db.rawQuery(
      '''
      SELECT a.*, p.nombre AS propiedad_nombre, i.nombre_apellido AS inquilino_nombre
      FROM alquileres a
      LEFT JOIN propiedades p ON p.id = a.propiedad_id
      LEFT JOIN inquilinos i ON i.id = a.inquilino_id
      WHERE a.id = ?
      LIMIT 1
    ''',
      [id],
    );
    return results.isEmpty ? null : results.first;
  }

  Future<List<Map<String, dynamic>>> getPagosByInquilinoId(
    int inquilinoId,
  ) async {
    final db = await database;
    return db.query(
      'pagos',
      where: 'id_inquilino = ? OR id_inquilino = ?',
      whereArgs: [inquilinoId.toString(), inquilinoId],
      orderBy: 'fecha_pago DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPagosByAlquilerId(
    int alquilerId, {
    int? inquilinoId,
  }) async {
    final db = await database;
    await ensureDatabaseReady();

    final whereParts = <String>[];
    final whereArgs = <Object>[];

    whereParts.add('(id_alquiler = ? OR alquiler_id = ?)');
    whereArgs.addAll([alquilerId, alquilerId]);

    if (inquilinoId != null) {
      whereParts.add('(id_inquilino = ? OR id_inquilino = ?)');
      whereArgs.addAll([inquilinoId.toString(), inquilinoId]);
    }

    final where = whereParts.join(' OR ');
    return db.query(
      'pagos',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'fecha_pago ASC',
    );
  }

  Future<int> updatePago({
    required int id,
    required String idInquilino,
    required String fechaPago,
    required double monto,
    required String estado,
  }) async {
    final db = await database;
    return db.update(
      'pagos',
      {
        'id_inquilino': idInquilino,
        'fecha_pago': fechaPago,
        'monto': monto,
        'estado': estado,
        'updated_at': DateTime.now().toIso8601String(),
        'sync_state': 'pending',
        'synced_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePropiedad(int id) async {
    final db = await database;
    return db.delete('propiedades', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAlquiler(int id) async {
    final db = await database;
    return db.delete('alquileres', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteInquilino(int id) async {
    final db = await database;
    return db.delete('inquilinos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deletePago(int id) async {
    final db = await database;
    return db.delete('pagos', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getPagoById(int id) async {
    final db = await database;
    final rows = await db.query(
      'pagos',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getPagoByIdConDetalle(int id) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT p.*, i.nombre_apellido AS inquilino_nombre
      FROM pagos p
      LEFT JOIN inquilinos i ON i.id = CAST(p.id_inquilino AS INTEGER)
      WHERE p.id = ?
      LIMIT 1
    ''',
      [id],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getPagosByEstado(String estado) async {
    final db = await database;
    return db.query(
      'pagos',
      where: 'estado = ?',
      whereArgs: [estado],
      orderBy: 'fecha_pago DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPagosByMes(String yearMonth) async {
    // yearMonth format: '2026-09'
    final db = await database;
    return db.query(
      'pagos',
      where: "fecha_pago LIKE ?",
      whereArgs: ['$yearMonth%'],
      orderBy: 'fecha_pago DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingRows(String tableName) async {
    final db = await database;
    return db.query(tableName, where: 'sync_state = ?', whereArgs: ['pending']);
  }

  Future<void> upsertSyncedRow(
    String tableName,
    Map<String, dynamic> values,
  ) async {
    final db = await database;
    await db.insert(
      tableName,
      {
        ...values,
        'sync_state': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> logSync(
    String entityName,
    String action,
    String status,
    String message,
  ) async {
    final db = await database;
    await db.insert('sync_log', {
      'entity_name': entityName,
      'action': action,
      'status': status,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markSynced(String tableName, int id) async {
    final db = await database;
    await db.update(
      tableName,
      {'sync_state': 'synced', 'synced_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
