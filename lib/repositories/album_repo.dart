import 'dart:convert';
import 'package:http/http.dart' as http;

class AlbumRepository {
  static const String baseUrl = 'https://vercelapi-gamma.vercel.app/api';

  Future<List<dynamic>> searchAlbums(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$baseUrl/search/albums?query=${Uri.encodeComponent(query)}&limit=$limit',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) return [];

      final decoded = json.decode(res.body);
      return decoded['data']['results'] ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAlbumDetails(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/albums?id=$id');
      final res = await http.get(uri);

      if (res.statusCode != 200) return null;

      final decoded = json.decode(res.body);
      return decoded['data'];
    } catch (e) {
      return null;
    }
  }
}