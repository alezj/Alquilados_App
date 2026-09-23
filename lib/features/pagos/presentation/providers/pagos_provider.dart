import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/pago.dart';

final pagosProvider = FutureProvider<List<Pago>>((ref) async {
  final database = LocalDatabaseService();
  await database.ensureSeedData();

  final rows = await database.getAllRows('pagos');
  return rows.map((row) {
    return Pago(
      id: row['id'] as int,
      idInquilino: (row['id_inquilino'] ?? '').toString(),
      fechaPago: (row['fecha_pago'] ?? '').toString(),
      monto: (row['monto'] as num?)?.toDouble() ?? 0,
    );
  }).toList(growable: false);
});
