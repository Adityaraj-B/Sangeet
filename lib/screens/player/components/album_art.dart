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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    final artSize = isWide ? 350.0 : 280.0;

    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      child: RotationTransition(
        turns: rotation,
        child: Container(
          width: artSize,
          height: artSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: NetworkImage(coverUrl),
              fit: BoxFit.cover,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 50,
                spreadRadius: 8,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.03),
                blurRadius: 2,
                spreadRadius: 0,
              ),
            ],
          ),
          // Inner ring for vinyl look
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.black.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
