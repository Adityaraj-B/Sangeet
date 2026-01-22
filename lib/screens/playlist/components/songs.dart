import 'package:flutter/material.dart';

import '../../../models/song.dart';

class PlaylistSongs extends StatelessWidget {
  final List<Song> songs;
  final ValueChanged<Song> onPlaySong;
  final String playlistId;

  const PlaylistSongs({super.key,
    required this.songs,
    required this.onPlaySong,
    required this.playlistId,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, i) {
          final song = songs[i];
          return ListTile(
            leading: Image.network(song.coverUrl),
            title: Text(song.title),
            subtitle: Text(song.artist),
            onTap: () => onPlaySong(song),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
            ),
          );
        },
        childCount: songs.length,
      ),
    );
  }
}
