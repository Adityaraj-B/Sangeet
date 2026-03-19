class Song {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final Duration duration;
  final String? streamUrl;
  final int? playCount;
  final String? language;
  final String? year;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.duration,
    this.streamUrl,
    this.playCount,
    this.language,
    this.year,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? coverUrl,
    Duration? duration,
    String? streamUrl,
    int? playCount,
    String? language,
    String? year,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      streamUrl: streamUrl ?? this.streamUrl,
      playCount: playCount ?? this.playCount,
      language: language ?? this.language,
      year: year ?? this.year,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'coverUrl': coverUrl,
      'duration': duration.inSeconds,
      'streamUrl': streamUrl,
      'playCount': playCount,
      'language': language,
      'year': year,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      coverUrl: json['coverUrl'],
      duration: Duration(seconds: json['duration'] ?? 0),
      streamUrl: json['streamUrl'],
      playCount: json['playCount'],
      language: json['language'],
      year: json['year'],
    );
  }

  @override
  String toString() {
    return 'Song(id: $id, title: $title, artist: $artist, streamUrl: $streamUrl)';
  }
}