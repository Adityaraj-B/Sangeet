import 'package:flutter/material.dart';
import '../../../models/song.dart';
import '../../../services/recently_played.dart';
import '../../home/components/old components/section_header.dart';

class RecentlyPlayedSection extends StatefulWidget {
  final void Function(Song) onPlaySong;
  final VoidCallback? onSeeAll;

  const RecentlyPlayedSection({
    super.key,
    required this.onPlaySong,
    this.onSeeAll,
  });

  @override
  State<RecentlyPlayedSection> createState() => _RecentlyPlayedSectionState();
}

class _RecentlyPlayedSectionState extends State<RecentlyPlayedSection> {
  final RecentlyPlayedService _recentService = RecentlyPlayedService();

  @override
  void initState() {
    super.initState();
    // Fetch initial data to populate the notifier when this widget mounts
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final songs = await _recentService.getRecentlyPlayed(limit: 10);
    // Update the notifier so the builder has data to show immediately
    RecentlyPlayedService.recentSongsNotifier.value = songs;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    final horizontalPad = isWide ? 28.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          child: SectionHeader(
            title: 'Recently Played',
            onSeeAll: widget.onSeeAll,
          ),
        ),
        const SizedBox(height: 16),

        // Reactive List
        SizedBox(
          height: isWide ? 220 : 200,
          child: ValueListenableBuilder<List<Song>>(
            valueListenable: RecentlyPlayedService.recentSongsNotifier,
            builder: (context, songs, child) {
              // 1. Empty State
              if (songs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.white.withValues(alpha :0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No recently played songs',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha :0.5),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 2. Data State
              // Ensure we only show the limit (e.g. 10) in the horizontal view
              final displaySongs = songs.take(10).toList();

              return ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                scrollDirection: Axis.horizontal,
                itemCount: displaySongs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final song = displaySongs[index];
                  return _buildSongCard(song);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSongCard(Song song) {
    return GestureDetector(
      onTap: () => widget.onPlaySong(song),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album art
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha :0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  song.coverUrl.isNotEmpty
                      ? Image.network(
                          song.coverUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[900],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  color: Colors.white54,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => _placeholderImage(),
                        )
                      : _placeholderImage(),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha :0.7),
                        ],
                      ),
                    ),
                  ),

                  // Play icon overlay
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha :0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Song title
          SizedBox(
            width: 140,
            child: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 2),

          // Artist name
          SizedBox(
            width: 140,
            child: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha :0.6),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: Colors.grey[900],
      child: Icon(
        Icons.music_note,
        color: Colors.white.withValues(alpha :0.3),
        size: 40,
      ),
    );
  }
}