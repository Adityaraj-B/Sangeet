import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/artist.dart';
import '../models/album.dart';

class SearchRepository {
  static const String baseUrl = 'https://vercelapi-gamma.vercel.app/api';

  // --- SONG SEARCH (JioSaavn) ---

  Future<List<Song>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    return searchSaavn(query, limit: limit);
  }

  /// Saavn-only search (used for sub-word queries and fallback).
  Future<List<Song>> searchSaavn(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$baseUrl/search/songs?query=${Uri.encodeComponent(query)}&limit=$limit',
      );

      final res = await http.get(uri);

      if (res.statusCode != 200) return [];

      return _parseSongs(res.body);
    } catch (_) {
      return [];
    }
  }

  // --- ARTIST SEARCH (Added) ---

  Future<List<Artist>> searchArtists(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$baseUrl/search/artists?query=${Uri.encodeComponent(query)}&limit=$limit',
      );

      final res = await http.get(uri);

      if (res.statusCode != 200) return [];

      return _parseArtists(res.body);
    } catch (e) {
      print('Error searching artists: $e');
      return [];
    }
  }

  // --- ALBUM SEARCH ---

  Future<List<Album>> searchAlbums(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$baseUrl/search/albums?query=${Uri.encodeComponent(query)}&limit=$limit',
      );

      final res = await http.get(uri);

      if (res.statusCode != 200) return [];

      return _parseAlbums(res.body);
    } catch (e) {
      print('Error searching albums: $e');
      return [];
    }
  }

  // --- AUTOCOMPLETE SUGGESTIONS (Spotify-like) ---

  /// Fetches autocomplete suggestions using the API's autocomplete endpoint.
  /// Returns a list of suggested search queries based on partial input.
  Future<List<String>> suggestions(String query, {int limit = 8}) async {
    if (query.trim().length < 2) return []; // Start suggesting after 2 chars

    try {
      // Try the autocomplete endpoint first (faster, more relevant)
      final uri = Uri.parse(
        '$baseUrl/search/autocomplete?query=${Uri.encodeComponent(query)}&limit=$limit',
      );

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final suggestions = _parseAutocompleteSuggestions(res.body);
        if (suggestions.isNotEmpty) {
          return suggestions.take(limit).toList();
        }
      }

      // Fallback: Quick search to get suggestions from results
      return await _fallbackSuggestions(query, limit);
    } catch (_) {
      return await _fallbackSuggestions(query, limit);
    }
  }

  /// Fallback method when autocomplete endpoint is unavailable.
  /// Searches songs, artists, AND albums for comprehensive suggestions.
  Future<List<String>> _fallbackSuggestions(String query, int limit) async {
    try {
      // Fetch quick searches in parallel for fast suggestions
      final results = await Future.wait([
        search(query, limit: 5),
        searchArtists(query, limit: 3),
        searchAlbums(query, limit: 3),
      ]);

      final songs = results[0] as List<Song>;
      final artists = results[1] as List<Artist>;
      final albums = results[2] as List<Album>;

      final suggestions = <String>{};

      // Add artist names first (highest priority — Spotify behavior)
      for (final artist in artists) {
        if (_matchesQuery(artist.name, query)) {
          suggestions.add(artist.name);
        }
      }

      // Add album names (critical for queries like "dhurandhar")
      for (final album in albums) {
        if (_matchesQuery(album.name, query)) {
          suggestions.add(album.name);
        }
      }

      // Add song titles — prefer high playCount songs
      final sortedSongs = List<Song>.from(songs)
        ..sort((a, b) => (b.playCount ?? 0).compareTo(a.playCount ?? 0));

      for (final song in sortedSongs) {
        if (_matchesQuery(song.title, query)) {
          suggestions.add(song.title);
        }
      }

      return suggestions.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// Check if a string matches the query (case-insensitive prefix or contains)
  bool _matchesQuery(String text, String query) {
    final normalizedText = text.toLowerCase().trim();
    final normalizedQuery = query.toLowerCase().trim();
    return normalizedText.startsWith(normalizedQuery) ||
           normalizedText.contains(normalizedQuery);
  }

  /// Parse autocomplete API response
  List<String> _parseAutocompleteSuggestions(String body) {
    try {
      final decoded = json.decode(body);
      final suggestions = <String>[];

      // Handle various API response formats
      if (decoded['data'] != null) {
        final data = decoded['data'];

        // Check for topquery (most relevant)
        if (data['topquery'] != null && data['topquery']['results'] is List) {
          for (final item in data['topquery']['results']) {
            final title = item['title']?.toString() ?? item['name']?.toString();
            if (title != null && title.isNotEmpty) {
              suggestions.add(title);
            }
          }
        }

        // Check for songs suggestions
        if (data['songs'] != null && data['songs']['results'] is List) {
          for (final item in data['songs']['results']) {
            final title = item['title']?.toString() ?? item['name']?.toString();
            if (title != null && title.isNotEmpty && !suggestions.contains(title)) {
              suggestions.add(title);
            }
          }
        }

        // Check for artists suggestions
        if (data['artists'] != null && data['artists']['results'] is List) {
          for (final item in data['artists']['results']) {
            final name = item['name']?.toString() ?? item['title']?.toString();
            if (name != null && name.isNotEmpty && !suggestions.contains(name)) {
              suggestions.add(name);
            }
          }
        }

        // Check for albums suggestions
        if (data['albums'] != null && data['albums']['results'] is List) {
          for (final item in data['albums']['results']) {
            final title = item['title']?.toString() ?? item['name']?.toString();
            if (title != null && title.isNotEmpty && !suggestions.contains(title)) {
              suggestions.add(title);
            }
          }
        }
      }

      // Handle simple array response
      if (decoded is List) {
        for (final item in decoded) {
          if (item is String) {
            suggestions.add(item);
          } else if (item is Map) {
            final title = item['title']?.toString() ??
                          item['name']?.toString() ??
                          item['query']?.toString();
            if (title != null && title.isNotEmpty) {
              suggestions.add(title);
            }
          }
        }
      }

      return suggestions;
    } catch (_) {
      return [];
    }
  }

  // --- PARSING HELPERS ---

  List<Song> _parseSongs(String body) {
    try {
      final decoded = json.decode(body);
      final data = decoded['data'];

      List list = [];

      if (data is List) {
        list = data;
      } else if (data is Map && data['results'] is List) {
        list = data['results'];
      }

      return list.map(_parseSingleSong).toList();
    } catch (_) {
      return [];
    }
  }

  List<Artist> _parseArtists(String body) {
    try {
      final decoded = json.decode(body);
      final data = decoded['data'];

      List list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data['results'] is List) {
        list = data['results'];
      }

      return list.map(_parseSingleArtist).toList();
    } catch (_) {
      return [];
    }
  }

  Song _parseSingleSong(dynamic e) {
    final String id = e['id']?.toString() ?? '';
    final String title = e['name']?.toString() ?? 'Unknown';

    String artist = 'Unknown';
    if (e['artists']?['primary'] is List) {
      artist = (e['artists']['primary'] as List)
          .map((a) => a['name'])
          .where((n) => n != null && n.toString().isNotEmpty)
          .join(', ');
    } else if (e['primaryArtists'] != null) {
      artist = e['primaryArtists'].toString();
    }

    String coverUrl = '';
    if (e['image'] is List && (e['image'] as List).isNotEmpty) {
      final img = (e['image'] as List).last;
      coverUrl = img['link']?.toString() ?? img['url']?.toString() ?? '';
    }

    final int durationSeconds =
        int.tryParse(e['duration']?.toString() ?? '') ?? 0;

    String? streamUrl;
    if (e['downloadUrl'] is List && (e['downloadUrl'] as List).isNotEmpty) {
      final dl = (e['downloadUrl'] as List).last;
      streamUrl = dl['link']?.toString() ?? dl['url']?.toString();
    }

    final int? playCount = int.tryParse(e['playCount']?.toString() ?? '');
    final String? language = e['language']?.toString();
    final String? year = e['year']?.toString();

    return Song(
      id: id,
      title: title,
      artist: artist,
      coverUrl: coverUrl,
      duration: Duration(seconds: durationSeconds),
      streamUrl: streamUrl,
      playCount: playCount,
      language: language,
      year: year,
    );
  }

  Artist _parseSingleArtist(dynamic e) {
    final String id = e['id']?.toString() ?? '';
    final String name = e['name']?.toString() ?? e['title']?.toString() ?? 'Unknown';
    final String type = e['role']?.toString() ?? 'Artist';

    String imageUrl = '';
    if (e['image'] is List && (e['image'] as List).isNotEmpty) {
      final img = (e['image'] as List).last;
      imageUrl = img['link']?.toString() ?? img['url']?.toString() ?? '';
    }

    String bio = '';
    if (e['bio'] is List && (e['bio'] as List).isNotEmpty) {
      bio = e['bio'][0]['text']?.toString() ?? '';
    } else if (e['bio'] is String) {
      bio = e['bio'];
    }

    return Artist(
      id: id,
      name: name,
      imageUrl: imageUrl,
      type: type,
      bio: bio,
    );
  }

  List<Album> _parseAlbums(String body) {
    try {
      final decoded = json.decode(body);
      final data = decoded['data'];

      List list = [];
      if (data is List) {
        list = data;
      } else if (data is Map && data['results'] is List) {
        list = data['results'];
      }

      return list.map(_parseSingleAlbum).toList();
    } catch (_) {
      return [];
    }
  }

  Album _parseSingleAlbum(dynamic e) {
    final String id = e['id']?.toString() ?? '';
    final String name = e['name']?.toString() ?? e['title']?.toString() ?? 'Unknown';

    String artist = 'Unknown';
    if (e['artists']?['primary'] is List) {
      artist = (e['artists']['primary'] as List)
          .map((a) => a['name'])
          .where((n) => n != null && n.toString().isNotEmpty)
          .join(', ');
    } else if (e['primaryArtists'] != null) {
      artist = e['primaryArtists'].toString();
    } else if (e['artist'] != null) {
      artist = e['artist'].toString();
    }

    String coverUrl = '';
    if (e['image'] is List && (e['image'] as List).isNotEmpty) {
      final img = (e['image'] as List).last;
      coverUrl = img['link']?.toString() ?? img['url']?.toString() ?? '';
    }

    final int songCount = int.tryParse(e['songCount']?.toString() ?? '') ?? 0;
    final String year = e['year']?.toString() ?? '';

    return Album(
      id: id,
      name: name,
      artist: artist,
      coverUrl: coverUrl,
      songCount: songCount,
      year: year,
    );
  }
}