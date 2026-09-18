import 'package:alquilados_app/core/errors/app_exception.dart';
import 'package:alquilados_app/core/errors/error_handler.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorHandler Tests', () {
    test('retorna la misma AppException si el error ya es AppException', () {
      const original = NetworkException();
      final result = ErrorHandler.handle(original);

      expect(result, isA<NetworkException>());
    });

    test('mapea DioExceptionType.connectionTimeout a TimeoutException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/propiedades'),
        type: DioExceptionType.connectionTimeout,
        message: 'Timed out',
      );

      final result = ErrorHandler.handle(dioException);

      expect(result, isA<TimeoutException>());
      expect(result.userMessage, contains('tardó demasiado'));
    });

    test('mapea DioExceptionType.connectionError a NetworkException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/propiedades'),
        type: DioExceptionType.connectionError,
        message: 'No internet',
      );

      final result = ErrorHandler.handle(dioException);

      expect(result, isA<NetworkException>());
      expect(result.userMessage, contains('conexión'));
    });

    test('mapea HTTP 400 Bad Request a BadRequestException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/inquilinos'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/inquilinos'),
          statusCode: 400,
          data: {'message': 'El campo nombre es requerido'},
        ),
      );

      final result = ErrorHandler.handle(dioException);

      expect(result, isA<BadRequestException>());
      expect(result.statusCode, 400);
      expect(result.userMessage, 'El campo nombre es requerido');
    });

    test('mapea HTTP 401 Unauthorized a UnauthorizedException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/profile'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/profile'),
          statusCode: 401,
          data: {'message': 'Token expirado'},
        ),
      );

      final result = ErrorHandler.handle(dioException);

      expect(result, isA<UnauthorizedException>());
      expect(result.statusCode, 401);
    });

    test('mapea HTTP 403 Forbidden a ForbiddenException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/admin/roles'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/admin/roles'),
          statusCode: 403,
        ),
      );

      final result = ErrorHandler.handle(dioException);

      expect(result, isA<ForbiddenException>());
      expect(result.statusCode, 403);
    });

    test('mapea HTTP 404 Not Found a NotFoundException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/propiedades/999'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/propiedades/999'),
          statusCode: 404,
        ),
      );

      final result = ErrorHandler.handle(dioException);

      expect(result, isA<NotFoundException>());
      expect(result.statusCode, 404);
    });

    test('mapea HTTP 500 Internal Server Error a ServerException', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/pagos'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/pagos'),
          statusCode: 500,
        ),
      );

      final result = ErrorHandler.handle(dioException);

      expect(result, isA<ServerException>());
      expect(result.statusCode, 500);
      expect(result.userMessage, contains('servidor'));
    });

    test('mapea excepciones genéricas a UnknownException', () {
      final genericError = Exception('Error desconocido de prueba');
      final result = ErrorHandler.handle(genericError);

      expect(result, isA<UnknownException>());
    });
  });
}
