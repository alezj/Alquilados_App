import '../entities/pago.dart';

abstract interface class PagosRepository {
  Future<List<Pago>> obtenerPagos();
}
