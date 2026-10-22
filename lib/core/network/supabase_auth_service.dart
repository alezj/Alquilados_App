import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import '../../features/sync/data/datasources/local_database_service.dart';

class SupabaseAuthService {
  SupabaseAuthService(this._storage, this._localDatabase)
    : _dio = Dio(
        BaseOptions(
          baseUrl: '${AppConfig.supabaseUrl.replaceAll(RegExp(r'/+$'), '')}/',
          headers: {
            'apikey': AppConfig.supabasePublishableKey,
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

  final SecureStorageService _storage;
  final LocalDatabaseService _localDatabase;
  final Dio _dio;

  Future<List<Map<String, dynamic>>> activeCompanies() async {
    final response = await _dio.get<List<dynamic>>(
      'rest/v1/companies?select=id,name&status=eq.active&order=name',
    );
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> signIn(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'auth/v1/token?grant_type=password',
        data: {'email': email.trim(), 'password': password},
      );
      final data = response.data ?? const <String, dynamic>{};
      final token = data['access_token']?.toString();
      final refresh = data['refresh_token']?.toString();
      final user = data['user'] as Map<String, dynamic>?;
      final userId = user?['id']?.toString();
      if (token == null || userId == null)
        throw Exception('Respuesta de autenticación incompleta.');
      await _storage.saveToken(token);
      if (refresh != null) await _storage.saveRefreshToken(refresh);
      final profile = await _dio.get<List<dynamic>>(
        'rest/v1/profiles?id=eq.$userId&select=approval_status,is_active',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final rows =
          profile.data?.whereType<Map<String, dynamic>>().toList() ??
          const <Map<String, dynamic>>[];
      final row = rows.isEmpty ? null : rows.first;
      if (row == null ||
          row['approval_status'] != 'approved' ||
          row['is_active'] != true) {
        await _storage.clearSession();
        throw Exception(_statusMessage(row?['approval_status']?.toString()));
      }
      final membershipsResponse = await _dio.get<List<dynamic>>(
        'rest/v1/company_memberships?select=company_id&user_id=eq.$userId&status=eq.approved&order=requested_at.asc&limit=1',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final memberships =
          membershipsResponse.data
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const <Map<String, dynamic>>[];
      if (memberships.isEmpty) {
        await _storage.clearSession();
        throw Exception(
          'Tu cuenta no tiene una empresa aprobada. Contacta al administrador.',
        );
      }
      final companyId = memberships.first['company_id'].toString();
      final companyResponse = await _dio.get<List<dynamic>>(
        'rest/v1/companies?select=slug&id=eq.$companyId&limit=1',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final companies =
          companyResponse.data?.whereType<Map<String, dynamic>>().toList() ??
          const <Map<String, dynamic>>[];
      if (companies.isEmpty) {
        await _storage.clearSession();
        throw Exception('No se pudo resolver la empresa de la cuenta.');
      }
      await _localDatabase.switchTenant(companies.first['slug'].toString());
      await _storage.saveUserData(userId);
    } on DioException catch (error) {
      await _storage.clearSession();
      final body = error.response?.data;
      final message = body is Map
          ? (body['msg'] ?? body['message'] ?? body['error_description'])
          : null;
      throw Exception(
        message?.toString() ??
            'No fue posible iniciar sesión. Verifica tus datos.',
      );
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String companyId,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        'auth/v1/signup',
        data: {
          'email': email.trim(),
          'password': password,
          'data': {
            'full_name': name.trim(),
            'company_id': companyId,
            'Origen': 'movil',
          },
        },
      );
      await _storage.clearSession();
    } on DioException catch (error) {
      final body = error.response?.data;
      final message = body is Map
          ? (body['msg'] ?? body['message'] ?? body['error_description'])
          : null;
      throw Exception(
        message?.toString() ?? 'No fue posible enviar la solicitud.',
      );
    }
  }

  Future<void> signOut() async {
    final token = await _storage.getToken();
    if (token != null) {
      try {
        await _dio.post<void>(
          'auth/v1/logout',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } catch (_) {
        // Clear the local session even if the remote session has already expired.
      }
    }
    await _storage.clearSession();
  }

  static String _statusMessage(String? status) => switch (status) {
    'pending' =>
      'Tu solicitud está pendiente de aprobación por el administrador.',
    'rejected' =>
      'Tu solicitud de acceso fue rechazada. Contacta al administrador.',
    'disabled' => 'Tu cuenta está deshabilitada. Contacta al administrador.',
    _ => 'Tu perfil no está autorizado para acceder al sistema.',
  };
}
