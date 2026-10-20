/// Tablas expuestas por la API REST de Supabase (PostgREST).
abstract final class ApiEndpoints {
  static const String inquilinos = 'inquilinos?Origen=eq.movil&usuario=eq.00000000-0000-0000-0000-000000000000&select=*';
  static const String estados = 'estados?Origen=eq.movil&usuario=eq.00000000-0000-0000-0000-000000000000&select=*';
  static const String pagos = 'pagos?Origen=eq.movil&usuario=eq.00000000-0000-0000-0000-000000000000&select=*';
  static const String propiedades = 'propiedades?Origen=eq.movil&usuario=eq.00000000-0000-0000-0000-000000000000&select=*';
  static const String mantenimientos = 'mantenimientos?Origen=eq.movil&usuario=eq.00000000-0000-0000-0000-000000000000&select=*';
  static const String alquileres = 'alquileres?Origen=eq.movil&usuario=eq.00000000-0000-0000-0000-000000000000&select=*';

  // Operaciones específicas de propiedades.
  static String propiedadById(String id) => 'propiedades?id=eq.$id&select=*';

  // Operaciones genéricas permitidas por el backend para los recursos indicados.
  static String resource(String resource) => resource;
  static String resourceById(String resource, String id) =>
      '$resource?id=eq.$id';
}
