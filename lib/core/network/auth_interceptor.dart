import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';

/// Interceptor de Dio para inyectar automáticamente el JWT en las cabeceras HTTP.
///
/// Comparación con Angular:
/// Equivale a un `AuthInterceptor implements HttpInterceptor` en Angular
/// que intercepta la `HttpRequest` y le hace `req.clone({ setHeaders: { Authorization: ... } })`.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required SecureStorageService secureStorage,
    this.onUnauthorized,
  }) : _secureStorage = secureStorage;

  final SecureStorageService _secureStorage;

  /// Callback ejecutado cuando el servidor responde con 401 (ej: token expirado)
  final VoidCallback? onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Si la petición ya tiene Authorization o es el endpoint de login, continuar sin inyectar
    if (options.headers.containsKey('Authorization') ||
        options.path.contains('/auth/login')) {
      return handler.next(options);
    }

    try {
      final token = await _secureStorage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      AppLogger.w('No se pudo adjuntar el token a la petición: ${options.path}');
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      AppLogger.w('Sesión expirada o no autorizada (HTTP 401) en ${err.requestOptions.path}');
      onUnauthorized?.call();
    }
    return handler.next(err);
  }
}
