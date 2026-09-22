import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/datasources/propiedades_remote_data_source.dart';
import '../../data/repositories/propiedades_repository_impl.dart';
import '../../domain/entities/propiedad.dart';
import '../../domain/repositories/propiedades_repository.dart';

final propiedadesRepositoryProvider = Provider<PropiedadesRepository>((ref) {
  return PropiedadesRepositoryImpl(
    PropiedadesRemoteDataSource(ref.watch(apiClientProvider)),
  );
});

final propiedadesProvider = FutureProvider<List<Propiedad>>((ref) {
  return ref.watch(propiedadesRepositoryProvider).obtenerPropiedades();
});
