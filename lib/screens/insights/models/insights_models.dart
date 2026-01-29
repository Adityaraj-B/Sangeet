import 'package:flutter/material.dart';

/// Artist statistics data model
class ArtistStats {
  final String name;
  final int playCount;
  final String imageUrl;
  final int totalMinutes;

  ArtistStats({
    required this.name,
    required this.playCount,
    required this.imageUrl,
    this.totalMinutes = 0,
  });
}

/// Genre statistics data model
class GenreStats {
  final String name;
  final int percentage;
  final Color color;

  GenreStats({
    required this.name,
    required this.percentage,
    required this.color,
  });
}
