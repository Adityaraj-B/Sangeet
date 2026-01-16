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
    if (songs.isEmpty) {
      return const SizedBox(
        height: 245,
        child: Center(
          child: Text(
            'No songs available',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    return SizedBox(
      height: 245,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: ListView.separated(
          key: ValueKey('h-${songs.length}-${visibleIndices.length}'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 2),
          itemCount: songs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final song = songs[index];
            final visible = visibleIndices.contains(index);

            return SizedBox(
              width: 150,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: visible ? 0 : 12, end: 0),
                duration: const Duration(milliseconds: 420),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: visible ? 1 : 0,
                    child: Transform.translate(
                      offset: Offset(visible ? 0 : 12, 0),
                      child: child,
                    ),
                  );
                },
                child: _SongCard(
                  song: song,
                  onPlay: onPlay,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  final Song song;
  final void Function(Song) onPlay;

  const _SongCard({
    required this.song,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onPlay(song),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                _CoverImage(url: song.coverUrl),

                // Options menu
                Positioned(
                  right: 6,
                  top: 6,
                  child: _OptionsButton(song: song),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),

          Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  final String url;

  const _CoverImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _placeholder();
    }

    return Image.network(
      url,
      height: 140,
      width: 150,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: 140,
          width: 150,
          color: Colors.grey.shade800,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 140,
      width: 150,
      color: Colors.grey.shade800,
      child: const Icon(
        Icons.music_note,
        color: Colors.white24,
        size: 48,
      ),
    );
  }
}

class _OptionsButton extends StatelessWidget {
  final Song song;

  const _OptionsButton({required this.song});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showOptions(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.more_vert,
          color: Colors.white70,
          size: 20,
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _option(Icons.queue_music, 'Add to Queue'),
              _option(Icons.playlist_add, 'Add to Playlist'),
              _option(Icons.share, 'Share'),
            ],
          ),
        );
      },
    );
  }

  Widget _option(IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: () {},
    );
  }
}
