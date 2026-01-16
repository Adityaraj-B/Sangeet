enum PlaybackType { song, podcast }

class PlaybackItem {
  final PlaybackType type;
  final dynamic data;

  const PlaybackItem({
    required this.type,
    required this.data,
  });
}
