class Song {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final Duration duration;
  final String? streamUrl;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.duration,
    this.streamUrl,
  });
  // Add copyWith method for creating new instances with updated fields
  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? coverUrl,
    Duration? duration,
    String? streamUrl,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }

  // Add these methods to Song class
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'coverUrl': coverUrl,
      'duration': duration.inSeconds,
      'streamUrl': streamUrl,
    };
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      coverUrl: json['coverUrl'],
      duration: Duration(seconds: json['duration']),
      streamUrl: json['streamUrl'],
    );
  }
  
  @override
  String toString() {
    return 'Song(id: $id, title: $title, artist: $artist, streamUrl: $streamUrl)';
  }
}