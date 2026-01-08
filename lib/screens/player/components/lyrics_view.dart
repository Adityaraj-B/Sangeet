import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class LyricsView extends StatelessWidget {
  final String? lyrics;

  const LyricsView({super.key, this.lyrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceColor.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        child: Text(
          lyrics ?? 'Lyrics not available',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
