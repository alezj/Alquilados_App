import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../sync/data/datasources/local_database_service.dart';
import '../../domain/entities/alquiler.dart';

class AlquileresFiltroState {
  const AlquileresFiltroState({this.busqueda = '', this.estado = 'todos'});

  final String busqueda;
  final String estado;

  AlquileresFiltroState copyWith({String? busqueda, String? estado}) {
    return AlquileresFiltroState(
      busqueda: busqueda ?? this.busqueda,
      estado: estado ?? this.estado,
    );
  }
}

class AlquileresFiltroController extends StateNotifier<AlquileresFiltroState> {
  AlquileresFiltroController() : super(const AlquileresFiltroState());

  void actualizarBusqueda(String value) {
    state = state.copyWith(busqueda: value);
  }

  void actualizarEstado(String value) {
    state = state.copyWith(estado: value);
  }
}

final alquileresProvider = FutureProvider<List<Alquiler>>((ref) async {
  final database = LocalDatabaseService();
  await database.ensureDatabaseReady();
  final rows = await database.getAlquileresConDetalles();
  return rows.map(Alquiler.fromMap).toList();
});

final alquileresFiltroProvider =
    StateNotifierProvider<AlquileresFiltroController, AlquileresFiltroState>(
  (ref) => AlquileresFiltroController(),
);
