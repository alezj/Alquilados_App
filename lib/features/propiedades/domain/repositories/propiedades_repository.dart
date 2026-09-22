import '../entities/propiedad.dart';

abstract interface class PropiedadesRepository {
  Future<List<Propiedad>> obtenerPropiedades();
}
