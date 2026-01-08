import 'package:flutter/material.dart';

class AlbumArt extends StatelessWidget {
  final String coverUrl;
  final Animation<double> rotation;

  const AlbumArt({
    super.key,
    required this.coverUrl,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: rotation,
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 40,
              spreadRadius: 6,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            coverUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.music_note, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
