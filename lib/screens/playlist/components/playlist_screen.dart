import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/components/bottom_player_container.dart';
import '../../../models/song.dart';
import '../../../services/playlist_provider.dart';
import '../../playlist/playlist_body.dart';

class PlaylistsScreen extends StatelessWidget {
  final ValueChanged<Song> onPlaySong;

  const PlaylistsScreen({super.key, required this.onPlaySong});

  Future<void> _createPlaylist(BuildContext context) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _CreatePlaylistDialog(controller: controller),
    );

    if (name != null && name.isNotEmpty && context.mounted) {
      context.read<PlaylistProvider>().createPlaylist(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Consumer<PlaylistProvider>(
              builder: (context, provider, _) {
                final playlists = provider.playlists;

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      centerTitle: true,
                      backgroundColor: kBackgroundColor,
                      elevation: 0,
                      title: const Text(
                        'Your Playlists',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _createPlaylist(context),
                        ),
                      ],
                    ),

                    if (playlists.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(
                          onCreate: () => _createPlaylist(context),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 100),
                        sliver: SliverGrid(
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final playlist = playlists[index];
                              return _PlaylistGridCard(
                                playlist: playlist,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlaylistBody(
                                        playlist: playlist,
                                        onPlaySong: onPlaySong,
                                      ),
                                    ),
                                  );
                                },
                                onLongPress: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => _PlaylistOptionsSheet(
                                      playlist: playlist,
                                    ),
                                  );
                                },
                              );
                            },
                            childCount: playlists.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // Bottom player container
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: BottomPlayerContainer(
                backgroundColor: kBackgroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistGridCard extends StatelessWidget {
  final dynamic playlist;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PlaylistGridCard({
    required this.playlist,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasSongs = playlist.songIds.isNotEmpty;
    final coverUrl =
    hasSongs && playlist.songs.isNotEmpty ? playlist.songs.first.coverUrl : null;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: coverUrl == null || coverUrl.isEmpty
                  ? LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.05),
                ],
              )
                  : null,
              image: coverUrl != null && coverUrl.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(coverUrl),
                fit: BoxFit.cover,
              )
                  : null,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.6,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  playlist.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${playlist.songIds.length} songs',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
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

class _PlaylistOptionsSheet extends StatelessWidget {
  final dynamic playlist;

  const _PlaylistOptionsSheet({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: playlist.title);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Rename',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final name = await showDialog<String>(
                    context: context,
                    builder: (_) =>
                        _CreatePlaylistDialog(controller: controller),
                  );
                  if (name != null && name.isNotEmpty && context.mounted) {
                    context
                        .read<PlaylistProvider>()
                        .renamePlaylist(playlist.id, name);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Delete',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  context
                      .read<PlaylistProvider>()
                      .deletePlaylist(playlist.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_music,
              size: 80, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text(
            'No playlists yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Create playlists and add songs',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: onCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Create Playlist'),
          ),
        ],
      ),
    );
  }
}

class _CreatePlaylistDialog extends StatelessWidget {
  final TextEditingController controller;

  const _CreatePlaylistDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.6,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Playlist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Playlist name',
                    hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
