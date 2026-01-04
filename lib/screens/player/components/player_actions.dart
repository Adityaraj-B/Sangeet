import 'package:flutter/material.dart';

class PlayerActions extends StatelessWidget {
  const PlayerActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        _Action(Icons.playlist_add, 'Playlist'),
        _Action(Icons.share, 'Share'),
        _Action(Icons.more_horiz, 'More'),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Action(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
