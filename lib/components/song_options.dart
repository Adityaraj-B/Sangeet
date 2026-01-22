import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../constants.dart';
import '../screens/playlist/components/add_to_playlist.dart';
import '../services/audio_player_service.dart';
import '../services/like_service.dart';

class SongOptionsSheet extends StatelessWidget {
  final Song song;
  final VoidCallback? onPlay;

  final AudioPlayerService _audioService = AudioPlayerService();

  SongOptionsSheet({
    super.key,
    required this.song,
    this.onPlay,
  });


  static void show(BuildContext context, Song song, {VoidCallback? onPlay}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SongOptionsSheet(song: song, onPlay: onPlay),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLiked = context.watch<LikeService>().isLiked(song);
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 24),
            child: Transform.scale(
              scale: 0.98 + (value * 0.02),
              child: child,
            ),
          ),
        );
    },
    child: ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.6,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Song Info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: song.coverUrl.isNotEmpty
                          ? Image.network(
                        song.coverUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _placeholderImage(),
                      )
                          : _placeholderImage(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            song.artist,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),

              if (onPlay != null)
                _OptionTile(
                  icon: Icons.play_circle_outline,
                  title: 'Play',
                  onTap: () {
                    Navigator.pop(context);
                    onPlay!();
                  },
                ),

              _OptionTile(
                icon: Icons.playlist_play,
                title: 'Play Next',
                onTap: () {
                  Navigator.pop(context);
                  _audioService.playNextInQueue(song);
                  _showGlassSnack(context, 'Will play next');
                },
              ),

              _OptionTile(
                icon: Icons.playlist_add,
                title: 'Add to Playlist',
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => AddToPlaylistDialog(song: song),
                  );
                },
              ),

              _OptionTile(
                icon: Icons.queue,
                title: 'Add to Queue',
                onTap: () {
                  Navigator.pop(context);
                  _audioService.addToQueue(song);
                  _showGlassSnack(context, 'Added to queue');
                },
              ),

              _OptionTile(
                icon: isLiked ? Icons.favorite : Icons.favorite_outline,
                title: isLiked ? 'Remove from Favorites' : 'Add to Favorites',
                onTap: () async {
                  final likeService = context.read<LikeService>();
                  // capture current state (build-time)
                  final wasLiked = isLiked;
                  Navigator.pop(context);
                  await likeService.toggleLike(song);
                  _showGlassSnack(
                    context,
                    wasLiked ? 'Removed from favorites' : 'Added to favorites',
                  );
                },
              ),

              _OptionTile(
                icon: Icons.share_outlined,
                title: 'Share',
                onTap: () {
                  Navigator.pop(context);
                },
              ),

              _OptionTile(
                icon: Icons.info_outline,
                title: 'Song Info',
                onTap: () {
                  Navigator.pop(context);
                  _showSongInfo(context);
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    )
    );
  }

  void _showGlassSnack(BuildContext context, String text) {
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
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 0.6,
                ),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.music_note,
        color: Colors.white54,
        size: 32,
      ),
    );
  }

  void _showSongInfo(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha :0.45),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha :0.16),
                    Colors.white.withValues(alpha :0.06),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha :0.18),
                  width: 0.6,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Title ──
                  const Text(
                    'Song Info',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),

                  const SizedBox(height: 24),

                  _glassInfoRowCentered('Title', song.title),
                  _glassInfoRowCentered('Artist', song.artist),
                  _glassInfoRowCentered(
                    'Duration',
                    _formatDuration(song.duration),
                  ),

                  const SizedBox(height: 26),

                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
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

  Widget _glassInfoRowCentered(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha :0.55),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.8),
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}