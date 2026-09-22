import '../entities/inquilino.dart';

abstract interface class InquilinosRepository {
  Future<List<Inquilino>> obtenerInquilinos();
}
