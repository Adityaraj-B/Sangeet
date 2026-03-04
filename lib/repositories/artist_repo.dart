import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/artist.dart';
import '../models/song.dart';

class ArtistRepository {
  static const String baseUrl = 'https://vercelapi-gamma.vercel.app/api';

  /// Search for artists
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

  /// Get detailed info about a specific artist
  Future<Artist?> getArtistDetails(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/artists?id=$id');
      final res = await http.get(uri);

      if (res.statusCode != 200) return null;

      final decoded = json.decode(res.body);
      final data = decoded['data'];

      if (data != null) {
        return _parseSingleArtist(data);
      }
      return null;
    } catch (e) {
      print('Error getting artist details: $e');
      return null;
    }
  }

  /// Get songs by a specific artist
  Future<List<Song>> getArtistSongs(String artistId, {int page = 0}) async {
    try {
      final uri = Uri.parse(
          '$baseUrl/artists/$artistId/songs?page=$page&limit=20');

      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final decoded = json.decode(res.body);

      // The API structure for artist songs can vary slightly
      var songsData;
      if (decoded['data'] != null) {
        if (decoded['data']['songs'] != null) {
          songsData = decoded['data']['songs'];
        } else if (decoded['data'] is List) {
          songsData = decoded['data'];
        }
      }

      if (songsData is List) {
        return songsData.map((e) => _parseSingleSong(e)).toList();
      }

      return [];
    } catch (e) {
      print('Error getting artist songs: $e');
      return [];
    }
  }

  // --- PARSING HELPERS ---

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

      return list.map((e) => _parseSingleArtist(e)).toList();
    } catch (_) {
      return [];
    }
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

    // Bio handling
    String bio = '';
    if (e['bio'] is List && (e['bio'] as List).isNotEmpty) {
      // Sometimes bio is a list of objects with 'text'
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

  // Reusing Song parsing logic for Artist Songs
  Song _parseSingleSong(dynamic e) {
    final String id = e['id']?.toString() ?? '';
    final String title = e['name']?.toString() ?? 'Unknown';

    String artist = 'Unknown';
    if (e['primaryArtists'] != null && e['primaryArtists'].toString().isNotEmpty) {
      artist = e['primaryArtists'].toString();
    } else if (e['artists'] != null && e['artists']['primary'] != null) {
      final primary = e['artists']['primary'];
      if (primary is List && primary.isNotEmpty) {
        artist = primary.map((a) => a['name'] ?? '').join(', ');
      }
    }

    String coverUrl = '';
    if (e['image'] is List && (e['image'] as List).isNotEmpty) {
      final img = (e['image'] as List).last;
      coverUrl = img['link']?.toString() ?? img['url']?.toString() ?? '';
    }

    String? streamUrl = '';
    if (e['downloadUrl'] is List && (e['downloadUrl'] as List).isNotEmpty) {
      final dl = (e['downloadUrl'] as List).last;
      streamUrl = dl['link']?.toString() ?? dl['url']?.toString();
    }

    final int durationSeconds = int.tryParse(e['duration']?.toString() ?? '') ?? 0;
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
}