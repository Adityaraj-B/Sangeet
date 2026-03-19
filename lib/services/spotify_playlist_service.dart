import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/playlist_track_model.dart';

// ── Typed exceptions ─────────────────────────────────────────────

class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);
  @override
  String toString() => message;
}

class ParseException implements Exception {
  final String message;
  const ParseException(this.message);
  @override
  String toString() => message;
}

// ── Service ──────────────────────────────────────────────────────

class SpotifyPlaylistService {
  static final _playlistIdRegex =
      RegExp(r'open\.spotify\.com/playlist/([a-zA-Z0-9]+)');

  /// Import tracks from a public Spotify playlist URL.
  ///
  /// No API key, no OAuth — scrapes the public embed/HTML page and
  /// extracts the JSON blob that Spotify injects into the DOM.
  Future<List<PlaylistTrack>> importSpotifyPlaylist(String playlistUrl) async {
    // ── Step 1: validate URL ──
    final match = _playlistIdRegex.firstMatch(playlistUrl.trim());
    if (match == null) {
      throw const FormatException(
        'Invalid Spotify playlist URL. '
        'It should look like: https://open.spotify.com/playlist/...',
      );
    }
    final playlistId = match.group(1)!;

    // ── Step 2: fetch HTML (use the embed endpoint — lighter, more stable) ──
    final embedUrl = 'https://open.spotify.com/embed/playlist/$playlistId';
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse(embedUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      );
    } catch (e) {
      throw NetworkException('Network error: $e');
    }

    if (response.statusCode != 200) {
      throw NetworkException(
        'Failed to load playlist (HTTP ${response.statusCode}). '
        'Make sure the playlist is public.',
      );
    }

    final html = response.body;

    // ── Step 3: extract JSON from HTML ──
    // Spotify embed pages include a <script id="__NEXT_DATA__"> tag with all
    // the track data as JSON, or a resource script. Try multiple patterns.
    Map<String, dynamic>? jsonData;

    final patterns = [
      // Next.js data blob (most common in 2025-2026)
      RegExp(
        r'<script\s+id="__NEXT_DATA__"\s+type="application/json">\s*(\{.+?\})\s*</script>',
        dotAll: true,
      ),
      // Legacy session/entity patterns
      RegExp(
        r'<script\s+id="session"\s+type="application/json">\s*(\{.+?\})\s*</script>',
        dotAll: true,
      ),
      RegExp(
        r'Spotify\.Entity\s*=\s*(\{.+?\});\s*</script>',
        dotAll: true,
      ),
      // Resource JSON
      RegExp(
        r'<script\s+type="application/json"\s+id="initial-state">\s*(\{.+?\})\s*</script>',
        dotAll: true,
      ),
    ];

