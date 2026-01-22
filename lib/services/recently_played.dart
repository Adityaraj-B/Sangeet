import 'dart:convert';
import 'package:flutter/foundation.dart'; // Required for ValueNotifier
import './secure_storage_service.dart';
import '../models/song.dart';

class RecentlyPlayedService {
  // 1. Singleton Pattern
  static final RecentlyPlayedService _instance = RecentlyPlayedService._internal();
  factory RecentlyPlayedService() => _instance;
  RecentlyPlayedService._internal();

  static const String _recentKey = 'recently_played_songs';
  static const int _maxRecentSongs = 50;

  // 2. The Notifier (Listens for changes)
  // Widgets can listen to this to rebuild automatically.
  static final ValueNotifier<List<Song>> recentSongsNotifier = ValueNotifier([]);

  /// Helper to update the notifier
  Future<void> _notifyListeners() async {
    final songs = await getRecentlyPlayed();
    recentSongsNotifier.value = songs;
  }

  /// Add song to recently played
  Future<void> addSong(Song song) async {
    try {
      final recentJson = await SecureStorageService.getString(_recentKey);

      List<Map<String, dynamic>> recentList = [];

      if (recentJson != null) {
        final decoded = jsonDecode(recentJson) as List;
        recentList = decoded.cast<Map<String, dynamic>>();
      }

      // Remove if already exists (to move to top)
      recentList.removeWhere((item) => item['id'] == song.id);

      // Add to beginning with timestamp
      recentList.insert(0, {
        ...song.toJson(),
        'playedAt': DateTime.now().toIso8601String(),
      });

      // Keep only last N songs
      if (recentList.length > _maxRecentSongs) {
        recentList = recentList.sublist(0, _maxRecentSongs);
      }

      // Save back
      await SecureStorageService.setString(_recentKey, jsonEncode(recentList));

      // 3. Notify UI to update
      await _notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding to recently played: $e');
      }
    }
  }

  /// Get recently played songs
  Future<List<Song>> getRecentlyPlayed({int limit = 20}) async {
    try {
      final recentJson = await SecureStorageService.getString(_recentKey);

      if (recentJson == null) return [];

      final decoded = jsonDecode(recentJson) as List;
      final recentList = decoded.cast<Map<String, dynamic>>();

      return recentList
          .take(limit)
          .map((json) => Song.fromJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting recently played: $e');
      }
      return [];
    }
  }

  /// Get recently played with timestamps
  Future<List<Map<String, dynamic>>> getRecentWithTimestamps({int limit = 20}) async {
    try {
      final recentJson = await SecureStorageService.getString(_recentKey);

      if (recentJson == null) return [];

      final decoded = jsonDecode(recentJson) as List;
      final recentList = decoded.cast<Map<String, dynamic>>();

      return recentList.take(limit).map((json) {
        return {
          'song': Song.fromJson(json),
          'playedAt': DateTime.parse(json['playedAt']),
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting recent with timestamps: $e');
      }
      return [];
    }
  }

  /// Clear all recently played
  Future<void> clearAll() async {
    await SecureStorageService.remove(_recentKey);

    // 3. Notify UI to update
    await _notifyListeners();
  }

  /// Remove specific song from recently played
  Future<void> removeSong(String songId) async {
    try {
      final recentJson = await SecureStorageService.getString(_recentKey);

      if (recentJson == null) return;

      final decoded = jsonDecode(recentJson) as List;
      var recentList = decoded.cast<Map<String, dynamic>>();

      recentList.removeWhere((item) => item['id'] == songId);

      await SecureStorageService.setString(_recentKey, jsonEncode(recentList));

      // 3. Notify UI to update
      await _notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error removing from recently played: $e');
      }
    }
  }

  /// Get recently played grouped by date
  Future<Map<String, List<Song>>> getRecentGroupedByDate({int days = 7}) async {
    try {
      final recentWithTime = await getRecentWithTimestamps(limit: 100);
      final Map<String, List<Song>> grouped = {};
      final now = DateTime.now();

      for (var item in recentWithTime) {
        final song = item['song'] as Song;
        final playedAt = item['playedAt'] as DateTime;

        // Calculate difference
        final difference = now.difference(playedAt);

        String key;
        if (difference.inHours < 1) {
          key = 'Just Now';
        } else if (difference.inHours < 24) {
          key = 'Today';
        } else if (difference.inDays == 1) {
          key = 'Yesterday';
        } else if (difference.inDays < 7) {
          key = 'This Week';
        } else if (difference.inDays < 30) {
          key = 'This Month';
        } else {
          key = 'Older';
        }

        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(song);
      }

      return grouped;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error grouping recently played: $e');
      }
      return {};
    }
  }
}