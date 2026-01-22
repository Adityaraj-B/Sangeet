import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class PlayerControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Color accentColor;

  const PlayerControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 28,
          icon: Icon(Icons.skip_previous, color: accentColor),
          onPressed: onPrevious,
        ),

        const SizedBox(width: 16),

        GestureDetector(
          onTap: onPlayPause,
          child: AnimatedScale(
            scale: isPlaying ? 1.0 : 1.05,
            duration: const Duration(milliseconds: 150),
            child: Container(
              height: 64,
              width: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryColor,
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 36,
              ),
            ),
          ),
        ),

        const SizedBox(width: 16),

        IconButton(
          iconSize: 28,
          icon: Icon(Icons.skip_next, color: accentColor),
          onPressed: onNext,
        ),
      ],
    );
  }
}
