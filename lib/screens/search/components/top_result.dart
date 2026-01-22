import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/models/artist.dart';
import 'package:sangeet/models/song.dart';

class TopResultCard extends StatelessWidget {
  final dynamic item; // Can be Song or Artist
  final VoidCallback onTap;

  const TopResultCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArtist = item is Artist;
    final String title = isArtist ? (item as Artist).name : (item as Song).title;
    final String subtitle = isArtist ? 'Artist' : (item as Song).artist;
    final String imageUrl = isArtist ? (item as Artist).imageUrl : (item as Song).coverUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                shape: isArtist ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isArtist ? null : BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isArtist ? 100 : 12),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(isArtist),
                )
                    : _placeholder(isArtist),
              ),
            ),
            const SizedBox(height: 16),

            // Title & Type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          subtitle.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Big Play Button (Only for Songs)
                if (!isArtist)
                  Container(
                    height: 48,
                    width: 48,
                    decoration: const BoxDecoration(
                      color: kPrimaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool isArtist) {
    return Container(
      color: const Color(0xFF2C2C2C),
      child: Icon(
        isArtist ? Icons.person_rounded : Icons.music_note_rounded,
        color: Colors.white.withValues(alpha: 0.2),
        size: 40,
      ),
    );
  }
}