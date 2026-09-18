/// Clase base para todas las excepciones controladas de Alquilados App.
///
/// Comparación con ASP.NET Core:
/// Equivale a definir una jerarquía de excepciones de negocio (`DomainException`, `NotFoundException`, etc.)
/// que luego el middleware de excepciones mapea a `ProblemDetails`.
///
/// Principio clave:
/// Diferencia siempre entre [message] (técnico para logging/debug)
/// y [userMessage] (amigable, seguro y comprensible para mostrar en la UI).
sealed class AppException implements Exception {
  const AppException({
    required this.message,
    required this.userMessage,
    this.statusCode,
  });

  /// Mensaje técnico (para consola/logs)
  final String message;

  /// Mensaje amigable en español (para la interfaz de usuario)
  final String userMessage;

  /// Código de estado HTTP si aplica
  final int? statusCode;

  @override
  String toString() => '$runtimeType(statusCode: $statusCode, message: $message, userMessage: $userMessage)';
}

/// Fallo de conexión de red (sin internet, DNS no resuelto, etc.)
final class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No internet connection',
    super.userMessage = 'No tienes conexión a internet. Verifica tu red Wi-Fi o datos móviles.',
  });
}

/// Timeout de conexión o respuesta del servidor
final class TimeoutException extends AppException {
  const TimeoutException({
    super.message = 'Connection or receive timeout',
    super.userMessage = 'El servidor tardó demasiado en responder. Intenta nuevamente.',
  });
}

/// HTTP 400: Petición inválida o errores de validación de formulario
final class BadRequestException extends AppException {
  const BadRequestException({
    super.message = 'Bad Request',
    super.userMessage = 'Los datos enviados son incorrectos o están incompletos.',
    super.statusCode = 400,
    this.errors,
  });

  /// Diccionario opcional de errores por campo devuelto por ASP.NET Core
  /// Ejemplo: { "email": ["El formato de correo es inválido"] }
  final Map<String, dynamic>? errors;
}

/// HTTP 401: No autorizado (token expirado o credenciales inválidas)
final class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = 'Unauthorized',
    super.userMessage = 'Tu sesión ha expirado o tus credenciales son incorrectas.',
    super.statusCode = 401,
  });
}

/// HTTP 403: Prohibido (el usuario autenticado no tiene permisos para este recurso)
final class ForbiddenException extends AppException {
  const ForbiddenException({
    super.message = 'Forbidden',
    super.userMessage = 'No tienes permisos suficientes para realizar esta acción.',
    super.statusCode = 403,
  });
}

/// HTTP 404: Recurso no encontrado (inmueble, inquilino o pago inexistente)
final class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'Resource Not Found',
    super.userMessage = 'El recurso solicitado no fue encontrado.',
    super.statusCode = 404,
  });
}

/// HTTP 409: Conflicto (ej: registrar un inquilino con una cédula/documento ya existente)
final class ConflictException extends AppException {
  const ConflictException({
    super.message = 'Conflict',
    super.userMessage = 'Existe un conflicto con los datos proporcionados (ej. registro duplicado).',
    super.statusCode = 409,
  });
}

/// HTTP 500/502/503: Error interno del servidor ASP.NET Core o base de datos
final class ServerException extends AppException {
  const ServerException({
    super.message = 'Internal Server Error',
    super.userMessage = 'No pudimos completar la operación en el servidor. Intenta nuevamente en unos momentos.',
    super.statusCode = 500,
  });
}

/// Fallo al leer o escribir en almacenamiento local seguro
final class StorageException extends AppException {
  const StorageException({
    super.message = 'Local storage operation failed',
    super.userMessage = 'Ocurrió un problema con el almacenamiento del dispositivo.',
  });
}

/// Excepción no catalogada
final class UnknownException extends AppException {
  const UnknownException({
    super.message = 'An unexpected error occurred',
    super.userMessage = 'Ocurrió un error inesperado. Por favor intenta de nuevo.',
    super.statusCode,
  });
}
