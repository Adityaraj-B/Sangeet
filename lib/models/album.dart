class Album {
  final String id;
  final String name;
  final String artist;
  final String coverUrl;
  final int songCount;
  final String year;

  const Album({
    required this.id,
    required this.name,
    required this.artist,
    required this.coverUrl,
    this.songCount = 0,
    this.year = '',
  });

  @override
  String toString() {
    return 'Album(id: $id, name: $name, artist: $artist)';
  }
}