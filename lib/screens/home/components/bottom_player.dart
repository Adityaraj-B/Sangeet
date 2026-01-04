import 'package:flutter/material.dart';
import '../../../data/dummy_data.dart' as song;
import '../../../models/song.dart';
import '../../player/player_body.dart';

class BottomPlayer extends StatelessWidget {
  final Song? currentSong;
  final bool isPlaying;
  final VoidCallback onToggle;

  const BottomPlayer({Key? key, required this.currentSong, required this.isPlaying, required this.onToggle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (currentSong == null) return const SizedBox.shrink();
    return GestureDetector(
        onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            song: currentSong!,
            isPlaying: isPlaying,
            onPlayPause: onToggle,
          ),
        ),
      );
      },
      child: Container(
        height: 72,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06)))),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(currentSong!.coverUrl, height: 52, width: 52, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey, width: 52, height: 52))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(currentSong!.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(currentSong!.artist, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            ]),
          ),
          IconButton(icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 36), onPressed: onToggle),
          const SizedBox(width: 6),
        ]),
      ),
    );
  }
}
