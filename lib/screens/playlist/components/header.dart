import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/playlist.dart';
import '../../../models/song.dart';
import '../../../services/playlist_provider.dart';

class PlaylistHeader extends StatelessWidget {
  final Playlist playlist;

  const PlaylistHeader({super.key, required this.playlist});

  String _formatDuration(List<Song> songs) {
    if (songs.isEmpty) return "0 MINS";

    final totalSeconds = songs.fold<int>(0, (previousValue, element) => previousValue + element.duration.inSeconds);
    final duration = Duration(seconds: totalSeconds);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return "$hours HR $minutes MINS";
    } else {
      return "$minutes MINS";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the cached songs from the provider
    final playlistSongs = context.select<PlaylistProvider, List<Song>>(
      (provider) => provider.getPlaylistSongs(playlist.id),
    );

    final hasSongs = playlistSongs.isNotEmpty;
    final coverUrl = hasSongs ? playlistSongs.first.coverUrl : null;
    final songCount = playlist.songIds.length;
    final durationString = _formatDuration(playlistSongs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Album Art
        Center(
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha :0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              image: (coverUrl != null && coverUrl.isNotEmpty)
                  ? DecorationImage(
                image: NetworkImage(coverUrl),
                fit: BoxFit.cover,
              )
                  : null,
              color: Colors.grey[900],
            ),
            child: (coverUrl == null || coverUrl.isEmpty)
                ? const Icon(Icons.music_note, size: 80, color: Colors.grey)
                : null,
          ),
        ),

        const SizedBox(height: 32),

        // Playlist Title
        Text(
          playlist.title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 28,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 6),

        // Metadata Row
        Text(
          "PUBLIC • $songCount SONGS • $durationString",
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}