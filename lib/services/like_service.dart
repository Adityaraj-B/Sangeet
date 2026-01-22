import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

class LikeService extends ChangeNotifier {
  static const _key = 'liked_songs_v1';

  final Map<String, Song> _liked = {};

  List<Song> get likedSongs => _liked.values.toList();

  bool isLiked(Song song) => _liked.containsKey(song.id);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) {
      debugPrint('LikeService: no saved likes');
      return;
    }

    final decoded = json.decode(raw) as Map<String, dynamic>;

    _liked.clear();
    decoded.forEach((id, value) {
      try {
        _liked[id] = Song.fromJson(
          Map<String, dynamic>.from(value),
        );
      } catch (e) {
        debugPrint('LikeService restore failed for $id: $e');
      }
    });

    debugPrint('LikeService loaded ${_liked.length} liked songs');
    notifyListeners();
  }

  Future<void> toggleLike(Song song) async {
    if (_liked.containsKey(song.id)) {
      _liked.remove(song.id);
    } else {
      _liked[song.id] = song;
    }

    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = json.encode(
      _liked.map((k, v) => MapEntry(k, v.toJson())),
    );

    await prefs.setString(_key, encoded);
  }
}
