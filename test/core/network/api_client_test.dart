import 'package:alquilados_app/core/errors/app_exception.dart';
import 'package:alquilados_app/core/network/api_client.dart';
import 'package:alquilados_app/core/storage/secure_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorageService extends Mock implements SecureStorageService {}
class MockDio extends Mock implements Dio {}

void main() {
  late MockSecureStorageService mockSecureStorage;
  late MockDio mockDio;
  late ApiClient apiClient;

  setUp(() {
    mockSecureStorage = MockSecureStorageService();
    mockDio = MockDio();
    when(() => mockDio.interceptors).thenReturn(Interceptors());

    apiClient = ApiClient(
      secureStorage: mockSecureStorage,
      customDio: mockDio,
    );
  });

  group('ApiClient Tests', () {
    test('get exitoso retorna Response con datos', () async {
      final mockResponse = Response(
        requestOptions: RequestOptions(path: '/api/propiedades'),
        data: [{'id': 1, 'nombre': 'Depto 101'}],
        statusCode: 200,
      );

      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => mockResponse);

      final response = await apiClient.get<dynamic>('/api/propiedades');

      expect(response.statusCode, 200);
      expect(response.data, isA<List<dynamic>>());
    });

    test('get con error 404 lanza NotFoundException', () async {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/propiedades/99'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/api/propiedades/99'),
          statusCode: 404,
        ),
      );

      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenThrow(dioException);

      expect(
        () => apiClient.get<dynamic>('/api/propiedades/99'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('post exitoso envía payload y retorna Response', () async {
      final mockResponse = Response(
        requestOptions: RequestOptions(path: '/api/pagos'),
        data: {'id': 10, 'monto': 1200},
        statusCode: 201,
      );

      when(() => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => mockResponse);

      final response = await apiClient.post<dynamic>(
        '/api/pagos',
        data: {'monto': 1200},
      );

      expect(response.statusCode, 201);
    });
  });
}
