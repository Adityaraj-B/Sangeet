import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './secure_storage_service.dart';

/// One-time migration utility to move data from SharedPreferences to SecureStorage
class StorageMigration {
  static const String _migrationCompleteKey = 'migration_to_secure_storage_complete';

  /// Check if migration has already been completed
  static Future<bool> isMigrationComplete() async {
    final migrated = await SecureStorageService.getBool(_migrationCompleteKey);
    return migrated ?? false;
  }

  /// Migrate all data from SharedPreferences to SecureStorage
  static Future<void> migrateIfNeeded() async {
    try {
      // Check if migration already done
      if (await isMigrationComplete()) {
        if (kDebugMode) {
          debugPrint('Migration already complete, skipping...');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('Starting migration from SharedPreferences to SecureStorage...');
      }

      final prefs = await SharedPreferences.getInstance();

      // Migrate auth data
      await _migrateAuthData(prefs);

      // Migrate recently played
      await _migrateRecentlyPlayed(prefs);

      // Migrate playlists
      await _migratePlaylists(prefs);

      // Mark migration as complete
      await SecureStorageService.setBool(_migrationCompleteKey, true);

      if (kDebugMode) {
        debugPrint('Migration completed successfully!');
      }

      // Optional: Clear old SharedPreferences data after successful migration
      // Uncomment the next line if you want to remove the old data
      // await _clearOldData(prefs);

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during migration: $e');
      }
      // Don't mark as complete if there was an error
    }
  }

  /// Migrate authentication data
  static Future<void> _migrateAuthData(SharedPreferences prefs) async {
    try {
      // Migrate login state
      final isLoggedIn = prefs.getBool('is_logged_in');
      if (isLoggedIn != null) {
        await SecureStorageService.setBool('is_logged_in', isLoggedIn);
        if (kDebugMode) {
          debugPrint('✓ Migrated login state');
        }
      }

      // Migrate user profile data
      final userName = prefs.getString('user_name');
      if (userName != null) {
        await SecureStorageService.setString('user_name', userName);
        if (kDebugMode) {
          debugPrint('✓ Migrated user name');
        }
      }

      final userEmail = prefs.getString('user_email');
      if (userEmail != null) {
        await SecureStorageService.setString('user_email', userEmail);
        if (kDebugMode) {
          debugPrint('✓ Migrated user email');
        }
      }

      final profileImage = prefs.getString('profile_image');
      if (profileImage != null) {
        await SecureStorageService.setString('profile_image', profileImage);
        if (kDebugMode) {
          debugPrint('✓ Migrated profile image');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error migrating auth data: $e');
      }
    }
  }

  /// Migrate recently played songs
  static Future<void> _migrateRecentlyPlayed(SharedPreferences prefs) async {
    try {
      final recentlyPlayed = prefs.getString('recently_played_songs');
      if (recentlyPlayed != null) {
        await SecureStorageService.setString('recently_played_songs', recentlyPlayed);
        if (kDebugMode) {
          debugPrint('✓ Migrated recently played songs');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error migrating recently played: $e');
      }
    }
  }

  /// Migrate playlists
  static Future<void> _migratePlaylists(SharedPreferences prefs) async {
    try {
      // Migrate user playlists
      final playlists = prefs.getStringList('user_playlists');
      if (playlists != null) {
        await SecureStorageService.setStringList('user_playlists', playlists);
        if (kDebugMode) {
          debugPrint('✓ Migrated ${playlists.length} playlists');
        }
      }

      // Migrate cached songs
      final cachedSongs = prefs.getString('cached_songs');
      if (cachedSongs != null) {
        await SecureStorageService.setString('cached_songs', cachedSongs);
        if (kDebugMode) {
          debugPrint('✓ Migrated cached songs');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error migrating playlists: $e');
      }
    }
  }

  /// Clear old SharedPreferences data after migration
  /// CAUTION: Only call this after confirming migration was successful
  static Future<void> _clearOldData(SharedPreferences prefs) async {
    try {
      await prefs.remove('is_logged_in');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('profile_image');
      await prefs.remove('recently_played_songs');
      await prefs.remove('user_playlists');
      await prefs.remove('cached_songs');

      if (kDebugMode) {
        debugPrint('✓ Cleared old SharedPreferences data');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error clearing old data: $e');
      }
    }
  }

  /// Force re-migration (useful for testing)
  static Future<void> resetMigration() async {
    await SecureStorageService.remove(_migrationCompleteKey);
    if (kDebugMode) {
      debugPrint('Migration flag reset');
    }
  }
}

