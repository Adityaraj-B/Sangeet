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
    // Watch for updates
    final currentPlaylist = context.select<PlaylistProvider, Playlist?>(
          (provider) => provider.getPlaylistById(playlist.id),
    );

    // Get the cached songs from the provider
    final playlistSongs = context.select<PlaylistProvider, List<Song>>(
          (provider) => provider.getPlaylistSongs(playlist.id),
    );

    if (currentPlaylist == null) {
      return const Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final coverUrl = playlistSongs.isNotEmpty
        ? playlistSongs.first.coverUrl
        : '';

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

          // Bottom player container
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