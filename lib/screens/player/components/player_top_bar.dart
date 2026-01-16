import 'package:flutter/material.dart';

class PlayerTopBar extends StatelessWidget {
  final bool liked;
  final VoidCallback onLikeToggle;
  final VoidCallback onCollapse;

  const PlayerTopBar({
    super.key,
    required this.liked,
    required this.onLikeToggle,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: onCollapse, // ✅ ONLY callback
        ),
        const Spacer(),
        const Text(
          'Now Playing',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            color: liked ? Colors.redAccent : Colors.white70,
          ),
          onPressed: onLikeToggle,
        ),
      ],
    );
  }
}
