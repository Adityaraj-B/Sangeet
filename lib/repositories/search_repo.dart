import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sangeet/models/song.dart';

class SearchRepository {
  static const String baseUrl =
      'https://jiosaavn-api.acefaroff.workers.dev/api';

  Future<List<Song>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$baseUrl/search/songs?query=${Uri.encodeComponent(query)}&limit=$limit',
      );

      final res = await http.get(uri);

      if (res.statusCode != 200) return [];

      return _parseSongs(res.body);
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }

  Future<List<String>> suggestions(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return [];

    final songs = await search(query, limit: limit);
    return songs.map((s) => s.title).toSet().toList();
  }

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
    } catch (e) {
      print('Parse songs error: $e');
      return [];
    }
  }

  Song _parseSingleSong(dynamic e) {
    final id = e['id']?.toString() ?? '';
    final title = e['name']?.toString() ?? 'Unknown';

    // Parse artist
    String artist = 'Unknown';
    if (e['artists']?['primary'] is List) {
      artist = (e['artists']['primary'] as List)
          .map((a) => a['name'])
          .where((n) => n != null && n.toString().isNotEmpty)
          .join(', ');
    } else if (e['primaryArtists'] != null) {
      artist = e['primaryArtists'].toString();
    }

    // Parse cover image
    String coverUrl = '';
    if (e['image'] is List && (e['image'] as List).isNotEmpty) {
      final images = e['image'] as List;
      coverUrl = images.last['link']?.toString() ??
          images.last['url']?.toString() ??
          '';
    }

    // Parse duration
    final durationSeconds =
        int.tryParse(e['duration']?.toString() ?? '') ?? 0;

    // Parse stream URL - THIS IS THE KEY FIX!
    String? streamUrl;
    if (e['downloadUrl'] is List && (e['downloadUrl'] as List).isNotEmpty) {
      final downloads = e['downloadUrl'] as List;
      // Get the highest quality (usually last in array)
      streamUrl = downloads.last['link']?.toString() ??
          downloads.last['url']?.toString();
    }

    print('Parsed song: $title, streamUrl: ${streamUrl?.substring(0, 50)}...');

    return Song(
      id: id,
      title: title,
      artist: artist,
      coverUrl: coverUrl,
      duration: Duration(seconds: durationSeconds),
      streamUrl: streamUrl, // Already included in search results!
    );
  }
}