    for (final pattern in patterns) {
      final m = pattern.firstMatch(html);
      if (m != null) {
        try {
          jsonData = jsonDecode(m.group(1)!) as Map<String, dynamic>;
          if (kDebugMode) {
            debugPrint(
                'SpotifyPlaylistService: Matched pattern, top-level keys: ${jsonData.keys.toList()}');
          }
          break;
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                'SpotifyPlaylistService: Pattern matched but JSON decode failed: $e');
          }
          continue;
        }
      }
    }

    if (jsonData == null) {
      if (kDebugMode) {
        debugPrint(
            'SpotifyPlaylistService: No pattern matched. HTML length=${html.length}');
        // Print a snippet around known script tags for debugging
        final nextDataIdx = html.indexOf('__NEXT_DATA__');
        if (nextDataIdx >= 0) {
          debugPrint(
              'SpotifyPlaylistService: Found __NEXT_DATA__ at index $nextDataIdx');
          final snippet = html.substring(
            nextDataIdx,
            (nextDataIdx + 200).clamp(0, html.length),
          );
          debugPrint('SpotifyPlaylistService: Snippet: $snippet');
        }
      }
      throw const ParseException(
        'Could not extract track data from the Spotify page. '
        'Spotify may have changed their page structure.',
      );
    }

    // ── Step 4: parse tracks ──
    final tracks = <PlaylistTrack>[];

    // Navigate multiple possible JSON structures
    List<dynamic>? items;
    try {
      items = _findTrackItems(jsonData);
      if (kDebugMode) {
        debugPrint(
            'SpotifyPlaylistService: Found ${items?.length ?? 0} track items');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SpotifyPlaylistService: _findTrackItems error: $e');
      }
    }

    if (items == null || items.isEmpty) {
      throw const ParseException(
        'No tracks found in the playlist. '
        'The playlist may be empty or Spotify changed their data format.',
      );
    }

    for (final item in items) {
      try {
        final track = _parseTrackItem(item);
        if (track != null) tracks.add(track);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SpotifyPlaylistService: Skipping unparseable item: $e');
        }
      }
    }

    if (tracks.isEmpty) {
      throw const ParseException(
        'Could not parse any tracks from the playlist data.',
      );
    }

    if (kDebugMode) {
      debugPrint(
          'SpotifyPlaylistService: Imported ${tracks.length} tracks from playlist $playlistId');
    }

    return tracks;
  }

  // ── Helpers ────────────────────────────────────────────────────

  /// Walk the JSON tree and find the track items list.
  /// Spotify nests this in different places depending on the embed version.
  List<dynamic>? _findTrackItems(Map<String, dynamic> json) {
    // Path 1: __NEXT_DATA__ → props → pageProps → state → data → entity → trackList
    try {
      final entity = _dig(json, [
        'props', 'pageProps', 'state', 'data', 'entity',
      ]) as Map<String, dynamic>?;
      if (entity != null) {
        final trackList = entity['trackList'] as List<dynamic>?;
        if (trackList != null && trackList.isNotEmpty) return trackList;
      }
    } catch (_) {}

    // Path 1b: state → data → entity → trackList (embed format without __NEXT_DATA__ wrapper)
    try {
      final entity = _dig(json, [
        'state', 'data', 'entity',
      ]) as Map<String, dynamic>?;
      if (entity != null) {
        final trackList = entity['trackList'] as List<dynamic>?;
        if (trackList != null && trackList.isNotEmpty) return trackList;
      }
    } catch (_) {}

    // Path 2: entities → items
    try {
      final entities = json['entities'] as Map<String, dynamic>?;
      if (entities != null) {
        final items = entities['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) return items;
      }
    } catch (_) {}

    // Path 3: tracks → items (legacy embed)
    try {
      final tracks = json['tracks'] as Map<String, dynamic>?;
      if (tracks != null) {
        final items = tracks['items'] as List<dynamic>?;
        if (items != null && items.isNotEmpty) return items;
      }
    } catch (_) {}

    // Path 4: deep scan for any key named 'items' or 'trackList' that contains track-like objects
    final items = _deepFindItems(json);
    if (items != null && items.isNotEmpty) return items;

    return null;
  }

  /// Parse a single track item from the JSON.
  PlaylistTrack? _parseTrackItem(dynamic item) {
    if (item == null) return null;

    Map<String, dynamic>? trackMap;

    // Handle { track: { ... } } wrapper
    if (item is Map<String, dynamic>) {
      if (item.containsKey('track') && item['track'] is Map) {
        trackMap = item['track'] as Map<String, dynamic>;
      } else if (item.containsKey('name') || item.containsKey('title')) {
        // The item IS the track (embed format uses 'title', API uses 'name')
        trackMap = item;
      }
    }

    if (trackMap == null) return null;

    // Filter out podcasts / episodes
    // Embed format uses 'entityType', classic API uses 'type'
    final type = trackMap['type'] as String? ??
        trackMap['entityType'] as String? ??
        'track';
    if (type != 'track') return null;

    // Title: embed format uses 'title', classic API uses 'name'
    final title =
        trackMap['name'] as String? ?? trackMap['title'] as String?;
    if (title == null || title.isEmpty) return null;

    // Artists
    String artist = '';
    final artists = trackMap['artists'];
    if (artists is List && artists.isNotEmpty) {
      artist = artists
          .map((a) => (a is Map ? a['name'] : a)?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .join(', ');
    }
    // Embed format puts artist in 'subtitle'
    if (artist.isEmpty) {
      artist = trackMap['subtitle'] as String? ?? 'Unknown Artist';
    }

    // Album
    String album = '';
    final albumData = trackMap['album'];
    if (albumData is Map) {
      album = albumData['name'] as String? ?? '';
    }

    // Cover image
    String coverUrl = '';
    if (albumData is Map) {
      final images = albumData['images'] as List?;
      if (images != null && images.isNotEmpty) {
        // Pick the largest image
        coverUrl = (images.first is Map
                ? images.first['url']
                : images.first)
            ?.toString() ??
            '';
      }
    }
    // Fallback: track-level image
    if (coverUrl.isEmpty) {
      final images = trackMap['images'] as List?;
      if (images != null && images.isNotEmpty) {
        coverUrl = (images.first is Map
                ? images.first['url']
                : images.first)
            ?.toString() ??
            '';
      }
    }
    // Fallback: coverArt field (newer embed)
    if (coverUrl.isEmpty) {
      final coverArt = trackMap['coverArt'];
      if (coverArt is Map) {
        final sources = coverArt['sources'] as List?;
        if (sources != null && sources.isNotEmpty) {
          coverUrl = (sources.last as Map)['url']?.toString() ?? '';
        }
      }
    }

    // Duration: embed format uses 'duration', classic uses 'duration_ms'
    final durationMs = trackMap['duration_ms'] as int? ??
        trackMap['duration'] as int? ??
        0;

    return PlaylistTrack(
      title: title,
      artist: artist,
      album: album,
      coverUrl: coverUrl,
      durationMs: durationMs,
    );
  }

  /// Dig into nested maps by a list of keys.
  dynamic _dig(Map<String, dynamic> map, List<String> keys) {
    dynamic current = map;
    for (final key in keys) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Deep-scan the JSON tree for a key named 'items' or 'trackList' whose
  /// value is a list of maps containing track-like data.
  List<dynamic>? _deepFindItems(Map<String, dynamic> json, {int depth = 0}) {
    if (depth > 8) return null; // limit recursion

    for (final entry in json.entries) {
      if ((entry.key == 'items' || entry.key == 'trackList') &&
          entry.value is List) {
        final list = entry.value as List;
        if (list.isNotEmpty) {
          final first = list.first;
          // Check if it looks like a track item
          if (first is Map &&
              (first.containsKey('track') ||
               first.containsKey('name') ||
               first.containsKey('title'))) {
            return list;
          }
        }
      }
      if (entry.value is Map<String, dynamic>) {
        final result = _deepFindItems(
          entry.value as Map<String, dynamic>,
          depth: depth + 1,
        );
        if (result != null) return result;
      }
    }
    return null;
  }
}

