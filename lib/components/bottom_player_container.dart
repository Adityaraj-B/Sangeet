import 'package:flutter/material.dart';
import 'package:sangeet/services/audio_player_service.dart';
import 'bottom_player.dart';

class BottomPlayerContainer extends StatelessWidget {
  final Color backgroundColor;

  const BottomPlayerContainer({
    super.key,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final audio = AudioPlayerService();

    return AnimatedBuilder(
      animation: audio.queue,
      builder: (context, _) {
        final hasSong = audio.currentSong != null;

        return AnimatedSlide(
          offset: hasSong ? Offset.zero : const Offset(0, 1.2),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: hasSong ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: BottomPlayer(
                backgroundColor: backgroundColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
