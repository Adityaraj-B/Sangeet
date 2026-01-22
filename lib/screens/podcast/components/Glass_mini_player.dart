import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../models/podcasts.dart';

class GlassMiniPlayer extends StatelessWidget {
  final Podcast podcast;
  final ValueChanged<Podcast> onPlay;

  const GlassMiniPlayer({
    super.key,
    required this.podcast,
    required this.onPlay,
  });


  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kPrimaryColor.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kPrimaryColor.withValues(alpha: 0.06)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: _coverImage()),
              const SizedBox(width: 12),
              Expanded(child: _titleAndProgress()),
              const SizedBox(width: 12),
              _controls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverImage() => Image.network(podcast.imageUrl, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 64, height: 64, color: Colors.grey[800], child: const Icon(Icons.podcasts, color: Colors.white24)));

  Widget _titleAndProgress() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(podcast.title,
              style: const TextStyle(
                  color: kPrimaryColor,
                  fontSize: 15,
                  fontWeight:
                  FontWeight.w800
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis
          ),
      const SizedBox(height: 4),
      Text(podcast.author,
          style: TextStyle(
              color: kPrimaryColor.withValues(alpha: 0.72),
              fontSize: 12
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis
      ),
      const SizedBox(height: 10),
      ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
              value: podcast.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(kAccentColor)
          )
      ),
    ]);
  }

  Widget _controls() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(onPressed: () {},
          icon: const Icon(Icons.replay_10),
          color: Colors.white70, iconSize: 22
      ),
      const SizedBox(height: 4),
      FloatingActionButton(
        heroTag: podcast.id,
        onPressed: () => onPlay(podcast),
        mini: true,
        backgroundColor: kAccentColor,
        child: const Icon(Icons.play_arrow, color: Colors.black),
      ),

    ]);
  }
}
