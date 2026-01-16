import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/components/playable.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/models/podcasts.dart';
import 'package:sangeet/services/audio_player_service.dart';
import '../screens/player/player_body.dart';

class BottomPlayer extends StatelessWidget {
  final PlaybackItem? currentItem;
  final Color backgroundColor;

  const BottomPlayer({
    super.key,
    required this.currentItem,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (currentItem == null) return const SizedBox.shrink();

    final audio = AudioPlayerService();
    final isPodcast = currentItem!.type == PlaybackType.podcast;

    final title = isPodcast
        ? (currentItem!.data as Podcast).title
        : (currentItem!.data as Song).title;

    final subtitle = isPodcast
        ? (currentItem!.data as Podcast).author
        : (currentItem!.data as Song).artist;

    final imageUrl = isPodcast
        ? (currentItem!.data as Podcast).imageUrl
        : (currentItem!.data as Song).coverUrl;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              item: currentItem!,
              onCollapse: () => Navigator.pop(context),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      backgroundColor.withOpacity(0.85),
                      backgroundColor.withOpacity(0.6),
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.5),
                    ],
                    stops: const [0.0, 0.2, 0.75, 1.0],
                  ),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrl,
                          height: 44,
                          width: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 44,
                            width: 44,
                            color: Colors.grey,
                            child: Icon(
                              isPodcast
                                  ? Icons.podcasts
                                  : Icons.music_note,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (!isPodcast)
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded),
                          color: Colors.white,
                          onPressed: audio.playPrevious,
                        ),

                      StreamBuilder<bool>(
                        stream: audio.playingStream,
                        initialData: audio.isPlaying,
                        builder: (context, snapshot) {
                          final playing = snapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              playing
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_filled_rounded,
                              size: 36,
                              color: Colors.white,
                            ),
                            onPressed: audio.togglePlayPause,
                          );
                        },
                      ),

                      if (!isPodcast)
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded),
                          color: Colors.white,
                          onPressed: audio.playNext,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
