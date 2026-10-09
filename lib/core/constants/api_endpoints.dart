/// Endpoints expuestos actualmente por el backend ASP.NET Core.
///
/// Fuente de verdad: el documento OpenAPI publicado por el backend.
/// La URL base debe terminar en `/api`, por ejemplo:
/// `http://localhost:5129/api` durante el desarrollo local.
///
/// Las colecciones se sincronizan desde `SyncRepositoryImpl`, que también usa
/// las operaciones genéricas de escritura expuestas por `Backend`.
abstract final class ApiEndpoints {
  static const String _backend = '/Backend';

  // Consultas disponibles.
  static const String status = '$_backend/status';
  static const String inquilinos = '$_backend/inquilinos';
  static const String estados = '$_backend/estados';
  static const String pagos = '$_backend/pagos';
  static const String propiedades = '$_backend/propiedades';
  static const String mantenimientos = '$_backend/mantenimientos';
  static const String alquileres = '$_backend/alquileres';

  // Operaciones específicas de propiedades.
  static String propiedadById(String id) => '$_backend/propiedades/$id';

  // Operaciones genéricas permitidas por el backend para los recursos indicados.
  static String resource(String resource) => '$_backend/$resource';
  static String resourceById(String resource, String id) =>
      '$_backend/$resource/$id';
}
