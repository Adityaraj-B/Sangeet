import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/components/playable.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/models/podcasts.dart';
import 'package:sangeet/services/audio_player_service.dart';

import 'components/player_top_bar.dart';
import 'components/album_art.dart';
import 'components/lyrics_view.dart';
import 'components/song_info.dart';
import 'components/progress_bar.dart';
import 'components/player_controls.dart';
import 'components/view_toggle.dart';
import 'components/player_actions.dart';

class PlayerScreen extends StatefulWidget {
  final PlaybackItem item;
  final VoidCallback onCollapse;

  const PlayerScreen({
    super.key,
    required this.item,
    required this.onCollapse,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayerService _audioService = AudioPlayerService();

  late final AnimationController _discAnim;
  bool _liked = false;
  bool _showLyrics = false;
  ColorScheme? _scheme;

  bool get _isPodcast => widget.item.type == PlaybackType.podcast;

  String get _imageUrl => _isPodcast
      ? (widget.item.data as Podcast).imageUrl
      : (widget.item.data as Song).coverUrl;

  Future<void> _loadScheme() async {
    final scheme = await ColorScheme.fromImageProvider(
      provider: NetworkImage(_imageUrl),
      brightness: Brightness.dark,
    );

    if (mounted) setState(() => _scheme = scheme);
  }

  @override
  void initState() {
    super.initState();

    _discAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    if (!_isPodcast) {
      final song = widget.item.data as Song;
      final current = _audioService.currentSong;

      // 🔒 Only play if it's a NEW song
      if (current == null || current.id != song.id) {
        _audioService.playSong(song);
      }

      _audioService.playingStream.listen((playing) {
        if (!mounted) return;
        playing ? _discAnim.repeat() : _discAnim.stop();
      });
    }
    _loadScheme();
  }

  @override
  void dispose() {
    _discAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 24;
    final accent = _scheme?.primary ?? Colors.white;
    final albumColor = _scheme != null
        ? HSLColor.fromColor(_scheme!.primary)
        .withLightness(0.48)
        .withSaturation(0.8)
        .toColor()
        : kBackgroundColor;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity > 600) {
            widget.onCollapse();
          }
        },
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.65),
                  radius: 1.25,
                  colors: [
                    albumColor.withOpacity(0.9),
                    albumColor.withOpacity(0.45),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),

            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
              child: Container(color: Colors.black.withOpacity(0.08)),
            ),

            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
                child: Column(
                  children: [
                    PlayerTopBar(
                      liked: _liked,
                      onLikeToggle: () => setState(() => _liked = !_liked),
                      onCollapse: () {
                        widget.onCollapse();
                        //Navigator.pop(context, true);
                      },
                    ),
                    const SizedBox(height: 24),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _isPodcast
                          ? AlbumArt(
                        coverUrl: _imageUrl,
                        rotation: const AlwaysStoppedAnimation(0),
                      )
                          : (_showLyrics
                          ? LyricsView()
                          : AlbumArt(
                        coverUrl: _imageUrl,
                        rotation: _discAnim,
                      )),
                    ),

                    const SizedBox(height: 26),

                    _isPodcast
                        ? Text(
                      (widget.item.data as Podcast).title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    )
                        : SongInfo(song: widget.item.data as Song),

                    const SizedBox(height: 16),

                    ProgressBar(
                      positionStream: _audioService.positionStream,
                      durationStream: _audioService.durationStream,
                      accentColor: accent,
                      onSeek: (d) => _audioService.seek(d),
                    ),

                    const SizedBox(height: 20),

                    StreamBuilder<bool>(
                      stream: _audioService.playingStream,
                      initialData: _audioService.isPlaying,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;

                        return PlayerControls(
                          isPlaying: isPlaying,
                          onPlayPause: () {
                            _audioService.togglePlayPause();
                          },
                          onNext: () {
                            _audioService.playNext();
                          },
                          onPrevious: () {
                            _audioService.playPrevious();
                          },
                          accentColor: accent,
                          isPodcast: _isPodcast,
                        );
                      },
                    ),

                    if (!_isPodcast) ...[
                      const SizedBox(height: 24),
                      ViewToggle(
                        showLyrics: _showLyrics,
                        onToggle: (v) => setState(() => _showLyrics = v),
                      ),
                    ],

                    const SizedBox(height: 30),
                    PlayerActions(accentColor: accent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
