/// A track scraped from a public Spotify playlist page.
///
/// This is an intermediate model used during import.  After the user
/// confirms, each [PlaylistTrack] is matched to a JioSaavn [Song] via
/// search, so the app never needs to stream from Spotify.
class PlaylistTrack {
  final String title;
  final String artist;
  final String album;
  final String coverUrl;
  final int durationMs;

  const PlaylistTrack({
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    required this.durationMs,
  });

  factory PlaylistTrack.fromJson(Map<String, dynamic> json) {
    return PlaylistTrack(
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String? ?? '',
      album: json['album'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      durationMs: json['durationMs'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'coverUrl': coverUrl,
      'durationMs': durationMs,
    };
  }

  /// Human-readable duration string (e.g. "3:42").
  String get formattedDuration {
    final d = Duration(milliseconds: durationMs);
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  String toString() =>
      'PlaylistTrack(title: $title, artist: $artist, album: $album)';
}

