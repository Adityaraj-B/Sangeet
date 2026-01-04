import 'package:flutter/material.dart';
import 'package:sangeet/models/song.dart';

class SongInfo extends StatelessWidget {
  final Song song;

  const SongInfo({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          song.artist,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
