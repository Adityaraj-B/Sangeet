import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/services/audio_player_service.dart';
import '../../services/like_service.dart';

import 'components/player_top_bar.dart';
import 'components/album_art.dart';
import 'components/lyrics_view.dart';
import 'components/song_info.dart';
import 'components/progress_bar.dart';
import 'components/player_controls.dart';
import 'components/view_toggle.dart';
import 'components/player_actions.dart';
import 'components/artist_view.dart';

class PlayerScreen extends StatefulWidget {
  final VoidCallback onCollapse;

  const PlayerScreen({
    super.key,
    required this.onCollapse,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayerService _audioService = AudioPlayerService();

  late final AnimationController _discAnim;
  PlayerViewMode _viewMode = PlayerViewMode.song;
  StreamSubscription<bool>? _playingSub;

  Song? get _currentSong => _audioService.currentSong;

  @override
  void initState() {
    super.initState();

    _discAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    _playingSub = _audioService.playingStream.listen((playing) {
      if (!mounted) return;
      playing ? _discAnim.repeat() : _discAnim.stop();
    });

    // Start animation if already playing
    if (_audioService.isPlaying) {
      _discAnim.repeat();
    }
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _discAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final likeService = context.watch<LikeService>();

    // Rebuild when queue/currentSong changes.
    return AnimatedBuilder(
      animation: _audioService.queue,
      builder: (context, _) {
        final song = _currentSong;
        if (song == null) {
          // No song playing, show empty state
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 64, color: Colors.white38),
                  const SizedBox(height: 16),
                  Text(
                    'No song playing',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: widget.onCollapse,
                    child: Text('Go Back', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }

        final isLiked = likeService.isLiked(song);
        final bottomInset = MediaQuery.of(context).padding.bottom + 24;

        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 600) {
                widget.onCollapse();
              }
            },
            child: Stack(
              children: [
                // Background blur
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  child: SizedBox.expand(
                    key: ValueKey(song.id),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                      child: Image.network(
                        song.coverUrl,
                        fit: BoxFit.cover,
                        colorBlendMode: BlendMode.darken,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),

                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
                    child: Column(
                      children: [
                        PlayerTopBar(
                          liked: isLiked,
                          onLikeToggle: () =>
                              context.read<LikeService>().toggleLike(song),
                          onCollapse: widget.onCollapse,
                        ),

                        const Spacer(),

                        Expanded(
                          flex: 5,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: _viewMode == PlayerViewMode.lyrics
                                ? LyricsView(
                                    artist: song.artist,
                                    track: song.title,
                                    positionStream: _audioService.positionStream,
                                  )
                                : _viewMode == PlayerViewMode.artist
                                    ? ArtistView(
                                        key: const ValueKey('artist_view'),
                                        song: song,
                                        onPlaySong: (s) {
                                          _audioService.playSong(s);
                                        },
                                      )
                                    : AlbumArt(
                                        key: ValueKey(song.id),
                                        coverUrl: song.coverUrl,
                                        rotation: _discAnim,
                                      ),
                          ),
                        ),

                        const Spacer(),

                        SongInfo(song: song),
                        const SizedBox(height: 16),

                        ViewToggle(
                          viewMode: _viewMode,
                          onToggle: (v) => setState(() => _viewMode = v),
                        ),

                        const SizedBox(height: 24),

                        ProgressBar(
                          positionStream: _audioService.positionStream,
                          durationStream: _audioService.durationStream,
                          accentColor: Colors.white,
                          onSeek: _audioService.seek,
                        ),

                        const SizedBox(height: 20),

                        StreamBuilder<bool>(
                          stream: _audioService.playingStream,
                          initialData: _audioService.isPlaying,
                          builder: (context, snapshot) {
                            return PlayerControls(
                              isPlaying: snapshot.data ?? false,
                              onPlayPause: _audioService.togglePlayPause,
                              onNext: _audioService.playNext,
                              onPrevious: _audioService.playPrevious,
                              accentColor: Colors.white,
                            );
                          },
                        ),

                        const SizedBox(height: 30),

                        PlayerActions(
                          accentColor: Colors.white,
                          currentSong: song,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
