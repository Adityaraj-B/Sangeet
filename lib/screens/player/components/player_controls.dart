import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class PlayerControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const PlayerControls({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 28,
          icon: const Icon(Icons.skip_previous, color: Colors.white),
          onPressed: () {},
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onPlayPause,
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
        const SizedBox(width: 12),
        IconButton(
          iconSize: 28,
          icon: const Icon(Icons.skip_next, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }
}
