import 'package:flutter/material.dart';
import '../../../models/song.dart';

class HorizontalSongList extends StatelessWidget {
  final List<Song> songs;
  final List<int> visibleIndices;
  final void Function(Song) onPlay;

  const HorizontalSongList({
    super.key,
    required this.songs,
    required this.visibleIndices,
    required this.onPlay,
  });


  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 245,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: ListView.separated(
          key: ValueKey('h-${songs.length}-${visibleIndices.length}'),
          scrollDirection: Axis.horizontal,
          itemCount: songs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final song = songs[index];
            final visible = visibleIndices.contains(index);
            return SizedBox(
              width: 150,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: visible ? 0 : 12, end: visible ? 0 : 12),
                duration: const Duration(milliseconds: 420),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: visible ? 1 : 0,
                    child: Transform.translate(offset: Offset(visible ? 0 : 12, 0), child: child),
                  );
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(children: [
                      Image.network(song.coverUrl, height: 140, width: 150, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(height: 140, width: 150, color: Colors.grey)),
                      Positioned(
                        right: 5,
                        top: 8,
                        child: Container(
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                          child: IconButton(iconSize: 20, padding: const EdgeInsets.all(6), icon: const Icon(Icons.more_vert, color: Colors.white70), onPressed: () {}),
                        ),
                      )
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)),
                      ),
                      IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 28), onPressed: () => onPlay(song)),
                    ],
                  ),
                  Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 14)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}
