import '../../domain/entities/pago.dart';
import '../../domain/repositories/pagos_repository.dart';
import '../datasources/pagos_remote_data_source.dart';

class PagosRepositoryImpl implements PagosRepository {
  const PagosRepositoryImpl(this._remoteDataSource);
  final PagosRemoteDataSource _remoteDataSource;
  @override
  Future<List<Pago>> obtenerPagos() => _remoteDataSource.obtenerPagos();
}
