import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/datasources/pagos_remote_data_source.dart';
import '../../data/repositories/pagos_repository_impl.dart';
import '../../domain/entities/pago.dart';
import '../../domain/repositories/pagos_repository.dart';

final pagosRepositoryProvider = Provider<PagosRepository>(
  (ref) =>
      PagosRepositoryImpl(PagosRemoteDataSource(ref.watch(apiClientProvider))),
);
final pagosProvider = FutureProvider<List<Pago>>(
  (ref) => ref.watch(pagosRepositoryProvider).obtenerPagos(),
);
