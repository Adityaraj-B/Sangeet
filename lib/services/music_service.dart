import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';
import 'remote_music_service.dart';

/// Singleton music service powered by JioSaavn.
class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  final RemoteMusicService _saavn =
  RemoteMusicService('https://vercelapi-gamma.vercel.app/api');

  // Expose the raw Saavn service for callers that need it
  RemoteMusicService get saavn => _saavn;

  // ─────────────────────────── SEARCH ───────────────────────────

  /// Searches JioSaavn for songs.
  Future<List<Song>> search(String query, {int limit = 20}) async {
    try {
      return await _saavn.searchSongs(query);
    } catch (e) {
      debugPrint('MusicService.search error: $e');
      return [];
    }
  }

  // ─────────────────────── STREAM URL ───────────────────────

  /// Resolves a playable [AudioSource] for a song.
  Future<AudioSource?> getAudioSource(Song song) async {
    if (song.streamUrl == null || song.streamUrl!.isEmpty) return null;

    // FIX: JioSaavn occasionally returns http:// URLs.
    // Windows just_audio backend rejects non-TLS — force https://.
    final url = song.streamUrl!.replaceFirst('http://', 'https://');

    return AudioSource.uri(Uri.parse(url));
  }

  /// Resolves a playable stream URL for a song.
  Future<String?> getStreamUrl(Song song) async {
    return song.streamUrl?.replaceFirst('http://', 'https://');
  }

  /// Resolves a playable stream source (URL + headers) for a song.
  Future<StreamSource?> getStreamSource(Song song) async {
    if (song.streamUrl == null || song.streamUrl!.isEmpty) return null;
    final url = song.streamUrl!.replaceFirst('http://', 'https://');
    return StreamSource(url: url, headers: const {});
  }

  // ─────────────────────── UP NEXT ───────────────────────

  /// Returns recommended songs based on the current song.
  Future<List<Song>> getUpNext(Song song) async {
    try {
      return await _saavn.getSongSuggestions(song.id);
    } catch (e) {
      debugPrint('MusicService.getUpNext error: $e');
      return [];
    }
  }
}

/// A resolved audio stream: URL + any required HTTP headers.
class StreamSource {
  final String url;
  final Map<String, String> headers;

  const StreamSource({required this.url, required this.headers});
}