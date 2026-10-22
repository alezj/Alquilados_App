import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import '../utils/app_logger.dart';

/// Interceptor de Dio para inyectar automáticamente el JWT en las cabeceras HTTP.
///
/// Comparación con Angular:
/// Equivale a un `AuthInterceptor implements HttpInterceptor` en Angular
/// que intercepta la `HttpRequest` y le hace `req.clone({ setHeaders: { Authorization: ... } })`.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.secureStorage,
    required this.dio,
    this.onUnauthorized,
  });

  final SecureStorageService secureStorage;
  final Dio dio;

  /// Callback ejecutado cuando el servidor responde con 401 (ej: token expirado)
  final VoidCallback? onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await secureStorage.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      } else {
        options.headers.remove('Authorization');
      }
    } catch (e) {
      AppLogger.w(
        'No se pudo adjuntar el token a la petición: ${options.path}',
      );
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      AppLogger.w(
        'Sesión expirada o no autorizada (HTTP 401) en ${err.requestOptions.path}',
      );
      if (err.requestOptions.extra['sessionRefreshAttempted'] != true) {
        try {
          final refreshToken = await secureStorage.getRefreshToken();
          if (refreshToken == null || refreshToken.isEmpty) {
            throw StateError('No hay refresh token disponible.');
          }
          final authDio = Dio(
            BaseOptions(
              baseUrl:
                  '${AppConfig.supabaseUrl.replaceAll(RegExp(r'/+$'), '')}/',
              headers: {
                'apikey': AppConfig.supabasePublishableKey,
                'Content-Type': 'application/json',
              },
            ),
          );
          final refreshed = await authDio.post<Map<String, dynamic>>(
            'auth/v1/token?grant_type=refresh_token',
            data: {'refresh_token': refreshToken},
          );
          final data = refreshed.data ?? const <String, dynamic>{};
          final token = data['access_token']?.toString();
          final nextRefresh = data['refresh_token']?.toString();
          if (token == null || token.isEmpty) {
            throw StateError('Supabase no devolvió un access token.');
          }
          await secureStorage.saveToken(token);
          if (nextRefresh != null)
            await secureStorage.saveRefreshToken(nextRefresh);
          final request = err.requestOptions
            ..headers['Authorization'] = 'Bearer $token'
            ..extra['sessionRefreshAttempted'] = true;
          final response = await dio.fetch<dynamic>(request);
          return handler.resolve(response);
        } catch (error) {
          AppLogger.w('No se pudo renovar la sesión: $error');
          await secureStorage.clearSession();
          onUnauthorized?.call();
        }
      } else {
        await secureStorage.clearSession();
        onUnauthorized?.call();
      }
    }
    return handler.next(err);
  }
}
