import 'package:shared_preferences/shared_preferences.dart';
import './secure_storage_service.dart';
import './auth.dart';

/// Service to manage user profile data consistently across the app
class UserProfileService {
  /// Load user profile data from SecureStorage (for Google sign-in)
  /// or SharedPreferences (for email/password sign-in)
  static Future<UserProfileData> loadUserProfile() async {
    // First try to get from SecureStorage (Firebase/Google Sign-In)
    final storedName = await SecureStorageService.getString('user_name');
    final storedEmail = await SecureStorageService.getString('user_email');
    final storedPhotoUrl = await SecureStorageService.getString('profile_image');

    // Also check SharedPreferences for backward compatibility
    final prefs = await SharedPreferences.getInstance();

    // Get current Firebase user data if available
    final currentUser = AuthService.currentUser;

    // Prioritize: Firebase user data > SecureStorage > SharedPreferences
    String name = currentUser?.displayName ??
                  storedName ??
                  prefs.getString('user_name') ??
                  'User';

    String email = currentUser?.email ??
                   storedEmail ??
                   prefs.getString('user_email') ??
                   'user@email.com';

    String? photoUrl = currentUser?.photoURL ??
                       storedPhotoUrl ??
                       prefs.getString('profile_image');

    String bio = prefs.getString('user_bio') ?? 'Music is life 🎵';
    bool isPremium = prefs.getBool('is_premium') ?? false;

    // Sync to SharedPreferences for quick access
    await _syncToSharedPreferences(name, email, photoUrl);

    return UserProfileData(
      name: name,
      email: email,
      photoUrl: photoUrl,
      bio: bio,
      isPremium: isPremium,
    );
  }

  /// Sync profile data to SharedPreferences for quick access
  static Future<void> _syncToSharedPreferences(
    String name,
    String email,
    String? photoUrl,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    if (photoUrl != null && photoUrl.isNotEmpty) {
      await prefs.setString('profile_image', photoUrl);
    }
  }

  /// Update user profile data in both SecureStorage and SharedPreferences
  static Future<void> updateUserProfile({
    String? name,
    String? email,
    String? photoUrl,
    String? bio,
    bool? isPremium,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (name != null) {
      await SecureStorageService.setString('user_name', name);
      await prefs.setString('user_name', name);
    }

    if (email != null) {
      await SecureStorageService.setString('user_email', email);
      await prefs.setString('user_email', email);
    }

    if (photoUrl != null) {
      await SecureStorageService.setString('profile_image', photoUrl);
      await prefs.setString('profile_image', photoUrl);
    }

    if (bio != null) {
      await prefs.setString('user_bio', bio);
    }

    if (isPremium != null) {
      await prefs.setBool('is_premium', isPremium);
    }
  }

  /// Get username from email
  static String getUsernameFromEmail(String email) {
    if (email.contains('@')) {
      return email.split('@')[0];
    }
    return email.toLowerCase().replaceAll(' ', '');
  }
}

/// Data class for user profile
class UserProfileData {
  final String name;
  final String email;
  final String? photoUrl;
  final String bio;
  final bool isPremium;

  const UserProfileData({
    required this.name,
    required this.email,
    this.photoUrl,
    required this.bio,
    required this.isPremium,
  });
}
