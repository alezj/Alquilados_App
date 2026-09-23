import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/propiedad.dart';

final propiedadesProvider = FutureProvider<List<Propiedad>>((ref) async {
  final database = LocalDatabaseService();
  await database.ensureSeedData();

  final rows = await database.getAllRows('propiedades');
  return rows.map((row) {
    return Propiedad(
      id: row['id'] as int,
      nombre: (row['nombre'] ?? '').toString(),
      direccion: (row['direccion'] ?? '').toString(),
      estado: (row['estado'] as int?) ?? 0,
      precioMensual: (row['precio_mensual'] as num?)?.toDouble() ?? 0,
      notas: (row['notas'] ?? '').toString(),
    );
  }).toList(growable: false);
});
