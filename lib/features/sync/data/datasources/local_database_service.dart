import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();

  factory LocalDatabaseService() => _instance;

  LocalDatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = kIsWeb
        ? 'alquilados_local.db3'
        : '${(await getApplicationDocumentsDirectory()).path}/alquilados_local.db3';

    return openDatabase(
      path,
      version: 1,
      onCreate: _createSchema,
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
        fecha_pago TEXT,
        monto REAL,
        estado TEXT,
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

    final paymentCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM pagos'),
    );

    if (paymentCount == null || paymentCount == 0) {
      await db.insert('pagos', {
        'id': 1,
        'id_inquilino': '1',
        'fecha_pago': '2026-09-15',
        'monto': 1650.0,
        'estado': 'pagado',
        'sync_state': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      });

      await db.insert('pagos', {
        'id': 2,
        'id_inquilino': '2',
        'fecha_pago': '2026-09-20',
        'monto': 2100.0,
        'estado': 'pendiente',
        'sync_state': 'pending',
        'synced_at': null,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getAllRows(String tableName) async {
    final db = await database;
    return db.query(tableName, orderBy: 'id ASC');
  }

  Future<Map<String, int>> getDashboardSummary() async {
    final db = await database;

    final totalPropiedades = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM propiedades'),
    ) ?? 0;

    final ocupadas = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM propiedades WHERE estado = 2'),
    ) ?? 0;

    final disponibles = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM propiedades WHERE estado = 1'),
    ) ?? 0;

    final inquilinos = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM inquilinos'),
    ) ?? 0;

    final pagosPendientes = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM pagos WHERE estado = 'pendiente'"),
    ) ?? 0;

    final pagosRealizados = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM pagos WHERE estado = 'pagado'"),
    ) ?? 0;

    return {
      'totalPropiedades': totalPropiedades,
      'ocupadas': ocupadas,
      'disponibles': disponibles,
      'inquilinos': inquilinos,
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
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return db.insert('pagos', {
      'id_inquilino': idInquilino,
      'fecha_pago': fechaPago,
      'monto': monto,
      'estado': estado,
      'updated_at': now,
      'sync_state': 'pending',
      'synced_at': null,
    });
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

  Future<int> deleteInquilino(int id) async {
    final db = await database;
    return db.delete('inquilinos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deletePago(int id) async {
    final db = await database;
    return db.delete('pagos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getPendingRows(String tableName) async {
    final db = await database;
    return db.query(
      tableName,
      where: 'sync_state = ?',
      whereArgs: ['pending'],
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
      {
        'sync_state': 'synced',
        'synced_at': DateTime.now().toIso8601String(),
      },
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
