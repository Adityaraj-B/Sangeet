import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/models/song.dart';

import '../services/queue.dart';

class QueueScreen extends StatefulWidget {
  final VoidCallback? onPlaySong;

  const QueueScreen({super.key, this.onPlaySong});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final QueueService _queueService = QueueService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Queue'),
        actions: [
          if (_queueService.upNext.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'clear') {
                  _queueService.clearQueue();
                } else if (value == 'shuffle') {
                  _queueService.shuffleQueue();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'shuffle',
                  child: Row(
                    children: [
                      Icon(Icons.shuffle),
                      SizedBox(width: 12),
                      Text('Shuffle'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all),
                      SizedBox(width: 12),
                      Text('Clear Queue'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _queueService,
        builder: (context, _) {
          final upNext = _queueService.upNext;
          final history = _queueService.history;
          final currentSong = _queueService.currentSong;

          return CustomScrollView(
            slivers: [
              // Now Playing
              if (currentSong != null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Now Playing',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCurrentSongCard(currentSong),
                      ],
                    ),
                  ),
                ),
              ],

              // Up Next
              if (upNext.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          'Up Next',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${upNext.length}',
                            style: const TextStyle(
                              color: kPrimaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverReorderableList(
                  itemCount: upNext.length,
                  onReorder: (oldIndex, newIndex) {
                    _queueService.reorderQueue(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final song = upNext[index];
                    return _buildQueueSongTile(song, index, key: ValueKey(song.id));
                  },
                ),
              ],

              // History
              if (history.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'Recently Played',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final reversedIndex = history.length - 1 - index;
                      final song = history[reversedIndex];
                      return _buildHistorySongTile(song);
                    },
                    childCount: history.length,
                  ),
                ),
              ],

              // Empty state
              if (upNext.isEmpty && history.isEmpty && currentSong == null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.queue_music,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Queue is empty',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentSongCard(Song song) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: kPrimaryColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              song.coverUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 50,
                height: 50,
                color: kSurfaceColor,
                child: const Icon(Icons.music_note, color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.graphic_eq,
            color: kPrimaryColor,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildQueueSongTile(Song song, int index, {required Key key}) {
    return Dismissible(
      key: key,
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        _queueService.removeFromQueue(index);
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.drag_handle,
              color: Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                song.coverUrl,
                width: 45,
                height: 45,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 45,
                  height: 45,
                  color: kSurfaceColor,
                  child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          song.title,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildHistorySongTile(Song song) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          song.coverUrl,
          width: 45,
          height: 45,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 45,
            height: 45,
            color: kSurfaceColor,
            child: const Icon(Icons.music_note, color: Colors.white54, size: 20),
          ),
        ),
      ),
      title: Text(
        song.title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.history,
        color: Colors.white.withValues(alpha: 0.3),
        size: 20,
      ),
    );
  }
}