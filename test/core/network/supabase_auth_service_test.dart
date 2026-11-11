import 'dart:convert';
import 'dart:typed_data';

import 'package:alquilados_app/core/config/app_config.dart';
import 'package:alquilados_app/core/network/supabase_auth_service.dart';
import 'package:alquilados_app/core/storage/secure_storage_service.dart';
import 'package:alquilados_app/features/sync/data/datasources/local_database_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStorage extends Mock implements SecureStorageService {}

class MockDatabase extends Mock implements LocalDatabaseService {}

class AuthAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String? resolvedEmail = 'test@example.com';
  String username = 'Johancel';
  bool approved = true;
  bool failMembership = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final Object? data;
    var status = 200;
    if (options.path.contains('rpc/')) {
      data = resolvedEmail;
    } else if (options.path.contains('auth/v1/token')) {
      data = {
        'access_token': 'access',
        'refresh_token': 'refresh',
        'user': {'id': 'user-id'},
      };
    } else if (options.path.contains('profiles')) {
      data = [
        {
          'approval_status': approved ? 'approved' : 'pending',
          'is_active': true,
          'usuarioSesion': username,
        },
      ];
    } else if (options.path.contains('company_memberships')) {
      status = failMembership ? 500 : 200;
      data = failMembership
          ? {'message': 'Error de red'}
          : [
              {'company_id': 'company-id'},
            ];
    } else {
      data = [
        {'slug': 'admin'},
      ];
    }
    return ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MockStorage storage;
  late MockDatabase database;
  late AuthAdapter adapter;
  late SupabaseAuthService auth;

  setUp(() {
    AppConfig.backend = BackendEnvironment.production;
    storage = MockStorage();
    database = MockDatabase();
    adapter = AuthAdapter();
    when(() => storage.clearSession()).thenAnswer((_) async {});
    when(() => storage.saveToken(any())).thenAnswer((_) async {});
    when(() => storage.saveRefreshToken(any())).thenAnswer((_) async {});
    when(() => storage.saveUserData(any())).thenAnswer((_) async {});
    when(() => storage.saveSessionContext(any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => database.switchTenant(any())).thenAnswer((_) async {});
    auth = SupabaseAuthService(
      storage,
      database,
      dio: Dio()..httpClientAdapter = adapter,
    );
  });

  tearDown(() => AppConfig.backend = BackendEnvironment.production);

  test(
    'Johancel usa pruebas por defecto y resuelve usuario antes de autenticar',
    () async {
      await auth.signIn(' Johancel ', 'password');
      expect(
        adapter.requests.first.uri.host,
        Uri.parse(AppConfig.testUrl).host,
      );
      expect(adapter.requests.first.data, {'p_username': 'Johancel'});
      expect(adapter.requests[1].data, {
        'email': 'test@example.com',
        'password': 'password',
      });
      expect(
        adapter.requests.every((r) => r.headers['apikey'] == AppConfig.testKey),
        isTrue,
      );
      verify(() => database.switchTenant('test_admin')).called(1);
      verify(() => storage.saveSessionContext('test', 'test_admin', 'Johancel'))
          .called(1);
    },
  );

  test(
    'Johancel puede seleccionar producción y conserva la base existente',
    () async {
      await auth.signIn(
        'johancel',
        'password',
        environment: BackendEnvironment.production,
      );
      expect(
        adapter.requests.first.uri.host,
        Uri.parse(AppConfig.productionUrl).host,
      );
      verify(() => database.switchTenant('admin')).called(1);
    },
  );

  test('otro usuario siempre usa producción aunque solicite pruebas', () async {
    adapter.username = 'otro';
    await auth.signIn('otro', 'password', environment: BackendEnvironment.test);
    expect(
      adapter.requests.first.uri.host,
      Uri.parse(AppConfig.productionUrl).host,
    );
    verify(() => database.switchTenant('admin')).called(1);
  });

  test(
    'usuario inexistente no intenta autenticar ni abre datos locales',
    () async {
      adapter.resolvedEmail = null;
      await expectLater(auth.signIn('nadie', 'password'), throwsException);
      expect(adapter.requests, hasLength(1));
      verifyNever(() => database.switchTenant(any()));
    },
  );

  test('perfil pendiente no puede abrir la base local', () async {
    adapter.approved = false;
    await expectLater(auth.signIn('Johancel', 'password'), throwsException);
    verifyNever(() => database.switchTenant(any()));
    verifyNever(() => storage.saveSessionContext(any(), any(), any()));
  });

  test('el correo no sustituye a usuarioSesion', () async {
    await expectLater(
      auth.signIn('test@example.com', 'password'),
      throwsException,
    );
    verifyNever(() => database.switchTenant(any()));
  });

  test('fallo después de autenticar elimina la sesión parcial', () async {
    adapter.failMembership = true;
    await expectLater(auth.signIn('Johancel', 'password'), throwsException);
    verify(() => storage.clearSession()).called(2);
    verifyNever(() => database.switchTenant(any()));
  });
}
