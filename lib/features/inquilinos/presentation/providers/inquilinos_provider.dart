import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/inquilino.dart';

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
    );
  }).toList(growable: false);
});
