import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/screens/playlist/components/playlist_edit.dart';
import 'package:sangeet/screens/playlist/components/add_songs_dialog.dart';
import 'package:sangeet/screens/body.dart';
import '../../../models/playlist.dart';
import '../../../models/song.dart';
import '../../../services/playlist_provider.dart';
import '../../../services/audio_player_service.dart';
import '../../../services/queue.dart';
import '../../../services/like_service.dart';
import 'dart:math';

class PlaylistActions extends StatelessWidget {
  final Playlist playlist;

  const PlaylistActions({super.key, required this.playlist});

  Future<void> _shufflePlaylist(BuildContext context) async {
    final playlistSongs =
    context.read<PlaylistProvider>().getPlaylistSongs(playlist.id);

    if (playlistSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs to shuffle')),
      );
      return;
    }

    final audioService = AudioPlayerService();
    final queueService = QueueService();

    final shuffledSongs = List<Song>.from(playlistSongs)..shuffle(Random());

    // Clear any existing queue (auto-suggestions from a previous session)
    // so the shuffled playlist plays in full without interference.
    queueService.clearQueue();

    if (shuffledSongs.length > 1) {
      queueService.addAllToQueue(shuffledSongs.sublist(1));
    }

    await audioService.playSong(shuffledSongs.first);

    BodyState.instance?.openPlayerForCurrentSong();
  }

  Future<void> _playAllSongs(BuildContext context) async {
    final playlistSongs =
    context.read<PlaylistProvider>().getPlaylistSongs(playlist.id);

    if (playlistSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs to play')),
      );
      return;
    }

    final audioService = AudioPlayerService();
    final queueService = QueueService();

    // Clear any existing queue (auto-suggestions from a previous session)
    // so the playlist plays in full order without old songs in front.
    queueService.clearQueue();

    if (playlistSongs.length > 1) {
      queueService.addAllToQueue(playlistSongs.sublist(1));
    }

    await audioService.playSong(playlistSongs.first);

    BodyState.instance?.openPlayerForCurrentSong();
  }

  Future<void> _showAddSongsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (dialogContext) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(
            value: context.read<PlaylistProvider>(),
          ),
          ChangeNotifierProvider.value(
            value: context.read<LikeService>(),
          ),
        ],
        child: AddSongsDialog(playlist: playlist),
      ),
    );
  }

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
                _ActionIcon(
                  icon: Icons.edit_outlined,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PlaylistEditScreen(playlist: playlist),
                      ),
                    );

                    if (result != null && result is Map && context.mounted) {
                      final newTitle = result['title'] as String;
                      final newSongs = result['songs'] as List<Song>;

                      final updatedPlaylist = playlist.copyWith(
                        title: newTitle,
                        songs: newSongs,
                        updatedAt: DateTime.now(),
                      );

                      await context
                          .read<PlaylistProvider>()
                          .updatePlaylist(updatedPlaylist);
                    }
                  },
                ),
                const SizedBox(width: 8),

                // MORE MENU
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz,
                      color: Colors.grey[400], size: 26),
                  color: const Color(0xFF1E1E1E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) async {
                    if (value == 'delete') {
                      if (context.mounted) Navigator.pop(context);
                      await context
                          .read<PlaylistProvider>()
                          .deletePlaylist(playlist.id);
                    } else if (value == 'hide') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Playlist Hidden")),
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'hide',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off_outlined,
                              color: Colors.white70),
                          SizedBox(width: 12),
                          Text('Hide Playlist',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          SizedBox(width: 12),
                          Text('Delete Playlist',
                              style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // PLAY AND SHUFFLE BUTTONS
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.shuffle),
                  color: Colors.white,
                  iconSize: 28,
                  onPressed: () => _shufflePlaylist(context),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: () => _playAllSongs(context),
                  backgroundColor: primaryActionColor,
                  elevation: 0,
                  mini: false,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.black, size: 32),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ADD SONGS BUTTON
        InkWell(
          onTap: () => _showAddSongsDialog(context),
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