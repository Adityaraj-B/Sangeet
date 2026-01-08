import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/models/song.dart';
import 'components/player_top_bar.dart';
import 'components/album_art.dart';
import 'components/lyrics_view.dart';
import 'components/song_info.dart';
import 'components/progress_bar.dart';
import 'components/player_controls.dart';
import 'components/view_toggle.dart';
import 'components/player_actions.dart';

class PlayerScreen extends StatefulWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onCollapse;

  const PlayerScreen({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onCollapse,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _discAnim;
  bool _liked = false;
  bool _showLyrics = false;
  ColorScheme? _scheme;


  Future<void> _loadScheme() async {
    final scheme = await ColorScheme.fromImageProvider(
      provider: NetworkImage(widget.song.coverUrl),
      brightness: Brightness.dark,
    );

    if (mounted) {
      setState(() => _scheme = scheme);
    }
  }

  @override
  void initState() {
    super.initState();

    _discAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    if (widget.isPlaying) _discAnim.repeat();

    _loadScheme();
  }


  @override
  void didUpdateWidget(covariant PlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.isPlaying ? _discAnim.repeat() : _discAnim.stop();
  }

  @override
  void dispose() {
    _discAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 24;

    final scheme = _scheme;
    final accent = scheme?.primary ?? Colors.white;

    Color albumColor;
    if (scheme != null) {
      final hsl = HSLColor.fromColor(scheme.primary);
      albumColor = hsl
          .withLightness(0.48)
          .withSaturation(0.8)
          .toColor();
    } else {
      albumColor = kBackgroundColor;
    }

    return Scaffold(
      body: Stack(
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

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.transparent,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
            child: Container(
              color: Colors.black.withOpacity(0.08),
            ),
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
                  ),
                  const SizedBox(height: 24),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _showLyrics
                        ? LyricsView()
                        : AlbumArt(
                      coverUrl: widget.song.coverUrl,
                      rotation: _discAnim,
                    ),
                  ),

                  const SizedBox(height: 26),
                  SongInfo(song: widget.song),
                  const SizedBox(height: 16),

                  ProgressBar(accentColor: accent),
                  const SizedBox(height: 20),

                  PlayerControls(
                    isPlaying: widget.isPlaying,
                    onPlayPause: widget.onPlayPause,
                    accentColor: accent,
                  ),
                  const SizedBox(height: 24),

                  ViewToggle(
                    showLyrics: _showLyrics,
                    onToggle: (v) => setState(() => _showLyrics = v),
                  ),
                  const SizedBox(height: 30),

                  PlayerActions(accentColor: accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}