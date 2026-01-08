import 'dart:ui';

import 'package:flutter/material.dart';
import '../data/dummy_data.dart' as song;
import '../models/song.dart';
import '../screens/player/player_body.dart';

class BottomPlayer extends StatelessWidget {
  final Song? currentSong;
  final bool isPlaying;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Color backgroundColor;


  const BottomPlayer({
    super.key,
    required this.currentSong,
    required this.isPlaying,
    required this.onToggle,
    required this.onNext,
    required this.onPrevious,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (currentSong == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PlayerScreen(
                  song: currentSong!,
                  isPlaying: isPlaying,
                  onPlayPause: onToggle, onCollapse: () {  },
                ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          children: [
            // Base container with gradient background
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      backgroundColor.withOpacity(0.85),
                      backgroundColor.withOpacity(0.6),
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.5),
                    ],
                    stops: const [0.0, 0.2, 0.75, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            // Blur and content on top
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          currentSong!.coverUrl,
                          height: 44,
                          width: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(
                                height: 44,
                                width: 44,
                                color: Colors.grey,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentSong!.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      _ControlButton(
                        icon: Icons.skip_previous_rounded,
                        onTap: onPrevious,
                      ),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: IconButton(
                          key: ValueKey(isPlaying),
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                          onPressed: onToggle,
                        ),
                      ),

                      _ControlButton(
                        icon: Icons.skip_next_rounded,
                        onTap: onNext,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      splashRadius: 22,
      icon: Icon(
        icon,
        color: Colors.white.withOpacity(0.9),
        size: 26,
      ),
      onPressed: onTap,
    );
  }
}