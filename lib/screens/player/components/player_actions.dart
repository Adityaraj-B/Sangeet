import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../components/queue_screen.dart';
import '../../../components/device_selector_sheet.dart';
import '../../../models/song.dart';
import '../../../services/audio_player_service.dart';
import '../../playlist/components/add_to_playlist.dart';
import 'package:provider/provider.dart';
import '../../../services/like_service.dart';

class PlayerActions extends StatelessWidget {
  final Color accentColor;
  final Song? currentSong;

  const PlayerActions({
    super.key,
    required this.accentColor,
    this.currentSong,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Action(
          icon: Icons.playlist_add,
          label: 'Playlist',
          onTap: currentSong != null
              ? () {
            showDialog(
              context: context,
              builder: (_) => AddToPlaylistDialog(song: currentSong!),
            );
          }
              : null,
        ),
        _Action(
          icon: Icons.speaker_group_rounded,
          label: 'Devices',
          onTap: () {
            DeviceSelectorSheet.show(context);
          },
        ),
        // In player_actions.dart:
        _Action(
          icon: Icons.queue_music,
          label: 'Queue',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QueueScreen()),
            );
          },
        ),
        _Action(
          icon: Icons.more_horiz,
          label: 'More',
          onTap: () {
            _showMoreOptions(context);
          },
        ),
      ],
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        // compute current liked state here (using outer context)
        final isLiked = currentSong != null && context.read<LikeService>().isLiked(currentSong!);
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
                      Colors.white.withValues(alpha :0.14),
                      Colors.white.withValues(alpha :0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha :0.18),
                    width: 0.6,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha :0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    _MoreOption(
                      icon: Icons.playlist_play,
                      title: 'Play Next',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        AudioPlayerService().playNextInQueue(currentSong!);
                        _showGlassSnack(context, 'Will play next');
                      },
                    ),

                    _MoreOption(
                      icon: Icons.queue_music,
                      title: 'Add to Queue',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        AudioPlayerService().addToQueue(currentSong!);
                        _showGlassSnack(context, 'Added to queue');
                      },
                    ),

                    _MoreOption(
                      icon: isLiked ? Icons.favorite : Icons.favorite_outline,
                      title: isLiked ? 'Remove from Favorites' : 'Add to Favorites',
                      onTap: () async {
                        if (currentSong == null) return;
                        final likeService = context.read<LikeService>();
                        final wasLiked = likeService.isLiked(currentSong!);
                        Navigator.pop(sheetContext);
                        await likeService.toggleLike(currentSong!);
                        _showGlassSnack(
                          context,
                          wasLiked ? 'Removed from favorites' : 'Added to favorites',
                        );
                      },
                    ),

                    _MoreOption(
                      icon: Icons.download_outlined,
                      title: 'Download',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showGlassSnack(context, 'Download started');
                      },
                    ),

                    _MoreOption(
                      icon: Icons.info_outline,
                      title: 'Song Info',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showSongInfo(context);
                      },
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

  void _showSongInfo(BuildContext context) {
    if (currentSong == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 0.6,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Song Info',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _InfoRow('Title', currentSong!.title),
                  _InfoRow('Artist', currentSong!.artist),
                  _InfoRow('Duration', _formatDuration(currentSong!.duration)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
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

  Widget _InfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha :0.6),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
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

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _Action({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MoreOption({
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 24),
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