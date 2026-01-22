import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../models/song.dart';
import '../../../services/playlist_provider.dart';


class AddToPlaylistDialog extends StatefulWidget {
  final Song song;

  const AddToPlaylistDialog({
    super.key,
    required this.song,
  });

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  final TextEditingController _newPlaylistController = TextEditingController();
  bool _creatingNew = false;

  @override
  void dispose() {
    _newPlaylistController.dispose();
    super.dispose();
  }

  Future<void> _createAndAddToPlaylist(PlaylistProvider provider) async {
    final name = _newPlaylistController.text.trim();
    if (name.isEmpty) return;

    final playlist = await provider.createPlaylist(name);
    if (playlist != null) {
      await provider.addSongToPlaylist(playlist.id, widget.song);
      if (mounted) {
        Navigator.pop(context);
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(milliseconds: 2200),
            content: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha :0.18),
                        Colors.white.withValues(alpha :0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha :0.25),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.white.withValues(alpha :0.9),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Added to "$name"',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha :0.14),
                  Colors.white.withValues(alpha :0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha :0.18),
                width: 0.6,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add to Playlist',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.song.title,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha :0.6),
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: Colors.white.withValues(alpha :0.12)),

                // Playlist list
                Flexible(
                  child: Consumer<PlaylistProvider>(
                    builder: (context, provider, _) {
                      if (provider.playlists.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Text(
                              'No playlists yet.\nCreate one below!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha :0.5),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: provider.playlists.length,
                        itemBuilder: (context, index) {
                          final playlist = provider.playlists[index];
                          final isAdded = provider.isSongInPlaylist(
                            playlist.id,
                            widget.song.id,
                          );

                          final hasSongs = playlist.songIds.isNotEmpty;
                          final coverUrl = hasSongs && playlist.songs.isNotEmpty
                              ? playlist.songs.first.coverUrl
                              : null;

                          return ListTile(
                            onTap: isAdded
                                ? null
                                : () async {
                              final success =
                              await provider.addSongToPlaylist(
                                playlist.id,
                                widget.song,
                              );
                              if (mounted && success) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(16),
                                    content: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white.withValues(alpha :0.18),
                                                Colors.white.withValues(alpha :0.08),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha :0.25),
                                              width: 0.6,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.white.withValues(alpha :0.9),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'Added to "${playlist.title}"',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );

                              }
                            },
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: coverUrl == null
                                      ? LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha :0.14),
                                      Colors.white.withValues(alpha :0.05),
                                    ],
                                  )
                                      : null,
                                  image: coverUrl != null
                                      ? DecorationImage(
                                    image: NetworkImage(coverUrl),
                                    fit: BoxFit.cover,
                                  )
                                      : null,
                                ),
                                child: coverUrl == null
                                    ? const Icon(
                                  Icons.queue_music,
                                  color: Colors.white70,
                                )
                                    : null,
                              ),
                            ),
                            title: Text(
                              playlist.title,
                              style: TextStyle(
                                color: isAdded
                                    ? Colors.white.withValues(alpha :0.5)
                                    : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${playlist.songIds.length} songs',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha :0.5),
                                fontSize: 12,
                              ),
                            ),
                            trailing: isAdded
                                ? Icon(
                              Icons.check_circle,
                              color: Colors.white.withValues(alpha :0.9),
                            )
                                : const Icon(
                              Icons.check,
                              color: Colors.white,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                Divider(height: 1, color: Colors.white.withValues(alpha :0.12)),

                // Create new playlist section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _creatingNew
                      ? Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newPlaylistController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Playlist name',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha :0.5),
                            ),
                            filled: true,
                            fillColor:
                            Colors.white.withValues(alpha :0.08),
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check,
                            color: Colors.green),
                        onPressed: () =>
                            _createAndAddToPlaylist(
                              context.read<PlaylistProvider>(),
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white70),
                        onPressed: () =>
                            setState(() => _creatingNew = false),
                      ),
                    ],
                  )
                      : ElevatedButton.icon(
                    onPressed: () =>
                        setState(() => _creatingNew = true),
                    icon: const Icon(Icons.add),
                    label: const Text('Create New Playlist'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }
}