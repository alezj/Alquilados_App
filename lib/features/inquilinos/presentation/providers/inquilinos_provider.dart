import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/inquilino.dart';
import '../../../pagos/domain/entities/pago.dart';

final inquilinosProvider = FutureProvider<List<Inquilino>>((ref) async {
  final database = LocalDatabaseService();
  await database.ensureSeedData();

  final rows = await database.getAllRows('inquilinos');
  return rows.map((row) {
    return Inquilino(
      id: row['id'] as int,
      nombreApellido: (row['nombre_apellido'] ?? '').toString(),
      correo: (row['correo'] ?? '').toString().isEmpty ? null : (row['correo'] ?? '').toString(),
      fechaInicioContrato: (row['fecha_inicio_contrato'] ?? '').toString(),
      fechaPagos: (row['fecha_pagos'] as int?) ?? 0,
      syncState: (row['sync_state'] ?? 'pending').toString(),
      syncedAt: row['synced_at']?.toString(),
    );
  }).toList(growable: false);
});

final inquilinoDetalleProvider = FutureProvider.family<Inquilino?, int>((ref, id) async {
  final database = LocalDatabaseService();
  await database.ensureSeedData();

  final row = await database.getInquilinoById(id);
  if (row == null) return null;

  return Inquilino(
    id: row['id'] as int,
    nombreApellido: (row['nombre_apellido'] ?? '').toString(),
    correo: (row['correo'] ?? '').toString().isEmpty ? null : (row['correo'] ?? '').toString(),
    fechaInicioContrato: (row['fecha_inicio_contrato'] ?? '').toString(),
    fechaPagos: (row['fecha_pagos'] as int?) ?? 0,
    syncState: (row['sync_state'] ?? 'pending').toString(),
    syncedAt: row['synced_at']?.toString(),
  );
});

final pagosDeInquilinoProvider = FutureProvider.family<List<Pago>, int>((ref, inquilinoId) async {
  final database = LocalDatabaseService();
  await database.ensureSeedData();

  final rows = await database.getPagosByInquilinoId(inquilinoId);
  return rows.map((row) {
    return Pago(
      id: row['id'] as int,
      idInquilino: (row['id_inquilino'] ?? '').toString(),
      inquilinoNombre: (row['inquilino_nombre'] ?? '').toString(),
      fechaPago: (row['fecha_pago'] ?? '').toString(),
      monto: (row['monto'] as num?)?.toDouble() ?? 0,
      estado: (row['estado'] ?? 'pendiente').toString(),
      syncState: (row['sync_state'] ?? 'pending').toString(),
      syncedAt: row['synced_at']?.toString(),
    );
  }).toList(growable: false);
});
