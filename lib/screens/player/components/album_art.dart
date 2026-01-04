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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          coverUrl,
          height: 280,
          width: 280,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
