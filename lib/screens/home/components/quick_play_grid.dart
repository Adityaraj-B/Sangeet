import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../models/song.dart';
import '../../../components/Song_options.dart';

/// Spotify-style quick play grid with larger tiles for quick access
class QuickPlayGrid extends StatelessWidget {
  final List<Song> songs;
  final void Function(Song) onPlaySong;

  const QuickPlayGrid({
    super.key,
    required this.songs,
    required this.onPlaySong,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();

    final displaySongs = songs.take(4).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;

    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 28 : 20, 8, isWide ? 28 : 20, 16),
      child: Column(
        children: [
          if (isWide)
            // On desktop: show all 4 in a single row
            Row(
              children: [
                for (int i = 0; i < displaySongs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _QuickPlayTile(
                      song: displaySongs[i],
                      onTap: () => onPlaySong(displaySongs[i]),
                    ),
                  ),
                ],
              ],
            )
          else ...[
            // On mobile: 2x2 grid
            Row(
              children: [
                Expanded(child: _QuickPlayTile(song: displaySongs[0], onTap: () => onPlaySong(displaySongs[0]))),
                const SizedBox(width: 10),
                Expanded(child: _QuickPlayTile(song: displaySongs.length > 1 ? displaySongs[1] : displaySongs[0], onTap: () => onPlaySong(displaySongs.length > 1 ? displaySongs[1] : displaySongs[0]))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _QuickPlayTile(song: displaySongs.length > 2 ? displaySongs[2] : displaySongs[0], onTap: () => onPlaySong(displaySongs.length > 2 ? displaySongs[2] : displaySongs[0]))),
                const SizedBox(width: 10),
                Expanded(child: _QuickPlayTile(song: displaySongs.length > 3 ? displaySongs[3] : displaySongs[0], onTap: () => onPlaySong(displaySongs.length > 3 ? displaySongs[3] : displaySongs[0]))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickPlayTile extends StatefulWidget {
  final Song song;
  final VoidCallback onTap;

  const _QuickPlayTile({
    required this.song,
    required this.onTap,
  });

  @override
  State<_QuickPlayTile> createState() => _QuickPlayTileState();
}

class _QuickPlayTileState extends State<_QuickPlayTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onLongPress: () => SongOptionsSheet.show(context, widget.song, onPlay: widget.onTap),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Album Art
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.song.coverUrl.isNotEmpty
                          ? Image.network(
                              widget.song.coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                      // Subtle shine
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Song Title
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    widget.song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2A2A),
            Color(0xFF1A1A1A),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white.withValues(alpha: 0.15),
          size: 22,
        ),
      ),
    );
  }
}
