import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/models/album.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/services/remote_music_service.dart';

import '../../components/Song_options.dart';
import '../../services/audio_player_service.dart';
import '../../services/queue.dart';

class AlbumScreen extends StatefulWidget {
  final Album album;
  final RemoteMusicService musicService;
  final void Function(Song) onPlaySong;

  const AlbumScreen({
    super.key,
    required this.album,
    required this.musicService,
    required this.onPlaySong,
  });

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  List<Song> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSongs();
  }

  void _playAll() {
    if (_songs.isEmpty) return;
    final audio = AudioPlayerService();

    // IMPORTANT: Clear queue and add remaining songs BEFORE playing
    audio.queue.clearQueue();
    if (_songs.length > 1) {
      audio.queue.addAllToQueue(_songs.sublist(1));
    }

    // Now play the first song
    widget.onPlaySong(_songs.first);
  }

  void _handleSongTap(Song song) {
    // Find the index of the tapped song
    final songIndex = _songs.indexWhere((s) => s.id == song.id);

    final queueService = QueueService();

    // Clear existing queue to avoid mixing old songs with album songs
    queueService.clearQueue();

    // Add remaining album songs to queue BEFORE playing
    // This ensures playSong() sees the manual queue and won't load similar songs
    if (songIndex >= 0 && songIndex < _songs.length - 1) {
      final remainingSongs = _songs.sublist(songIndex + 1);
      queueService.addAllToQueue(remainingSongs);
    }

    // Now play the tapped song
    widget.onPlaySong(song);
  }

  Future<void> _fetchSongs() async {
    final songs = await widget.musicService.getAlbumSongs(widget.album.id);
    if (mounted) {
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: kPrimaryColor),
              ),
            )
          else if (_songs.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  "No songs found",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: 120,
                left: MediaQuery.of(context).size.width > 800 ? 28 : 0,
                right: MediaQuery.of(context).size.width > 800 ? 28 : 0,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    return _SongTile(
                      song: _songs[index],
                      index: index,
                      onTap: () => _handleSongTap(_songs[index]),
                      onPlaySong: _handleSongTap,
                    );
                      },
                  childCount: _songs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 400, // Slightly taller for better spacing
      backgroundColor: kBackgroundColor,
      pinned: true,
      stretch: true,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background Image with BLUR
            if (widget.album.coverUrl.isNotEmpty)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), // Subtle Blur
                child: Image.network(
                  widget.album.coverUrl,
                  fit: BoxFit.cover,
                  // Darken purely for contrast before the gradient
                  color: Colors.black.withValues(alpha: 0.4),
                  colorBlendMode: BlendMode.darken,
                  errorBuilder: (_, __, ___) => Container(color: kBackgroundColor),
                ),
              ),

            // 2. Gradient Overlay (Fade to kBackgroundColor)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    kBackgroundColor.withValues(alpha: 0.4),
                    kBackgroundColor.withValues(alpha: 0.9),
                    kBackgroundColor,
                  ],
                  stops: const [0.0, 0.4, 0.85, 1.0],
                ),
              ),
            ),

            // 3. Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Album Art Card (Sharp, no blur on this one)
                  Hero(
                    tag: 'album_${widget.album.id}',
                    child: Container(
                      height: 180,
                      width: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          widget.album.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.album, size: 60, color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    widget.album.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Artist & Year
                  Text(
                    "Album • ${widget.album.artist} • ${widget.album.year}",
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Liquid Glass Play Button
                  if (!_isLoading && _songs.isNotEmpty)
                    _LiquidGlassButton(
                      onTap: _playAll,
                      label: "Play All",
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidGlassButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _LiquidGlassButton({
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        children: [
          // 🔹 Frosted glass blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 180,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),

          // 🔹 MAIN LIQUID GRADIENT (FIXED)
          Container(
            width: 180,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.35), // top shine
                  Colors.white.withValues(alpha: 0.12), // center clarity
                  Colors.black.withValues(alpha: 0.15), // bottom depth
                ],
              ),
            ),
          ),

          // 🔹 Specular highlight strip (key difference)
          Positioned(
            top: 6,
            left: 14,
            right: 14,
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 🔹 Content
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.white.withValues(alpha: 0.25),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              child: SizedBox(
                width: 180,
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final void Function(Song) onPlaySong;

  const _SongTile({
    required this.song,
    required this.index,
    required this.onTap,
    required this.onPlaySong,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: kPrimaryColor.withValues(alpha: 0.1),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  "${index + 1}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 20,
                ),
                onPressed: () {
                  SongOptionsSheet.show(
                    context,
                    song,
                    onPlay: () => onPlaySong(song),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

