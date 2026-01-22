import 'package:flutter/material.dart';
import '../playlists/playlists_screen.dart';
import '../../../models/song.dart';

class LibraryFilters extends StatelessWidget {
  final ValueChanged<Song> onPlaySong;

  const LibraryFilters({super.key, required this.onPlaySong});

  @override
  Widget build(BuildContext context) {
    final filters = ["Playlists", "Podcasts", "Songs", "Artists", "Albums"];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = filters[index];

          return GestureDetector(
            onTap: () {
              if (label == "Playlists") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PlaylistsScreen(onPlaySong: onPlaySong),
                  ),
                );
              }
            },
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
