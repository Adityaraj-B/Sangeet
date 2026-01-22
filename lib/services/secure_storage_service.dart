import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

/// Secure storage service for sensitive data
/// Uses platform-specific secure storage (Keychain on iOS, KeyStore on Android)
class SecureStorageService {
  static final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Keys for secure storage
  static const String _authTokenKey = 'auth_token';
  static const String _userCredentialsKey = 'user_credentials';
  static const String _encryptionKeyPrefix = 'encrypted_';

  /// Save auth token securely
  static Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: _authTokenKey, value: token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving auth token: $e');
      }
    }
  }

  /// Get auth token
  static Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: _authTokenKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error reading auth token: $e');
      }
      return null;
    }
  }

  /// Delete auth token
  static Future<void> deleteAuthToken() async {
    try {
      await _storage.delete(key: _authTokenKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting auth token: $e');
      }
    }
  }

  /// Save encrypted data
  static Future<void> saveEncryptedData(String key, Map<String, dynamic> data) async {
    try {
      final jsonStr = json.encode(data);
      await _storage.write(key: _encryptionKeyPrefix + key, value: jsonStr);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving encrypted data: $e');
      }
    }
  }

  /// Get encrypted data
  static Future<Map<String, dynamic>?> getEncryptedData(String key) async {
    try {
      final jsonStr = await _storage.read(key: _encryptionKeyPrefix + key);
      if (jsonStr == null) return null;
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error reading encrypted data: $e');
      }
      return null;
    }
  }

  /// Delete encrypted data
  static Future<void> deleteEncryptedData(String key) async {
    try {
      await _storage.delete(key: _encryptionKeyPrefix + key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting encrypted data: $e');
      }
    }
  }

  // ==================== SharedPreferences Replacement Methods ====================

  /// Save a string value
  static Future<void> setString(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving string: $e');
      }
    }
  }

  /// Get a string value
  static Future<String?> getString(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error reading string: $e');
      }
      return null;
    }
  }

  /// Save a boolean value
  static Future<void> setBool(String key, bool value) async {
    try {
      await _storage.write(key: key, value: value.toString());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving bool: $e');
      }
    }
  }

  /// Get a boolean value
  static Future<bool?> getBool(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == null) return null;
      return value.toLowerCase() == 'true';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error reading bool: $e');
      }
      return null;
    }
  }

  /// Save a string list
  static Future<void> setStringList(String key, List<String> value) async {
    try {
      final jsonStr = json.encode(value);
      await _storage.write(key: key, value: jsonStr);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving string list: $e');
      }
    }
  }

  /// Get a string list
  static Future<List<String>?> getStringList(String key) async {
    try {
      final jsonStr = await _storage.read(key: key);
      if (jsonStr == null) return null;
      final decoded = json.decode(jsonStr) as List;
      return decoded.cast<String>();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error reading string list: $e');
      }
      return null;
    }
  }

  /// Remove a specific key
  static Future<void> remove(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error removing key: $e');
      }
    }
  }

  /// Clear all secure storage
  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error clearing secure storage: $e');
      }
    }
  }
}
