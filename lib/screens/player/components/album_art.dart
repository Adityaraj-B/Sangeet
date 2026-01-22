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
          image: DecorationImage(
            image: NetworkImage(coverUrl),
            fit: BoxFit.cover,
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha :0.08),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha :0.45),
              blurRadius: 40,
              spreadRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
