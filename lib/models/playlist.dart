// lib/models/playlist.dart

import 'package:sangeet/models/song.dart';

class Playlist {
  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final List<Song> songs;
  final List<String> songIds; // Add this to track song IDs from Firestore
  final DateTime createdAt;
  final DateTime updatedAt;

  const Playlist({
    required this.id,
    required this.title,
    this.description = '',
    this.coverUrl = '',
    this.songs = const [],
    this.songIds = const [], // Add this parameter
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'coverUrl': coverUrl,
      'songs': songs.map((s) => s.toJson()).toList(),
      'songIds': songIds, // Include songIds
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      coverUrl: json['coverUrl'] ?? '',
      songs: (json['songs'] as List<dynamic>?)
          ?.map((s) => Song.fromJson(s))
          .toList() ??
          [],
      songIds: (json['songIds'] as List<dynamic>?)?.cast<String>() ?? [], // Parse songIds
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  // Create a copy with modifications
  Playlist copyWith({
    String? title,
    String? description,
    String? coverUrl,
    List<Song>? songs,
    List<String>? songIds, // Add this parameter
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      songs: songs ?? this.songs,
      songIds: songIds ?? this.songIds, // Include songIds
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get playlist duration
  Duration get totalDuration {
    return songs.fold(
      Duration.zero,
          (total, song) => total + song.duration,
    );
  }

  // Format duration as "1h 23m"
  String get formattedDuration {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

// Also add toJson to Song model if not already there
extension SongJson on Song {
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

  static Song fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      coverUrl: json['coverUrl'],
      duration: Duration(seconds: json['duration']),
      streamUrl: json['streamUrl'],
    );
  }
}