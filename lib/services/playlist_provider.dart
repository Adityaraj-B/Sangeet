import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import 'playlist_service.dart';

class PlaylistProvider extends ChangeNotifier {
  final PlaylistService _service = PlaylistService.instance;

  List<Playlist> _playlists = [];
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  // Cache to store Song objects for each playlist
  final Map<String, List<Song>> _playlistSongsCache = {};

  List<Playlist> get playlists => _playlists;
  bool get isLoading => _isLoading;

  /// Initialize - subscribe to Firestore playlists stream.
  /// Call this after user is logged in.
  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Cancel any existing subscription
      await _subscription?.cancel();

      // Subscribe to real-time updates from Firestore
      _subscription = _service.playlistsStream().listen(
        (snapshot) {
          _playlists = snapshot.docs.map((doc) {
            final data = doc.data();
            final songIds = List<String>.from(data['songIds'] ?? []);

            // Load songs from Firestore into cache
            final songsData = data['songs'] as List<dynamic>? ?? [];
            final songs = songsData.map((songJson) {
              try {
                return Song.fromJson(Map<String, dynamic>.from(songJson));
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('Error parsing song: $e');
                }
                return null;
              }
            }).whereType<Song>().toList();

            // Update the cache with loaded songs
            if (songs.isNotEmpty) {
              _playlistSongsCache[doc.id] = songs;
            } else {
              _playlistSongsCache.remove(doc.id);
            }

            // Convert Firestore timestamp to DateTime
            DateTime createdAt;
            final timestamp = data['createdAt'];
            if (timestamp is Timestamp) {
              createdAt = timestamp.toDate();
            } else {
              createdAt = DateTime.now();
            }

            return Playlist(
              id: doc.id,
              title: data['name'] as String? ?? 'Untitled',
              description: '',
              coverUrl: '',
              songs: songs, // Include the loaded songs
              songIds: songIds, // Store the song IDs from Firestore
              createdAt: createdAt,
              updatedAt: createdAt,
            );
          }).toList();

          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          if (kDebugMode) {
            debugPrint('Error streaming playlists: $e');
          }
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing playlist provider: $e');
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clean up subscription when provider is disposed or user logs out.
  void clearSubscription() {
    _subscription?.cancel();
    _subscription = null;
    _playlists = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> renamePlaylist(String playlistId, String newTitle) async {
    try {
      await _service.renamePlaylist(playlistId, newTitle);
      // No need to update local state - Firestore stream will notify
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error renaming playlist: $e');
      }
    }
  }

  Future<Playlist?> createPlaylist(String title, {String? description}) async {
    try {
      final playlistId = await _service.createPlaylist(title);
      // Return a temporary playlist object
      // The actual update will come through the stream
      return Playlist(
        id: playlistId,
        title: title,
        description: description ?? '',
        songs: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        coverUrl: '',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error creating playlist: $e');
      }
      return null;
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    try {
      await _service.deletePlaylist(playlistId);
      // Clear the cache for this playlist
      _playlistSongsCache.remove(playlistId);
      // No need to update local state - Firestore stream will notify
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting playlist: $e');
      }
    }
  }

  Future<void> updatePlaylist(Playlist updatedPlaylist) async {
    try {
      // Update the title
      await _service.renamePlaylist(updatedPlaylist.id, updatedPlaylist.title);

      // Update the songs list
      final songIds = updatedPlaylist.songs.map((s) => s.id).toList();
      final songsData = updatedPlaylist.songs.map((s) => s.toJson()).toList();
      await _service.updatePlaylistSongs(updatedPlaylist.id, songIds, songsData);

      // Update the cache
      _playlistSongsCache[updatedPlaylist.id] = List.from(updatedPlaylist.songs);

      // No need to update local state - Firestore stream will notify
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating playlist: $e');
      }
    }
  }

  Future<bool> addSongToPlaylist(String playlistId, Song song) async {
    try {
      await _service.addSongToPlaylist(playlistId, song.id, song.toJson());

      // Cache the song in the playlist songs map
      if (_playlistSongsCache.containsKey(playlistId)) {
        // Avoid duplicates
        if (!_playlistSongsCache[playlistId]!.any((s) => s.id == song.id)) {
          _playlistSongsCache[playlistId]!.add(song);
        }
      } else {
        _playlistSongsCache[playlistId] = [song];
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding song to playlist: $e');
      }
      return false;
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    try {
      // Get the song data before removing
      Song? songToRemove;
      if (_playlistSongsCache.containsKey(playlistId)) {
        songToRemove = _playlistSongsCache[playlistId]!.firstWhere(
          (s) => s.id == songId,
          orElse: () => _playlistSongsCache[playlistId]!.first,
        );
      }

      await _service.removeSongFromPlaylist(
        playlistId,
        songId,
        songToRemove?.toJson() ?? {'id': songId},
      );

      // Remove from cache as well
      if (_playlistSongsCache.containsKey(playlistId)) {
        _playlistSongsCache[playlistId]!.removeWhere((song) => song.id == songId);
      }

      // No need to update local state - Firestore stream will notify
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error removing song from playlist: $e');
      }
    }
  }

  Future<void> reorderSongs(String playlistId, int oldIndex, int newIndex) async {
    // Note: Firestore arrays don't support atomic reordering.
    // For now, this is a no-op. Full implementation would require
    // fetching the array, reordering locally, and updating the whole array.
    if (kDebugMode) {
      debugPrint('Reorder songs not yet implemented for Firestore');
    }
  }

  Playlist? getPlaylistById(String playlistId) {
    try {
      return _playlists.firstWhere((p) => p.id == playlistId);
    } catch (e) {
      return null;
    }
  }

  bool isSongInPlaylist(String playlistId, String songId) {
    final playlist = getPlaylistById(playlistId);
    return playlist?.songIds.contains(songId) ?? false;
  }

  List<Playlist> getPlaylistsWithSong(String songId) {
    return _playlists.where((playlist) => playlist.songIds.contains(songId)).toList();
  }

  /// Get the cached songs for a playlist
  List<Song> getPlaylistSongs(String playlistId) {
    return _playlistSongsCache[playlistId] ?? [];
  }
}