import 'package:flutter/material.dart';
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
          duration: const Duration(milliseconds: 420),
          opacity: visible ? 1 : 0,
          child: Transform.translate(
            offset: Offset(visible ? 0 : 12, 0),
            child: Card(
              color: Colors.white.withOpacity(0.03),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(song.coverUrl, height: 56, width: 56, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey, width: 56, height: 56)),
                ),
                title: Text(song.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(song.artist, style: TextStyle(color: Colors.white.withOpacity(0.65))),
                trailing: IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 30), onPressed: () => onPlay(song)),
                onTap: () => onPlay(song),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
