import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

enum PlayerViewMode { song, lyrics, artist }

class ViewToggle extends StatelessWidget {
  final PlayerViewMode viewMode;
  final ValueChanged<PlayerViewMode> onToggle;

  const ViewToggle({
    super.key,
    required this.viewMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _btn('Song', viewMode == PlayerViewMode.song, () => onToggle(PlayerViewMode.song)),
        const SizedBox(width: 12),
        _btn('Lyrics', viewMode == PlayerViewMode.lyrics, () => onToggle(PlayerViewMode.lyrics)),
        const SizedBox(width: 12),
        _btn('Artist', viewMode == PlayerViewMode.artist, () => onToggle(PlayerViewMode.artist)),
      ],
    );
  }

  Widget _btn(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? kPrimaryColor.withValues(alpha :0.85)
              : kSurfaceColor.withValues(alpha :0.25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
