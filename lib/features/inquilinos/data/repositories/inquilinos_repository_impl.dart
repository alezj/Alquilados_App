import '../../domain/entities/inquilino.dart';
import '../../domain/repositories/inquilinos_repository.dart';
import '../datasources/inquilinos_remote_data_source.dart';

class InquilinosRepositoryImpl implements InquilinosRepository {
  const InquilinosRepositoryImpl(this._remoteDataSource);
  final InquilinosRemoteDataSource _remoteDataSource;

  @override
  Future<List<Inquilino>> obtenerInquilinos() =>
      _remoteDataSource.obtenerInquilinos();
}
