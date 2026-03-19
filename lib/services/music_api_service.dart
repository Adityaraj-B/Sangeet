import '../models/song.dart';

abstract class MusicApiService {
  Future<List<Song>> getTrending();
  Future<List<Song>> searchSongs(String query, {int limit = 20});
}
