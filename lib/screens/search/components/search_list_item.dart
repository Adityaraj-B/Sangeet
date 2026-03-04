import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sangeet/models/artist.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/models/album.dart';
import 'package:sangeet/components/song_options.dart';

// ─────────────────────────────────────────────
// SONG LIST ITEM
// ─────────────────────────────────────────────
class SongResultItem extends StatefulWidget {
  final Song song;
  final VoidCallback onTap;

  const SongResultItem({super.key, required this.song, required this.onTap});

  @override
  State<SongResultItem> createState() => _SongResultItemState();
}

class _SongResultItemState extends State<SongResultItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onLongPress: () =>
          SongOptionsSheet.show(context, widget.song, onPlay: widget.onTap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Artwork with shadow
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.song.coverUrl.isNotEmpty
                    ? Image.network(
                        widget.song.coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) =>
                            _songPlaceholder(),
                      )
                    : _songPlaceholder(),
              ),
            ),
            const SizedBox(width: 14),
            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // More button
            GestureDetector(
              onTap: () => SongOptionsSheet.show(context, widget.song,
                  onPlay: widget.onTap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.white.withValues(alpha: 0.25),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _songPlaceholder() => Container(
        color: const Color(0xFF1E1E22),
        child: Center(
          child: Icon(Icons.music_note_rounded,
              color: Colors.white.withValues(alpha: 0.12), size: 20),
        ),
      );
}

// ─────────────────────────────────────────────
// ARTIST LIST ITEM
// ─────────────────────────────────────────────
class ArtistResultItem extends StatefulWidget {
  final Artist artist;
  final VoidCallback onTap;

  const ArtistResultItem(
      {super.key, required this.artist, required this.onTap});

  @override
  State<ArtistResultItem> createState() => _ArtistResultItemState();
}

class _ArtistResultItemState extends State<ArtistResultItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Circular artist photo
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: widget.artist.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.artist.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              _artistPlaceholder(),
                        )
                      : _artistPlaceholder(),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Artist',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 12,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.18),
              size: 20,
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }

  Widget _artistPlaceholder() => Container(
        color: const Color(0xFF1E1E22),
        child: Center(
          child: Icon(Icons.person_rounded,
              color: Colors.white.withValues(alpha: 0.12), size: 22),
        ),
      );
}

// ─────────────────────────────────────────────
// ALBUM LIST ITEM
// ─────────────────────────────────────────────
class AlbumResultItem extends StatefulWidget {
  final Album album;
  final VoidCallback onTap;

  const AlbumResultItem({super.key, required this.album, required this.onTap});

  @override
  State<AlbumResultItem> createState() => _AlbumResultItemState();
}

class _AlbumResultItemState extends State<AlbumResultItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: _isPressed
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Album art with shadow
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: widget.album.coverUrl.isNotEmpty
                      ? Image.network(
                          widget.album.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              _albumPlaceholder(),
                        )
                      : _albumPlaceholder(),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      'Album',
                      if (widget.album.artist.isNotEmpty) widget.album.artist,
                      if (widget.album.year.isNotEmpty) widget.album.year,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 12,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.18),
              size: 20,
            ),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }

  Widget _albumPlaceholder() => Container(
        color: const Color(0xFF1E1E22),
        child: Center(
          child: Icon(Icons.album_rounded,
              color: Colors.white.withValues(alpha: 0.12), size: 20),
        ),
      );
}
