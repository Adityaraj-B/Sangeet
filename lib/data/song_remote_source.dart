import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/song.dart';

class SongRemoteSource {
  Future<List<Song>> fetchHomeSongs() async {
    final uri = Uri.parse('YOUR_API_URL_HERE');
    final res = await http.get(uri);
    final body = json.decode(res.body);

    final List list = body['data'];

    return list.map((e) {
      return Song(
        id: e['id'].toString(),
        title: e['title'],
        artist: e['artist'],
        coverUrl: e['image'],
        duration: Duration(seconds: int.parse(e['duration'].toString())),
        streamUrl: e['stream_url'],
      );
    }).toList();
  }
}
