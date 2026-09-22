import '../../domain/entities/propiedad.dart';
import '../../domain/repositories/propiedades_repository.dart';
import '../datasources/propiedades_remote_data_source.dart';

class PropiedadesRepositoryImpl implements PropiedadesRepository {
  const PropiedadesRepositoryImpl(this._remoteDataSource);

  final PropiedadesRemoteDataSource _remoteDataSource;

  @override
  Future<List<Propiedad>> obtenerPropiedades() =>
      _remoteDataSource.obtenerPropiedades();
}
