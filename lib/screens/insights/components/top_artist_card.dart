import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../models/insights_models.dart';

class TopArtistCard extends StatelessWidget {
  final ArtistStats artist;
  final int rank;

  const TopArtistCard({
    super.key,
    required this.artist,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final rankColors = [
      kAccentColor,
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
      Colors.white.withValues(alpha: 0.5),
      Colors.white.withValues(alpha: 0.5),
    ];

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: rankColors[rank - 1],
                          width: 2,
                        ),
                        image: artist.imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(artist.imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: artist.imageUrl.isEmpty
                          ? Center(
                              child: Text(
                                artist.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: rankColors[rank - 1],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: rank <= 3 ? kBackgroundColor : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  artist.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  '${artist.playCount} plays',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
