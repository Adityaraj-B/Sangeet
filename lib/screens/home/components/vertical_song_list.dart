import 'package:flutter/material.dart';
import '../../../components/Song_options.dart';
import '../../../models/song.dart';

class VerticalSongList extends StatelessWidget {
  final List<Song> songs;
  final List<int> visibleIndices;
  final void Function(Song) onPlay;

  const VerticalSongList({
    super.key,
    required this.songs,
    required this.visibleIndices,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: songs.asMap().entries.map((entry) {
        final index = entry.key;
        final song = entry.value;
        final visible = visibleIndices.contains(index);

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
          opacity: visible ? 1 : 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutQuart,
            offset: visible ? Offset.zero : const Offset(0.05, 0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha :0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha :0.08),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onPlay(song),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha :0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              song.coverUrl,
                              fit: BoxFit.cover,
                              frameBuilder: (context, child, frame, wasSync) {
                                if (wasSync) return child;
                                return AnimatedOpacity(
                                  opacity: frame == null ? 0 : 1,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                  child: child,
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey[850],
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha :0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white.withValues(alpha :0.7),
                            size: 22,
                          ),
                          onPressed: () {
                            SongOptionsSheet.show(
                              context,
                              song,
                              onPlay: () => onPlay(song),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}