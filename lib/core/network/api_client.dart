import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../errors/error_handler.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';
import 'auth_interceptor.dart';

/// Cliente HTTP centralizado basado en Dio para Alquilados App.
///
/// Comparación con Angular:
/// Equivale a un servicio centralizado envolviendo `HttpClient` con interceptors globales.
///
/// Características:
/// - Base URL configurada dinámicamente según el ambiente (dev, staging, prod).
/// - Interceptor de autenticación para inyección automática de JWT.
/// - Interceptor de logging para monitoreo de tráfico en desarrollo.
/// - Captura y transformación automática de todas las excepciones a [AppException].
class ApiClient {
  ApiClient({
    required SecureStorageService secureStorage,
    Dio? customDio,
    VoidCallback? onUnauthorized,
  }) {
    _dio = customDio ??
        Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: Duration(milliseconds: AppConfig.connectTimeoutMs),
            receiveTimeout: Duration(milliseconds: AppConfig.receiveTimeoutMs),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    // 1. Interceptor de autenticación (JWT)
    _dio.interceptors.add(
      AuthInterceptor(
        secureStorage: secureStorage,
        onUnauthorized: onUnauthorized,
      ),
    );

    // 2. Interceptor de logging (solo si está habilitado en el ambiente)
    if (AppConfig.enableLogs) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            AppLogger.d('HTTP --> ${options.method} ${options.baseUrl}${options.path}');
            return handler.next(options);
          },
          onResponse: (response, handler) {
            AppLogger.d('HTTP <-- ${response.statusCode} ${response.requestOptions.path}');
            return handler.next(response);
          },
          onError: (dioError, handler) {
            AppLogger.w('HTTP <-- ERROR ${dioError.response?.statusCode} ${dioError.requestOptions.path}');
            return handler.next(dioError);
          },
        ),
      );
    }
  }

  late final Dio _dio;

  /// Acceso a la instancia subyacente de Dio si se requiere funcionalidad avanzada
  Dio get rawDio => _dio;

  /// Petición HTTP GET tipada con manejo automático de errores
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } catch (e, s) {
      throw ErrorHandler.handle(e, s);
    }
  }

  /// Petición HTTP POST tipada con manejo automático de errores
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } catch (e, s) {
      throw ErrorHandler.handle(e, s);
    }
  }

  /// Petición HTTP PUT tipada con manejo automático de errores
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } catch (e, s) {
      throw ErrorHandler.handle(e, s);
    }
  }

  /// Petición HTTP DELETE tipada con manejo automático de errores
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } catch (e, s) {
      throw ErrorHandler.handle(e, s);
    }
  }

  /// Petición HTTP PATCH tipada con manejo automático de errores
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } catch (e, s) {
      throw ErrorHandler.handle(e, s);
    }
  }
}
