import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/app_exception.dart';
import '../utils/app_logger.dart';

/// Servicio de almacenamiento seguro del sistema operativo.
///
/// Implementación nativa:
/// - iOS: Apple Keychain Services
/// - Android: almacenamiento cifrado respaldado por Android Keystore (AES-GCM)
///
/// Comparación con Angular:
/// En la web se suele usar `localStorage` o cookies HTTP-Only.
/// En móvil, el almacenamiento sensible (JWT, Refresh Tokens)
/// NUNCA debe ir en texto plano; debe ir en el llavero seguro del OS.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  // Claves de almacenamiento
  static const String _keyToken = 'auth_token_jwt';
  static const String _keyRefreshToken = 'auth_refresh_token_jwt';
  static const String _keyUserData = 'auth_user_data_json';

  /// Guarda el Access Token JWT
  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _keyToken, value: token);
    } catch (e, s) {
      AppLogger.e('Error guardando token en SecureStorage', e, s);
      throw const StorageException(
        message: 'No se pudo guardar el token de autenticación',
      );
    }
  }

  /// Obtiene el Access Token JWT almacenado
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _keyToken);
    } catch (e, s) {
      AppLogger.e('Error leyendo token de SecureStorage', e, s);
      return null;
    }
  }

  /// Guarda el Refresh Token
  Future<void> saveRefreshToken(String refreshToken) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    } catch (e, s) {
      AppLogger.e('Error guardando refresh token en SecureStorage', e, s);
      throw const StorageException(
        message: 'No se pudo guardar el refresh token',
      );
    }
  }

  /// Obtiene el Refresh Token
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e, s) {
      AppLogger.e('Error leyendo refresh token de SecureStorage', e, s);
      return null;
    }
  }

  /// Guarda información serializada del usuario (JSON)
  Future<void> saveUserData(String jsonString) async {
    try {
      await _storage.write(key: _keyUserData, value: jsonString);
    } catch (e, s) {
      AppLogger.e('Error guardando datos de usuario', e, s);
    }
  }

  /// Obtiene información serializada del usuario (JSON)
  Future<String?> getUserData() async {
    try {
      return await _storage.read(key: _keyUserData);
    } catch (e, s) {
      AppLogger.e('Error leyendo datos de usuario', e, s);
      return null;
    }
  }

  /// Elimina los tokens y cierra la sesión en el almacenamiento local
  Future<void> clearSession() async {
    try {
      await _storage.delete(key: _keyToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyUserData);
    } catch (e, s) {
      AppLogger.e('Error limpiando sesión en SecureStorage', e, s);
    }
  }

  /// Comprueba si existe un token almacenado
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
