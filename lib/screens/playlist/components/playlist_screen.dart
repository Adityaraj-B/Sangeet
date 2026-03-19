import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/components/bottom_player_container.dart';
import '../../../models/song.dart';
import '../../../services/playlist_provider.dart';
import '../../playlist/playlist_body.dart';
import '../../spotify_import_screen.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    if (isDesktop) {
      return _DesktopPlaylistsLayout(
        onPlaySong: onPlaySong,
        onCreatePlaylist: _createPlaylist,
      );
    }

    // ── Mobile layout (unchanged) ────────────────────────────────────────
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
                          icon: const Icon(Icons.download_rounded, size: 22),
                          tooltip: 'Import from Spotify',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SpotifyImportScreen(),
                              ),
                            );
                          },
                        ),
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
                        padding: const EdgeInsets.only(
                            left: 14, right: 14, top: 14, bottom: 100),
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

// ── Desktop layout ────────────────────────────────────────────────────────────

class _DesktopPlaylistsLayout extends StatelessWidget {
  final ValueChanged<Song> onPlaySong;
  final Future<void> Function(BuildContext) onCreatePlaylist;

  const _DesktopPlaylistsLayout({
    required this.onPlaySong,
    required this.onCreatePlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          Consumer<PlaylistProvider>(
            builder: (context, provider, _) {
              final playlists = provider.playlists;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Top bar ──────────────────────────────────────────
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: kBackgroundColor,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: const Text(
                      'Your Playlists',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    actions: [
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SpotifyImportScreen()),
                        ),
                        icon: const Icon(Icons.download_rounded,
                            size: 16, color: Color(0xFF1DB954)),
                        label: const Text(
                          'Import from Spotify',
                          style: TextStyle(
                              color: Color(0xFF1DB954), fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => onCreatePlaylist(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New Playlist',
                            style: TextStyle(fontSize: 13)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),

                  if (playlists.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                          onCreate: () => onCreatePlaylist(context)),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 120),
                      sliver: SliverGrid(
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          // 4 columns on desktop — refined, dense, not giant
                          crossAxisCount: 4,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.88,
                        ),
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final playlist = playlists[index];
                            return _DesktopPlaylistCard(
                              playlist: playlist,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaylistBody(
                                    playlist: playlist,
                                    onPlaySong: onPlaySong,
                                  ),
                                ),
                              ),
                              onDelete: () => context
                                  .read<PlaylistProvider>()
                                  .deletePlaylist(playlist.id),
                              onRename: () async {
                                final ctrl = TextEditingController(
                                    text: playlist.title);
                                final name = await showDialog<String>(
                                  context: context,
                                  builder: (_) =>
                                      _CreatePlaylistDialog(controller: ctrl),
                                );
                                if (name != null &&
                                    name.isNotEmpty &&
                                    context.mounted) {
                                  context
                                      .read<PlaylistProvider>()
                                      .renamePlaylist(playlist.id, name);
                                }
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

          // Bottom player
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomPlayerContainer(backgroundColor: kBackgroundColor),
          ),
        ],
      ),
    );
  }
}

// ── Desktop playlist card ─────────────────────────────────────────────────────

class _DesktopPlaylistCard extends StatefulWidget {
  final dynamic playlist;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _DesktopPlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  State<_DesktopPlaylistCard> createState() => _DesktopPlaylistCardState();
}

class _DesktopPlaylistCardState extends State<_DesktopPlaylistCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hasSongs = widget.playlist.songIds.isNotEmpty;
    final coverUrl = hasSongs && widget.playlist.songs.isNotEmpty
        ? widget.playlist.songs.first.coverUrl
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _hovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: Colors.white
                  .withValues(alpha: _hovered ? 0.14 : 0.07),
              width: 0.6,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover art
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (coverUrl != null && coverUrl.isNotEmpty)
                        Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      else
                        _placeholder(),

                      // Hover overlay with actions
                      AnimatedOpacity(
                        opacity: _hovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Play button
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Context menu button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: AnimatedOpacity(
                          opacity: _hovered ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: PopupMenuButton<String>(
                            icon: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                Colors.black.withValues(alpha: 0.6),
                              ),
                              child: const Icon(Icons.more_vert,
                                  color: Colors.white, size: 16),
                            ),
                            color: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) {
                              if (value == 'rename') widget.onRename();
                              if (value == 'delete') widget.onDelete();
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Row(children: [
                                  Icon(Icons.edit_outlined,
                                      color: Colors.white70, size: 16),
                                  SizedBox(width: 10),
                                  Text('Rename',
                                      style:
                                      TextStyle(color: Colors.white)),
                                ]),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 16),
                                  SizedBox(width: 10),
                                  Text('Delete',
                                      style: TextStyle(
                                          color: Colors.redAccent)),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Info
              Padding(
                padding:
                const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${widget.playlist.songIds.length} songs',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A2A), Color(0xFF181818)],
        ),
      ),
      child: Center(
        child: Icon(Icons.library_music_rounded,
            color: Colors.white.withValues(alpha: 0.15), size: 36),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

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
    hasSongs && playlist.songs.isNotEmpty
        ? playlist.songs.first.coverUrl
        : null;

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
                leading:
                const Icon(Icons.delete, color: Colors.redAccent),
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
            'Create playlists or import from Spotify',
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
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SpotifyImportScreen(),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Import from Spotify'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1DB954),
              side: BorderSide(
                color: const Color(0xFF1DB954).withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
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
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5)),
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