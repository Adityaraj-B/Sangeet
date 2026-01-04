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

  const PlayerScreen({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.onPlayPause,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _discAnim;
  bool _liked = false;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _discAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    if (widget.isPlaying) _discAnim.repeat();
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

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
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

              /*AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _showLyrics
                    ? LyricsView(lyrics: widget.song.lyrics)
                    : AlbumArt(
                  coverUrl: widget.song.coverUrl,
                  rotation: _discAnim,
                ),
              ),*/

              const SizedBox(height: 24),
              SongInfo(song: widget.song),
              const SizedBox(height: 16),

              const ProgressBar(),
              const SizedBox(height: 18),

              PlayerControls(
                isPlaying: widget.isPlaying,
                onPlayPause: widget.onPlayPause,
              ),
              const SizedBox(height: 22),

              ViewToggle(
                showLyrics: _showLyrics,
                onToggle: (v) => setState(() => _showLyrics = v),
              ),
              const SizedBox(height: 18),

              const PlayerActions(),
            ],
          ),
        ),
      ),
    );
  }
}
