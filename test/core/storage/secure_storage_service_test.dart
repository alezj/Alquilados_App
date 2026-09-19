import 'package:alquilados_app/core/storage/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late SecureStorageService service;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    service = SecureStorageService(storage: mockStorage);
  });

  group('SecureStorageService Tests', () {
    const testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test';

    test('saveToken guarda el token en el almacenamiento seguro', () async {
      when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});

      await service.saveToken(testToken);

      verify(() => mockStorage.write(key: 'auth_token_jwt', value: testToken)).called(1);
    });

    test('getToken lee el token del almacenamiento seguro', () async {
      when(() => mockStorage.read(key: 'auth_token_jwt'))
          .thenAnswer((_) async => testToken);

      final result = await service.getToken();

      expect(result, testToken);
      verify(() => mockStorage.read(key: 'auth_token_jwt')).called(1);
    });

    test('hasToken retorna true si existe token guardado', () async {
      when(() => mockStorage.read(key: 'auth_token_jwt'))
          .thenAnswer((_) async => testToken);

      final hasToken = await service.hasToken();

      expect(hasToken, isTrue);
    });

    test('hasToken retorna false si no existe token guardado', () async {
      when(() => mockStorage.read(key: 'auth_token_jwt'))
          .thenAnswer((_) async => null);

      final hasToken = await service.hasToken();

      expect(hasToken, isFalse);
    });

    test('clearSession elimina el token y datos de sesión', () async {
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await service.clearSession();

      verify(() => mockStorage.delete(key: 'auth_token_jwt')).called(1);
      verify(() => mockStorage.delete(key: 'auth_refresh_token_jwt')).called(1);
      verify(() => mockStorage.delete(key: 'auth_user_data_json')).called(1);
    });
  });
}
