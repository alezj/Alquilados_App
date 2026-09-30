import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/pago.dart';

// ──────────────────────────────────────────────
// Helper
// ──────────────────────────────────────────────

Pago _rowToPago(Map<String, dynamic> row) => Pago(
      id: row['id'] as int,
      idInquilino: (row['id_inquilino'] ?? '').toString(),
      inquilinoNombre: (row['inquilino_nombre'] ?? '').toString(),
      fechaPago: (row['fecha_pago'] ?? '').toString(),
      monto: (row['monto'] as num?)?.toDouble() ?? 0,
      estado: (row['estado'] ?? 'pendiente').toString(),
      syncState: (row['sync_state'] ?? 'pending').toString(),
      syncedAt: row['synced_at']?.toString(),
    );

// ──────────────────────────────────────────────
// Providers base
// ──────────────────────────────────────────────

/// Carga todos los pagos desde SQLite.
final pagosProvider = FutureProvider<List<Pago>>((ref) async {
  final database = LocalDatabaseService();
  await database.ensureSeedData();
  final rows = await database.getAllRows('pagos');
  return rows.map(_rowToPago).toList(growable: false);
});

/// Detalle de un pago individual por ID.
final pagoDetalleProvider =
    FutureProvider.family<Pago?, int>((ref, id) async {
  final database = LocalDatabaseService();
  final row = await database.getPagoById(id);
  return row == null ? null : _rowToPago(row);
});

// ──────────────────────────────────────────────
// Estado de filtros
// ──────────────────────────────────────────────

/// Opciones de filtro disponibles.
enum FiltroEstadoPago { todos, pendiente, pagado, vencido }

class PagosFiltroState {
  const PagosFiltroState({
    this.estado = FiltroEstadoPago.todos,
    this.yearMonth, // e.g. '2026-09'
    this.busqueda = '',
  });

  final FiltroEstadoPago estado;
  final String? yearMonth;
  final String busqueda;

  PagosFiltroState copyWith({
    FiltroEstadoPago? estado,
    Object? yearMonth = const _Sentinel(),
    String? busqueda,
  }) =>
      PagosFiltroState(
        estado: estado ?? this.estado,
        yearMonth: yearMonth is _Sentinel ? this.yearMonth : yearMonth as String?,
        busqueda: busqueda ?? this.busqueda,
      );
}

class _Sentinel {
  const _Sentinel();
}

class PagosFiltroNotifier extends Notifier<PagosFiltroState> {
  @override
  PagosFiltroState build() => const PagosFiltroState();

  void setEstado(FiltroEstadoPago estado) {
    state = state.copyWith(estado: estado);
  }

  void setYearMonth(String? yearMonth) {
    state = state.copyWith(yearMonth: yearMonth);
  }

  void setBusqueda(String busqueda) {
    state = state.copyWith(busqueda: busqueda);
  }

  void reset() => state = const PagosFiltroState();
}

final pagosFiltroProvider =
    NotifierProvider<PagosFiltroNotifier, PagosFiltroState>(
  PagosFiltroNotifier.new,
);

// ──────────────────────────────────────────────
// Provider derivado con filtros aplicados
// ──────────────────────────────────────────────

final pagosFiltradosProvider = FutureProvider<List<Pago>>((ref) async {
  final todos = await ref.watch(pagosProvider.future);
  final filtro = ref.watch(pagosFiltroProvider);

  var resultado = todos;

  // Filtrar por estado
  if (filtro.estado != FiltroEstadoPago.todos) {
    final estadoStr = filtro.estado.name; // 'pendiente', 'pagado', 'vencido'
    resultado = resultado.where((p) => p.estado == estadoStr).toList();
  }

  // Filtrar por mes (yearMonth: '2026-09')
  if (filtro.yearMonth != null && filtro.yearMonth!.isNotEmpty) {
    resultado = resultado
        .where((p) => p.fechaPago.startsWith(filtro.yearMonth!))
        .toList();
  }

  // Filtrar por búsqueda libre (inquilino ID o monto)
  if (filtro.busqueda.isNotEmpty) {
    final q = filtro.busqueda.toLowerCase();
    resultado = resultado
        .where(
          (p) =>
              p.idInquilino.toLowerCase().contains(q) ||
              p.monto.toString().contains(q) ||
              p.estado.toLowerCase().contains(q),
        )
        .toList();
  }

  return resultado;
});
