import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';
import 'music_api_service.dart';

class RemoteMusicService implements MusicApiService {
  final String baseUrl;

  RemoteMusicService(this.baseUrl);

  @override
  Future<List<Song>> getTrending() async {
    try {
      // Use search with "latest hindi" as it works from your test
      final res = await http.get(
          Uri.parse('$baseUrl/search/songs?query=latest%20hindi&limit=15')
      );

      if (res.statusCode == 200) {
        return _parseSongs(res.body);
      }
      print('getTrending failed with status: ${res.statusCode}');
      return [];
    } catch (e) {
      print('Error in getTrending: $e');
      return [];
    }
  }

  @override
  Future<List<Song>> searchSongs(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final res = await http.get(
          Uri.parse('$baseUrl/search/songs?query=$encodedQuery&limit=15')
      );

      if (res.statusCode == 200) {
        return _parseSongs(res.body);
      }
      return [];
    } catch (e) {
      print('Error in searchSongs: $e');
      return [];
    }
  }

  Future<List<Song>> getSongSuggestions(String id) async {
    try {
      final res = await http.get(
          Uri.parse('$baseUrl/songs/$id/suggestions?limit=15')
      );

      if (res.statusCode == 200) {
        return _parseSongs(res.body);
      }
      return [];
    } catch (e) {
      print('Error in getSongSuggestions: $e');
      return [];
    }
  }

  List<Song> _parseSongs(String responseBody) {
    try {
      final body = json.decode(responseBody);

      // Based on your test: structure is { data: { results: [...] } }
      List songs = [];

      if (body['data'] != null) {
        if (body['data']['results'] != null && body['data']['results'] is List) {
          songs = body['data']['results'];
        } else if (body['data'] is List) {
          // Some endpoints might return data as direct array
          songs = body['data'];
        }
      }

      if (songs.isEmpty) {
        print('No songs found in response');
        return [];
      }

      print('Parsing ${songs.length} songs');

      List<Song> parsedSongs = [];
      for (var e in songs) {
        try {
          final song = _parseSingleSong(e);
          if (song.id.isNotEmpty) {
            parsedSongs.add(song);
          }
        } catch (err) {
          print('Failed to parse song: $err');
        }
      }

      return parsedSongs;

    } catch (e) {
      print('Error in _parseSongs: $e');
      return [];
    }
  }

  Song _parseSingleSong(dynamic e) {
    // Extract ID
    String id = e['id']?.toString() ?? '';

    // Extract title (API uses 'name' field)
    String title = e['name']?.toString() ?? e['title']?.toString() ?? 'Unknown';

    // Extract artist
    String artistName = 'Unknown';

    // Check for primaryArtists field (common in JioSaavn API)
    if (e['primaryArtists'] != null && e['primaryArtists'].toString().isNotEmpty) {
      artistName = e['primaryArtists'].toString();
    }
    // Check artists.primary array
    else if (e['artists'] != null && e['artists']['primary'] != null) {
      final primary = e['artists']['primary'];
      if (primary is List && primary.isNotEmpty) {
        artistName = primary.map((a) => a['name'] ?? '').join(', ');
      }
    }

    // Extract image/cover URL
    String coverUrl = '';
    if (e['image'] != null && e['image'] is List) {
      final images = e['image'] as List;
      if (images.isNotEmpty) {
        // Get highest quality (last image in array)
        final img = images.last;
        coverUrl = img['link']?.toString() ?? img['url']?.toString() ?? '';
      }
    }

    // Extract download/stream URL
    String streamUrl = '';
    if (e['downloadUrl'] != null && e['downloadUrl'] is List) {
      final downloads = e['downloadUrl'] as List;
      if (downloads.isNotEmpty) {
        // Get highest quality (last in array, usually 320kbps)
        final dl = downloads.last;
        streamUrl = dl['link']?.toString() ?? dl['url']?.toString() ?? '';
      }
    }

    // Extract duration
    int durationSeconds = 0;
    if (e['duration'] != null) {
      durationSeconds = int.tryParse(e['duration'].toString()) ?? 0;
    }

    return Song(
      id: id,
      title: title,
      artist: artistName,
      coverUrl: coverUrl,
      duration: Duration(seconds: durationSeconds),
      streamUrl: streamUrl,
    );
  }
}