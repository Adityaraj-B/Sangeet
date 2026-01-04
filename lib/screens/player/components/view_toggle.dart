import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class ViewToggle extends StatelessWidget {
  final bool showLyrics;
  final ValueChanged<bool> onToggle;

  const ViewToggle({
    super.key,
    required this.showLyrics,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _btn('Song', !showLyrics, () => onToggle(false)),
        const SizedBox(width: 12),
        _btn('Lyrics', showLyrics, () => onToggle(true)),
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
              ? kPrimaryColor.withOpacity(0.85)
              : kSurfaceColor.withOpacity(0.25),
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
