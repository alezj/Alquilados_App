import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage_service.dart';
import 'api_client.dart';
import 'supabase_auth_service.dart';
import '../../features/sync/data/datasources/local_database_service.dart';

/// Provider para el servicio de almacenamiento seguro (Keychain / EncryptedSharedPreferences).
///
/// Comparación con Angular:
/// Equivale a `@Injectable({ providedIn: 'root' }) class SecureStorageService`.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provider para el cliente HTTP centralizado (Dio).
///
/// Comparación con Angular:
/// Equivale al `HttpClient` inyectado en los servicios de Angular.
final apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return ApiClient(secureStorage: secureStorage);
});

final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService(
    ref.watch(secureStorageProvider),
    LocalDatabaseService(),
  );
});
