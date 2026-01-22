import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/screens/playlist/components/playlist_edit.dart';
import '../../../models/playlist.dart';
import '../../../models/song.dart';
import '../../../services/playlist_provider.dart';

class PlaylistActions extends StatelessWidget {
  final Playlist playlist;

  const PlaylistActions({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final primaryActionColor = kAccentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // EDIT BUTTON
                // Inside PlaylistActions...

                _ActionIcon(
                    icon: Icons.edit_outlined,
                    onTap: () async {
                      // 1. Wait for result (Map<String, dynamic>)
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaylistEditScreen(playlist: playlist),
                        ),
                      );

                      // 2. Check if result is valid
                      if (result != null && result is Map && context.mounted) {
                        final newTitle = result['title'] as String;
                        final newSongs = result['songs'] as List<Song>;

                        // 3. Update via Provider
                        // We create a new copy of the playlist with BOTH title and songs updated
                        final updatedPlaylist = playlist.copyWith(
                          title: newTitle,
                          songs: newSongs,
                          updatedAt: DateTime.now(),
                        );

                        await context.read<PlaylistProvider>().updatePlaylist(updatedPlaylist);
                      }
                    }
                ),
                const SizedBox(width: 8),
                _ActionIcon(icon: Icons.download_outlined, onTap: () {}),
                const SizedBox(width: 8),
                _ActionIcon(icon: Icons.share_outlined, onTap: () {}),
                const SizedBox(width: 8),

                // MORE MENU (Delete/Hide)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: Colors.grey[400], size: 26),
                  color: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      // Navigate back first to avoid staying on loading screen
                      if (context.mounted) Navigator.pop(context); // Close screen first
                      // Then delete the playlist
                      await context.read<PlaylistProvider>().deletePlaylist(playlist.id);
                    } else if (value == 'hide') {
                      // Implement hide logic if your model supports it
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Playlist Hidden")),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'hide',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off_outlined, color: Colors.white70),
                          SizedBox(width: 12),
                          Text('Hide Playlist', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent),
                          SizedBox(width: 12),
                          Text('Delete Playlist', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // PLAY BUTTON
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.shuffle),
                  color: Colors.white,
                  iconSize: 28,
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: () {},
                  backgroundColor: primaryActionColor,
                  elevation: 0,
                  mini: false,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ADD SONGS BUTTON
        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: primaryActionColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  "Add Songs",
                  style: TextStyle(
                    color: primaryActionColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, color: Colors.grey[400], size: 26),
      ),
    );
  }
}