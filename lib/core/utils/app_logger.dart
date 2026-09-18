import 'package:logger/logger.dart';
import '../config/app_config.dart';

/// Mecanismo centralizado y seguro de logging para Alquilados App.
///
/// Comparación con ASP.NET Core:
/// Equivale a `ILogger<T>` con filtros y enmascaramiento de información confidencial.
///
/// Características de seguridad:
/// - Enmascara automáticamente tokens JWT, passwords y API Keys para evitar fugas.
/// - Si `AppConfig.enableLogs` es falso (ej. producción), no emite salidas en consola.
abstract final class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 5,
      lineLength: 90,
      colors: true,
      printEmojis: true,
    ),
  );

  /// Palabras clave que deben censurarse si aparecen en los logs
  static final RegExp _sensitivePattern = RegExp(
    r'(password|token|bearer|authorization|secret|key)["\s:=]+([^\s,"]+)',
    caseSensitive: false,
  );

  /// Enmascara valores sensibles en el mensaje
  static String _sanitize(String message) {
    return message.replaceAllMapped(_sensitivePattern, (match) {
      final key = match.group(1);
      return '$key: [PROTECTED]';
    });
  }

  /// Nivel Debug: Detalles técnicos útiles durante desarrollo
  static void d(dynamic message, [Object? error, StackTrace? stackTrace]) {
    if (!AppConfig.enableLogs) return;
    _logger.d(_sanitize(message.toString()), error: error, stackTrace: stackTrace);
  }

  /// Nivel Info: Eventos de flujo normales (ej: "Usuario inició sesión", "Navegando a /propiedades")
  static void i(dynamic message, [Object? error, StackTrace? stackTrace]) {
    if (!AppConfig.enableLogs) return;
    _logger.i(_sanitize(message.toString()), error: error, stackTrace: stackTrace);
  }

  /// Nivel Warning: Anomalías o advertencias no bloqueantes
  static void w(dynamic message, [Object? error, StackTrace? stackTrace]) {
    if (!AppConfig.enableLogs) return;
    _logger.w(_sanitize(message.toString()), error: error, stackTrace: stackTrace);
  }

  /// Nivel Error: Fallos de operación, excepciones de red o errores de servidor
  static void e(dynamic message, [Object? error, StackTrace? stackTrace]) {
    if (!AppConfig.enableLogs) return;
    _logger.e(_sanitize(message.toString()), error: error, stackTrace: stackTrace);
  }
}
