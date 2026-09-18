import 'package:dio/dio.dart';
import '../utils/app_logger.dart';
import 'app_exception.dart';

/// Mapeador centralizado para convertir excepciones técnicas en [AppException] tipadas.
///
/// Comparación con Angular:
/// Equivale a la función de mapeo dentro de un `HttpErrorInterceptor` de Angular.
abstract final class ErrorHandler {
  /// Convierte cualquier error en una [AppException] estructurada y amigable
  static AppException handle(dynamic error, [StackTrace? stackTrace]) {
    // 1. Si ya es una AppException, retornarla directamente
    if (error is AppException) {
      return error;
    }

    // 2. Si es una excepción de red de Dio
    if (error is DioException) {
      return _handleDioException(error, stackTrace);
    }

    // 3. Cualquier otra excepción inesperada
    AppLogger.e('Excepción no controlada detectada', error, stackTrace);
    return UnknownException(
      message: error.toString(),
      userMessage: 'Ocurrió un error inesperado. Por favor intenta de nuevo.',
    );
  }

  static AppException _handleDioException(DioException dioError, StackTrace? stackTrace) {
    AppLogger.w(
      'DioException: [${dioError.type}] ${dioError.requestOptions.method} ${dioError.requestOptions.path} -> Status: ${dioError.response?.statusCode}',
      dioError,
    );

    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutException(
          message: 'Timeout: ${dioError.message}',
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          message: 'Connection error: ${dioError.message}',
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(dioError.response);

      case DioExceptionType.cancel:
        return const UnknownException(
          message: 'La petición fue cancelada por el usuario o por la aplicación.',
          userMessage: 'Operación cancelada.',
        );

      case DioExceptionType.badCertificate:
        return const NetworkException(
          message: 'Error de certificado SSL/TLS',
          userMessage: 'No se pudo verificar la seguridad de la conexión con el servidor.',
        );

      case DioExceptionType.unknown:
        final underlying = dioError.error;
        if (underlying != null && underlying.toString().contains('SocketException')) {
          return const NetworkException();
        }
        return UnknownException(
          message: dioError.message ?? 'Unknown Dio error',
        );
    }
  }

  static AppException _handleBadResponse(Response? response) {
    final statusCode = response?.statusCode ?? 500;
    final dynamic data = response?.data;

    // Intentar extraer el mensaje enviado por ASP.NET Core si existe
    // ASP.NET Core suele devolver:
    // { "message": "..." } o { "title": "...", "errors": { ... } } (ProblemDetails)
    String? apiMessage;
    Map<String, dynamic>? fieldErrors;

    if (data is Map<String, dynamic>) {
      if (data.containsKey('message') && data['message'] is String) {
        apiMessage = data['message'] as String;
      } else if (data.containsKey('title') && data['title'] is String) {
        apiMessage = data['title'] as String;
      }

      if (data.containsKey('errors') && data['errors'] is Map<String, dynamic>) {
        fieldErrors = data['errors'] as Map<String, dynamic>;
      }
    }

    switch (statusCode) {
      case 400:
        return BadRequestException(
          message: 'Bad Request 400: $apiMessage',
          userMessage: apiMessage ?? 'Los datos proporcionados son inválidos. Revisa el formulario.',
          errors: fieldErrors,
        );

      case 401:
        return UnauthorizedException(
          message: 'Unauthorized 401: $apiMessage',
          userMessage: apiMessage ?? 'Tu sesión ha expirado o las credenciales no son válidas.',
        );

      case 403:
        return ForbiddenException(
          message: 'Forbidden 403: $apiMessage',
          userMessage: apiMessage ?? 'No tienes permisos para acceder a esta información.',
        );

      case 404:
        return NotFoundException(
          message: 'Not Found 404: $apiMessage',
          userMessage: apiMessage ?? 'El registro solicitado no fue encontrado.',
        );

      case 409:
        return ConflictException(
          message: 'Conflict 409: $apiMessage',
          userMessage: apiMessage ?? 'Existe un conflicto con este registro (posible duplicado).',
        );

      case >= 500 && <= 599:
        return ServerException(
          message: 'Server Error $statusCode: $apiMessage',
          userMessage: 'El servidor encontró un problema interno. Intenta más tarde.',
          statusCode: statusCode,
        );

      default:
        return UnknownException(
          message: 'HTTP Status $statusCode: $apiMessage',
          statusCode: statusCode,
        );
    }
  }
}
