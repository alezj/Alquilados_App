import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/datasources/inquilinos_remote_data_source.dart';
import '../../data/repositories/inquilinos_repository_impl.dart';
import '../../domain/entities/inquilino.dart';
import '../../domain/repositories/inquilinos_repository.dart';

final inquilinosRepositoryProvider = Provider<InquilinosRepository>(
  (ref) => InquilinosRepositoryImpl(
    InquilinosRemoteDataSource(ref.watch(apiClientProvider)),
  ),
);

final inquilinosProvider = FutureProvider<List<Inquilino>>(
  (ref) => ref.watch(inquilinosRepositoryProvider).obtenerInquilinos(),
);
