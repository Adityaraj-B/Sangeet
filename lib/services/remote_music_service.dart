import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/artist.dart';
import '../models/song.dart';
import '../models/album.dart';
import 'music_api_service.dart';

class RemoteMusicService implements MusicApiService {
  final String baseUrl;

  RemoteMusicService(this.baseUrl);

  // --- ARTIST METHODS ---

  Future<Artist?> getArtistDetails(String artistId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/artists?id=$artistId'),
      );

      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final data = body['data'];

        if (data != null) {
          return Artist.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting artist details: $e');
      }
      return null;
    }
  }

  /// Fetches ALL songs for an artist by making multiple paginated requests
  Future<List<Song>> getArtistSongs(String artistId, {int page = 0}) async {
    try {
      final List<Song> allSongs = [];
      int currentPage = 0;
      bool hasMore = true;

      // Keep fetching until we get less than 10 songs (indicating last page)
      while (hasMore && currentPage < 100) { // Safety limit of 100 pages
        final res = await http.get(
          Uri.parse('$baseUrl/artists/$artistId/songs?page=$currentPage'),
        );

        if (res.statusCode == 200) {
          final body = json.decode(res.body);

          List songsData = [];
          if (body['data'] != null) {
            if (body['data']['songs'] != null) {
              songsData = body['data']['songs'];
            } else if (body['data']['results'] != null) {
              songsData = body['data']['results'];
            } else if (body['data'] is List) {
              songsData = body['data'];
            }
          }

          // Parse songs from this page
          for (final e in songsData) {
            final song = _parseSingleSong(e);
            if (song.id.isNotEmpty) {
              allSongs.add(song);
            }
          }

          // Check if we should continue fetching
          if (songsData.isEmpty || songsData.length < 10) {
            hasMore = false; // Last page reached
          } else {
            currentPage++;
            // Small delay to avoid rate limiting
            await Future.delayed(const Duration(milliseconds: 100));
          }
        } else {
          hasMore = false;
        }
      }

      return allSongs;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting artist songs: $e');
      }
      return [];
    }
  }

  // --- ALBUM METHODS ---

  Future<List<Album>> getTrendingAlbums() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/search/albums?query=latest%20hindi&limit=20'),
      );

      if (res.statusCode == 200) {
        return _parseAlbums(res.body);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting trending albums: $e');
      }
      return [];
    }
  }

  Future<List<Album>> searchAlbums(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final res = await http.get(
        Uri.parse('$baseUrl/search/albums?query=$encodedQuery&limit=50'),
      );

      if (res.statusCode == 200) {
        return _parseAlbums(res.body);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error searching albums: $e');
      }
      return [];
    }
  }

  Future<List<Song>> getAlbumSongs(String albumId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/albums?id=$albumId'),
      );

      if (res.statusCode == 200) {
        final body = json.decode(res.body);

        List songsData = [];
        if (body['data'] != null) {
          songsData = body['data']['songs'] ?? body['data']['list'] ?? [];
        } else {
          songsData = body['songs'] ?? body['list'] ?? [];
        }

        final List<Song> parsedSongs = [];
        for (final e in songsData) {
          final song = _parseSingleSong(e);
          if (song.id.isNotEmpty) {
            parsedSongs.add(song);
          }
        }
        return parsedSongs;
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting album songs: $e');
      }
      return [];
    }
  }

  // --- SONG METHODS ---

  @override
  Future<List<Song>> getTrending() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/search/songs?query=latest%20hindi&limit=20'),
      );

      if (res.statusCode == 200) {
        return _parseSongs(res.body);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting trending songs: $e');
      }
      return [];
    }
  }

  @override
  Future<List<Song>> searchSongs(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final res = await http.get(
        Uri.parse('$baseUrl/search/songs?query=$encodedQuery&limit=20'),
      );

      if (res.statusCode == 200) {
        return _parseSongs(res.body);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error searching songs: $e');
      }
      return [];
    }
  }

  Future<List<Song>> getSongSuggestions(String id) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/songs/$id/suggestions?limit=20'),
      );

      if (res.statusCode == 200) {
        return _parseSongs(res.body);
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting song suggestions: $e');
      }
      return [];
    }
  }

  // --- PARSING HELPERS ---

  List<Album> _parseAlbums(String responseBody) {
    try {
      final body = json.decode(responseBody);
      List albums = [];

      if (body['data'] != null) {
        final data = body['data'];
        if (data is Map && data['results'] is List) {
          albums = data['results'];
        } else if (data is List) {
          albums = data;
        }
      }

      final List<Album> parsedAlbums = [];
      for (final e in albums) {
        final album = _parseSingleAlbum(e);
        if (album.id.isNotEmpty) {
          parsedAlbums.add(album);
        }
      }
      return parsedAlbums;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error parsing albums: $e');
      }
      return [];
    }
  }

  Album _parseSingleAlbum(dynamic e) {
    final String id = e['id']?.toString() ?? '';
    final String name = e['name']?.toString() ?? e['title']?.toString() ?? 'Unknown Album';

    String artistName = 'Unknown';
    if (e['primaryArtists'] != null && e['primaryArtists'].toString().isNotEmpty) {
      artistName = e['primaryArtists'].toString();
    } else if (e['artists'] != null && e['artists']['primary'] != null) {
      final primary = e['artists']['primary'];
      if (primary is List && primary.isNotEmpty) {
        artistName = primary.map((a) => a['name'] ?? '').join(', ');
      }
    } else if (e['artist'] != null) {
      artistName = e['artist'].toString();
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
      artist: artistName,
      coverUrl: coverUrl,
      songCount: songCount,
      year: year,
    );
  }

  List<Song> _parseSongs(String responseBody) {
    try {
      final body = json.decode(responseBody);
      List songs = [];

      if (body['data'] != null) {
        final data = body['data'];
        if (data is Map && data['results'] is List) {
          songs = data['results'];
        } else if (data is List) {
          songs = data;
        }
      }

      final List<Song> parsedSongs = [];
      for (final e in songs) {
        final song = _parseSingleSong(e);
        if (song.id.isNotEmpty) {
          parsedSongs.add(song);
        }
      }
      return parsedSongs;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error parsing songs: $e');
      }
      return [];
    }
  }

  Song _parseSingleSong(dynamic e) {
    final String id = e['id']?.toString() ?? '';
    final String title = e['name']?.toString() ?? e['title']?.toString() ?? 'Unknown';

    String artistName = 'Unknown';
    if (e['primaryArtists'] != null && e['primaryArtists'].toString().isNotEmpty) {
      artistName = e['primaryArtists'].toString();
    } else if (e['artists'] != null && e['artists']['primary'] != null) {
      final primary = e['artists']['primary'];
      if (primary is List && primary.isNotEmpty) {
        artistName = primary.map((a) => a['name'] ?? '').join(', ');
      }
    }

    String coverUrl = '';
    if (e['image'] is List && (e['image'] as List).isNotEmpty) {
      final img = (e['image'] as List).last;
      coverUrl = img['link']?.toString() ?? img['url']?.toString() ?? '';
    }

    String streamUrl = '';
    if (e['downloadUrl'] is List && (e['downloadUrl'] as List).isNotEmpty) {
      final dl = (e['downloadUrl'] as List).last;
      streamUrl = dl['link']?.toString() ?? dl['url']?.toString() ?? '';
    }

    final int durationSeconds = int.tryParse(e['duration']?.toString() ?? '') ?? 0;
    final int? playCount = int.tryParse(e['playCount']?.toString() ?? '');
    final String? language = e['language']?.toString();
    final String? year = e['year']?.toString();

    return Song(
      id: id,
      title: title,
      artist: artistName,
      coverUrl: coverUrl,
      duration: Duration(seconds: durationSeconds),
      streamUrl: streamUrl,
      playCount: playCount,
      language: language,
      year: year,
    );
  }
}