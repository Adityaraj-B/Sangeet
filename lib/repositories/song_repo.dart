import '../data/song_remote_source.dart';
import '../models/song.dart';

class SongRepo {
  final SongRemoteSource remote;

  SongRepo(this.remote);

  Future<List<Song>> getHomeSongs() {
    return remote.fetchHomeSongs();
  }
}
