import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/models/artist.dart';
import 'package:sangeet/models/album.dart';

class TopResultCard extends StatefulWidget {
  final dynamic item;
  final VoidCallback onTap;

  const TopResultCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<TopResultCard> createState() => _TopResultCardState();
}

class _TopResultCardState extends State<TopResultCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSong = widget.item is Song;
    final isArtist = widget.item is Artist;
    final isAlbum = widget.item is Album;
    final String title;
    final String subtitle;
    final String imageUrl;
    final String typeLabel;

    if (isSong) {
      final song = widget.item as Song;
      title = song.title;
      subtitle = song.artist;
      imageUrl = song.coverUrl;
      typeLabel = 'Song';
    } else if (isAlbum) {
      final album = widget.item as Album;
      title = album.name;
      subtitle = album.artist;
      imageUrl = album.coverUrl;
      typeLabel = 'Album';
    } else {
      final artist = widget.item as Artist;
      title = artist.name;
      subtitle = 'Artist';
      imageUrl = artist.imageUrl;
      typeLabel = 'Artist';
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Artwork
              ClipRRect(
                borderRadius: BorderRadius.circular(isArtist ? 48 : 10),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => _placeholder(isSong, isAlbum),
                        )
                      : _placeholder(isSong, isAlbum),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      typeLabel.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Play button for songs/albums
              if (isSong || isAlbum) ...[
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(bool isSong, bool isAlbum) {
    return Container(
      color: const Color(0xFF252528),
      child: Center(
        child: Icon(
          isSong
              ? Icons.music_note_rounded
              : (isAlbum ? Icons.album_rounded : Icons.person_rounded),
          color: Colors.white.withValues(alpha: 0.15),
          size: 32,
        ),
      ),
    );
  }
}
