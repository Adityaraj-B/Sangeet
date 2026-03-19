import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/components/bottom_player_container.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../services/playlist_provider.dart';
import 'components/actions.dart';
import 'components/header.dart';
import 'components/songs.dart';

class PlaylistBody extends StatelessWidget {
  final Playlist playlist;
  final ValueChanged<Song> onPlaySong;

  const PlaylistBody({
    super.key,
    required this.playlist,
    required this.onPlaySong,
  });

  @override
  Widget build(BuildContext context) {
    final currentPlaylist = context.select<PlaylistProvider, Playlist?>(
          (provider) => provider.getPlaylistById(playlist.id),
    );

    final playlistSongs = context.select<PlaylistProvider, List<Song>>(
          (provider) => provider.getPlaylistSongs(playlist.id),
    );

    if (currentPlaylist == null) {
      return const Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    final coverUrl = playlistSongs.isNotEmpty ? playlistSongs.first.coverUrl : '';

    if (isDesktop) {
      return _DesktopPlaylistLayout(
        playlist: currentPlaylist,
        playlistSongs: playlistSongs,
        coverUrl: coverUrl,
        onPlaySong: onPlaySong,
      );
    }

    // ── Mobile layout (unchanged) ──────────────────────────────────────────
    return Scaffold(
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          if (coverUrl.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(coverUrl),
                      fit: BoxFit.cover,
                      opacity: 0.6,
                    ),
                  ),
                ),
              ),
            ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    kBackgroundColor.withValues(alpha: 0.95),
                    kBackgroundColor,
                  ],
                  stops: const [0.1, 0.55, 1.0],
                ),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                floating: true,
                snap: true,
                pinned: false,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlaylistHeader(playlist: currentPlaylist),
                      const SizedBox(height: 12),
                      PlaylistActions(playlist: currentPlaylist),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              PlaylistSongs(
                songs: playlistSongs,
                onPlaySong: onPlaySong,
                playlistId: currentPlaylist.id,
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 5,
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

// ── Desktop two-column layout ────────────────────────────────────────────────

class _DesktopPlaylistLayout extends StatelessWidget {
  final Playlist playlist;
  final List<Song> playlistSongs;
  final String coverUrl;
  final ValueChanged<Song> onPlaySong;

  const _DesktopPlaylistLayout({
    required this.playlist,
    required this.playlistSongs,
    required this.coverUrl,
    required this.onPlaySong,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          // Blurred background
          if (coverUrl.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(coverUrl),
                      fit: BoxFit.cover,
                      opacity: 0.25,
                    ),
                  ),
                ),
              ),
            ),

          // Dark overlay
          Positioned.fill(
            child: Container(
              color: kBackgroundColor.withValues(alpha: 0.75),
            ),
          ),

          // Main content
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left panel: fixed sidebar with art + info + controls ──────
              SizedBox(
                width: 320,
                child: _DesktopLeftPanel(
                  playlist: playlist,
                  playlistSongs: playlistSongs,
                  coverUrl: coverUrl,
                ),
              ),

              // Divider
              Container(
                width: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),

              // ── Right panel: scrollable song list ────────────────────────
              Expanded(
                child: Column(
                  children: [
                    // Top bar with back button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              playlist.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.filter_list,
                                color: Colors.white54, size: 20),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),

                    // Song list
                    Expanded(
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          PlaylistSongs(
                            songs: playlistSongs,
                            onPlaySong: onPlaySong,
                            playlistId: playlist.id,
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 100)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Bottom player
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomPlayerContainer(
              backgroundColor: kBackgroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopLeftPanel extends StatelessWidget {
  final Playlist playlist;
  final List<Song> playlistSongs;
  final String coverUrl;

  const _DesktopLeftPanel({
    required this.playlist,
    required this.playlistSongs,
    required this.coverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final totalSeconds = playlistSongs.fold<int>(
      0,
          (sum, s) => sum + (s.duration?.inSeconds ?? 0),
    );
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final durationText = hours > 0
        ? '$hours hr ${minutes} min'
        : '$minutes min';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album art
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: coverUrl.isNotEmpty
                ? Image.network(
              coverUrl,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            )
                : Container(
              width: double.infinity,
              height: 220,
              color: Colors.white.withValues(alpha: 0.08),
              child: const Icon(
                Icons.music_note,
                color: Colors.white24,
                size: 64,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            playlist.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          // Meta
          Text(
            '${playlistSongs.length} songs • $durationText',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 24),

          // Actions (play, shuffle, edit, etc.)
          PlaylistActions(playlist: playlist),

          const Spacer(),
        ],
      ),
    );
  }
}