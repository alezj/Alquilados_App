/// Tipos de ambientes soportados por la aplicación
enum AppEnvironment { dev, staging, prod }

/// Configuración centralizada de la aplicación Alquilados.
///
/// Los valores se inyectan en tiempo de compilación utilizando `--dart-define`
/// o `--dart-define-from-file=env/dev.json`.
///
/// Comparación con ASP.NET Core:
/// Equivale a `IConfiguration` leyendo de `appsettings.json`.
///
/// Comparación con Angular:
/// Equivale al archivo `src/environments/environment.ts`.
abstract final class AppConfig {
  /// Ambiente actual (dev, staging, prod)
  static const String _envString = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static AppEnvironment get environment {
    switch (_envString.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'staging':
      case 'qa':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.dev;
    }
  }

  /// URL REST del proyecto Supabase.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://plkbprmponbtwfxglmzm.supabase.co',
  );

  /// Clave publicable de cliente. Nunca colocar aquí una secret/service role key.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_E1IkI3HGl5uZenUfVCLgLg_HQ98n1hC',
  );

  static String get apiBaseUrl => '${supabaseUrl.replaceAll(RegExp(r'/+$'), '')}/rest/v1/';

  /// Habilitar logs en consola (se desactiva por defecto en producción)
  static const bool enableLogs = bool.fromEnvironment(
    'ENABLE_LOGS',
    defaultValue: true,
  );

  /// Timeout de conexión HTTP en milisegundos (por defecto 15 segundos)
  static const int connectTimeoutMs = int.fromEnvironment(
    'CONNECT_TIMEOUT_MS',
    defaultValue: 15000,
  );

  /// Timeout de recepción HTTP en milisegundos (por defecto 15 segundos)
  static const int receiveTimeoutMs = int.fromEnvironment(
    'RECEIVE_TIMEOUT_MS',
    defaultValue: 15000,
  );

  /// Helper para comprobar si estamos en modo desarrollo
  static bool get isDev => environment == AppEnvironment.dev;

  /// Helper para comprobar si estamos en modo producción
  static bool get isProd => environment == AppEnvironment.prod;
}
