import 'package:flutter/material.dart';
import '../../../../models/playlist.dart';

class PlaylistGrid extends StatelessWidget {
  final List<Playlist> playlists;
  final List<int> visibleIndices;

  const PlaylistGrid({
    super.key,
    required this.playlists,
    required this.visibleIndices,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: playlists.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        final visible = visibleIndices.contains(index);

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          opacity: visible ? 1 : 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOut,
            offset: visible ? Offset.zero : const Offset(0, 0.08),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    playlist.coverUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (c, w, p) =>
                    p == null ? w : Container(color: Colors.grey.shade800),
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey.shade800),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha :0.55),
                          Colors.black.withValues(alpha :0.15),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        playlist.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 8,
                              color: Colors.black54,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
