import 'dart:convert';
import 'package:http/http.dart' as http;

class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});
}

class LyricsService {
  static const String _baseUrl = "https://lrclib.net/api/get";

  // Cache to avoid repeated API calls for the same song
  final Map<String, List<LyricLine>> _cache = {};

  Future<List<LyricLine>> fetchLyrics(String artist, String track) async {
    final cacheKey = '$artist-$track'.toLowerCase();

    // Return cached lyrics if available
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      "artist_name": artist,
      "track_name": track,
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Prefer synced lyrics, fall back to plain text
        String rawLyrics = data['syncedLyrics'] ?? data['plainLyrics'] ?? "";
        final lyrics = _parseLrc(rawLyrics);
        _cache[cacheKey] = lyrics;
        return lyrics;
      }
    } catch (e) {
      print("Error fetching lyrics: $e");
    }
    return [];
  }

  List<LyricLine> _parseLrc(String lrc) {
    final List<LyricLine> lines = [];
    // Regex matches [00:12.34] or [00:12]
    final RegExp regex = RegExp(r'^\[(\d{2}):(\d{2})(?:\.(\d+))?\](.*)');

    for (var line in lrc.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final int minutes = int.parse(match.group(1)!);
        final int seconds = int.parse(match.group(2)!);
        // Handle optional milliseconds
        final int millis = match.group(3) != null
            ? int.parse(match.group(3)!.padRight(3, '0').substring(0, 3))
            : 0;

        lines.add(LyricLine(
          timestamp: Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
          text: match.group(4)?.trim() ?? "",
        ));
      }
    }
    return lines;
  }

  void clearCache() {
    _cache.clear();
  }
}

