import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import '../models/artist.dart'; // Make sure this import exists

class SearchRepository {
  static const String baseUrl = 'https://vercelapi-gamma.vercel.app/api';

  // --- SONG SEARCH ---

  Future<List<Song>> search(String query, {int limit = 20}) async {
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

  // --- SUGGESTIONS ---

  Future<List<String>> suggestions(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return [];

    final songs = await search(query, limit: limit);
    return songs.map((s) => s.title).toSet().toList();
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

    return Song(
      id: id,
      title: title,
      artist: artist,
      coverUrl: coverUrl,
      duration: Duration(seconds: durationSeconds),
      streamUrl: streamUrl,
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
}