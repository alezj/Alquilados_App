/// Rutas relativas centralizadas de la API ASP.NET Core.
///
/// Principio arquitectónico:
/// NUNCA escribir URLs hardcodeadas en datasources o servicios.
/// Toda ruta de endpoint debe provenir de esta clase.
///
/// Comparación con Angular:
/// Equivale a un archivo `api-endpoints.constants.ts`.
abstract final class ApiEndpoints {
  // --- Autenticación y Cuentas ---
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh-token';
  static const String profile = '/auth/profile';

  // --- Dashboard ---
  static const String dashboardStats = '/dashboard/stats';

  // --- Propiedades / Inmuebles ---
  static const String propiedades = '/propiedades';
  static String propiedadById(int id) => '/propiedades/$id';
  static String propiedadInquilino(int id) => '/propiedades/$id/inquilino';

  // --- Inquilinos ---
  static const String inquilinos = '/inquilinos';
  static String inquilinoById(int id) => '/inquilinos/$id';
  static String inquilinoHistorialPagos(int id) => '/inquilinos/$id/pagos';

  // --- Pagos ---
  static const String pagos = '/pagos';
  static String pagoById(int id) => '/pagos/$id';
  static const String registrarPago = '/pagos';

  // --- Alquileres / Contratos ---
  static const String alquileres = '/alquileres';
  static String alquilerById(int id) => '/alquileres/$id';
}
