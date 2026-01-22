import '../models/podcasts.dart';
import '../models/song.dart';

enum PlaybackType { song, podcast }

class PlaybackItem {
  final PlaybackType type;
  final dynamic data;

  PlaybackItem({
    required this.type,
    required this.data,
  });

  factory PlaybackItem.song(Song song) {
    return PlaybackItem(
      type: PlaybackType.song,
      data: song,
    );
  }

  factory PlaybackItem.podcast(Podcast podcast) {
    return PlaybackItem(
      type: PlaybackType.podcast,
      data: podcast,
    );
  }
}

