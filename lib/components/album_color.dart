import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

Future<Color> extractDominantColor(String imageUrl) async {
  final palette = await PaletteGenerator.fromImageProvider(
    NetworkImage(imageUrl),
    size: const Size(200, 200),
    maximumColorCount: 12,
  );

  return palette.dominantColor?.color ?? Colors.black;
}
