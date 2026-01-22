import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import './secure_storage_service.dart';

/// Biometric authentication service
/// Provides fingerprint, face recognition, and other biometric authentication
class BiometricAuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // Storage keys
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricEmailKey = 'biometric_email';
  static const String _biometricPasswordKey = 'biometric_password';

  /// Check if biometric authentication is available on device
  static Future<bool> isAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking biometric availability: $e');
      }
      return false;
    }
  }

  /// Get list of available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting available biometrics: $e');
      }
      return [];
    }
  }

  /// Get human-readable biometric type name
  static String getBiometricTypeName(List<BiometricType> types) {
    if (types.isEmpty) return 'Biometric';

    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else {
      return 'Biometric';
    }
  }

  /// Authenticate with biometrics
  static Future<bool> authenticate({
    String reason = 'Please authenticate to access your account',
  }) async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
      );
      return didAuthenticate;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Biometric authentication error: ${e.code} - ${e.message}');
      }

      // Handle specific error codes
      if (e.code == 'NotAvailable') {
        throw 'Biometric authentication is not available on this device';
      } else if (e.code == 'NotEnrolled') {
        throw 'No biometric credentials enrolled. Please set up biometrics in device settings';
      } else if (e.code == 'PasscodeNotSet') {
        throw 'Please set up device passcode first';
      } else if (e.code == 'PermanentlyLockedOut') {
        throw 'Biometric authentication is locked. Please use device passcode';
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Unexpected biometric error: $e');
      }
      return false;
    }
  }

  /// Enable biometric authentication and save credentials
  static Future<void> enableBiometric({
    required String email,
    required String password,
  }) async {
    try {
      await SecureStorageService.setBool(_biometricEnabledKey, true);
      await SecureStorageService.setString(_biometricEmailKey, email);
      await SecureStorageService.setString(_biometricPasswordKey, password);

      if (kDebugMode) {
        debugPrint('Biometric authentication enabled for: $email');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error enabling biometric: $e');
      }
      throw 'Failed to enable biometric authentication';
    }
  }

  /// Disable biometric authentication and clear credentials
  static Future<void> disableBiometric() async {
    try {
      await SecureStorageService.setBool(_biometricEnabledKey, false);
      await SecureStorageService.remove(_biometricEmailKey);
      await SecureStorageService.remove(_biometricPasswordKey);

      if (kDebugMode) {
        debugPrint('Biometric authentication disabled');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error disabling biometric: $e');
      }
    }
  }

  /// Check if biometric authentication is enabled
  static Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await SecureStorageService.getBool(_biometricEnabledKey);
      return enabled ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking biometric status: $e');
      }
      return false;
    }
  }

  /// Get stored credentials after successful biometric authentication
  static Future<Map<String, String>?> getStoredCredentials() async {
    try {
      final email = await SecureStorageService.getString(_biometricEmailKey);
      final password = await SecureStorageService.getString(_biometricPasswordKey);

      if (email != null && password != null) {
        return {
          'email': email,
          'password': password,
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error retrieving stored credentials: $e');
      }
      return null;
    }
  }

  /// Authenticate and get credentials in one call
  static Future<Map<String, String>?> authenticateAndGetCredentials({
    String reason = 'Please authenticate to sign in',
  }) async {
    try {
      // Check if biometric is enabled
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        if (kDebugMode) {
          debugPrint('Biometric authentication is not enabled');
        }
        return null;
      }

      // Attempt biometric authentication
      final authenticated = await authenticate(reason: reason);
      if (!authenticated) {
        return null;
      }

      // Return stored credentials
      return await getStoredCredentials();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in authenticateAndGetCredentials: $e');
      }
      rethrow;
    }
  }

  /// Check if device has biometric hardware and it's set up
  static Future<bool> canUseBiometric() async {
    try {
      final isAvailable = await BiometricAuthService.isAvailable();
      if (!isAvailable) return false;

      final biometrics = await getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking if can use biometric: $e');
      }
      return false;
    }
  }
}
