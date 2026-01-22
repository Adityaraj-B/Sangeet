// lib/services/playlist_storage_service.dart

import 'dart:convert';
import '../services/secure_storage_service.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class PlaylistStorageService {
  static const String _playlistsKey = 'user_playlists';
  static const String _songsKey = 'cached_songs';

  // ==================== PLAYLISTS ====================

  /// Save all playlists to local storage
  Future<void> savePlaylists(List<Playlist> playlists) async {
    final jsonList = playlists.map((p) => jsonEncode(p.toJson())).toList();
    await SecureStorageService.setStringList(_playlistsKey, jsonList);
  }

  /// Load all playlists from local storage
  Future<List<Playlist>> loadPlaylists() async {
    final jsonList = await SecureStorageService.getStringList(_playlistsKey);

    if (jsonList == null) return [];

    return jsonList
        .map((jsonStr) => Playlist.fromJson(jsonDecode(jsonStr)))
        .toList();
  }

  /// Create a new playlist
  Future<Playlist> createPlaylist(String title, {String? description}) async {
    final playlists = await loadPlaylists();

    final newPlaylist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description ?? '',
      songs: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      coverUrl: '',
    );

    playlists.add(newPlaylist);
    await savePlaylists(playlists);

    return newPlaylist;
  }

  /// Delete a playlist
  Future<void> deletePlaylist(String playlistId) async {
    final playlists = await loadPlaylists();
    playlists.removeWhere((p) => p.id == playlistId);
    await savePlaylists(playlists);
  }

  /// Update playlist details (name, description, cover)
  Future<void> updatePlaylist(Playlist updatedPlaylist) async {
    final playlists = await loadPlaylists();
    final index = playlists.indexWhere((p) => p.id == updatedPlaylist.id);

    if (index != -1) {
      playlists[index] = updatedPlaylist.copyWith(
        updatedAt: DateTime.now(),
      );
      await savePlaylists(playlists);
    }
  }

  /// Add a song to a playlist
  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final playlists = await loadPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);

    if (index != -1) {
      final playlist = playlists[index];

      // Check if song already exists
      if (!playlist.songs.any((s) => s.id == song.id)) {
        final updatedSongs = List<Song>.from(playlist.songs)..add(song);

        playlists[index] = playlist.copyWith(
          songs: updatedSongs,
          updatedAt: DateTime.now(),
        );

        await savePlaylists(playlists);

        // Also cache the song
        await cacheSong(song);
      }
    }
  }

  /// Remove a song from a playlist
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlists = await loadPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);

    if (index != -1) {
      final playlist = playlists[index];
      final updatedSongs = playlist.songs.where((s) => s.id != songId).toList();

      playlists[index] = playlist.copyWith(
        songs: updatedSongs,
        updatedAt: DateTime.now(),
      );

      await savePlaylists(playlists);
    }
  }

  /// Reorder songs in a playlist
  Future<void> reorderSongs(String playlistId, int oldIndex, int newIndex) async {
    final playlists = await loadPlaylists();
    final index = playlists.indexWhere((p) => p.id == playlistId);

    if (index != -1) {
      final playlist = playlists[index];
      final songs = List<Song>.from(playlist.songs);

      final song = songs.removeAt(oldIndex);
      songs.insert(newIndex, song);

      playlists[index] = playlist.copyWith(
        songs: songs,
        updatedAt: DateTime.now(),
      );

      await savePlaylists(playlists);
    }
  }

  // ==================== SONG CACHE ====================

  /// Cache a song for offline access
  Future<void> cacheSong(Song song) async {
    final songsJson = await SecureStorageService.getString(_songsKey);

    Map<String, dynamic> songsMap = {};
    if (songsJson != null) {
      songsMap = Map<String, dynamic>.from(jsonDecode(songsJson));
    }

    songsMap[song.id] = {
      'id': song.id,
      'title': song.title,
      'artist': song.artist,
      'coverUrl': song.coverUrl,
      'duration': song.duration.inSeconds,
      'streamUrl': song.streamUrl,
    };

    await SecureStorageService.setString(_songsKey, jsonEncode(songsMap));
  }

  /// Get cached song by ID
  Future<Song?> getCachedSong(String songId) async {
    final songsJson = await SecureStorageService.getString(_songsKey);

    if (songsJson == null) return null;

    final songsMap = Map<String, dynamic>.from(jsonDecode(songsJson));
    final songData = songsMap[songId];

    if (songData == null) return null;

    return Song(
      id: songData['id'],
      title: songData['title'],
      artist: songData['artist'],
      coverUrl: songData['coverUrl'],
      duration: Duration(seconds: songData['duration']),
      streamUrl: songData['streamUrl'],
    );
  }

  // ==================== UTILITIES ====================

  /// Clear all playlists
  Future<void> clearAllPlaylists() async {
    await SecureStorageService.remove(_playlistsKey);
  }

  /// Clear song cache
  Future<void> clearSongCache() async {
    await SecureStorageService.remove(_songsKey);
  }

  /// Get playlist by ID
  Future<Playlist?> getPlaylistById(String playlistId) async {
    final playlists = await loadPlaylists();
    try {
      return playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      return null;
    }
  }
}