import '../models/song.dart';
import '../models/playlist.dart';

class DummyData {
  static final List<Song> trendingSongs = [
    Song(
      id: '1',
      title: 'Midnight City',
      artist: 'M83',
      coverUrl: 'https://picsum.photos/seed/1/300/300',
      duration: const Duration(minutes: 4, seconds: 3),
    ),
    Song(
      id: '2',
      title: 'Starboy',
      artist: 'The Weeknd',
      coverUrl: 'https://picsum.photos/seed/2/300/300',
      duration: const Duration(minutes: 3, seconds: 50),
    ),
    Song(
      id: '3',
      title: 'Blinding Lights',
      artist: 'The Weeknd',
      coverUrl: 'https://picsum.photos/seed/3/300/300',
      duration: const Duration(minutes: 3, seconds: 20),
    ),
  ];

  static final List<Song> recommendedSongs = [
    Song(
      id: '4',
      title: 'Levitating',
      artist: 'Dua Lipa',
      coverUrl: 'https://picsum.photos/seed/4/300/300',
      duration: const Duration(minutes: 3, seconds: 23),
    ),
    Song(
      id: '5',
      title: 'Peaches',
      artist: 'Justin Bieber',
      coverUrl: 'https://picsum.photos/seed/5/300/300',
      duration: const Duration(minutes: 3, seconds: 18),
    ),
    Song(
      id: '6',
      title: 'Save Your Tears',
      artist: 'The Weeknd',
      coverUrl: 'https://picsum.photos/seed/6/300/300',
      duration: const Duration(minutes: 3, seconds: 35),
    ),
  ];

  static final List<Song> recentSongs = [
    Song(
      id: '7',
      title: 'Good 4 U',
      artist: 'Olivia Rodrigo',
      coverUrl: 'https://picsum.photos/seed/7/300/300',
      duration: const Duration(minutes: 2, seconds: 58),
    ),
    Song(
      id: '8',
      title: 'Montero',
      artist: 'Lil Nas X',
      coverUrl: 'https://picsum.photos/seed/8/300/300',
      duration: const Duration(minutes: 2, seconds: 17),
    ),
  ];

  static final List<Playlist> playlists = [
    // Playlist(
    //   id: '1',
    //   title: 'Top Hits',
    //   coverUrl: 'https://picsum.photos/seed/9/300/300', songs: [],
    //
    // ),
    // Playlist(
    //   id: '2',
    //   title: 'Chill Vibes',
    //   coverUrl: 'https://picsum.photos/seed/10/300/300', songs: [],
    //
    // ),
    // Playlist(
    //   id: '3',
    //   title: 'Workout',
    //   coverUrl: 'https://picsum.photos/seed/11/300/300', songs: [],
    //
    // ),
    // Playlist(
    //   id: '4',
    //   title: 'Party Mix',
    //   coverUrl: 'https://picsum.photos/seed/12/300/300', songs: [
    //     trendingSongs[0],
    //     recommendedSongs[1],
    //     recentSongs[0],
    //   ],

    //),
  ];
  static final List<Song> likedSongs = [
    Song(
      id: '101',
      title: 'After Hours',
      artist: 'The Weeknd',
      coverUrl: 'https://picsum.photos/seed/101/300/300',
      duration: const Duration(minutes: 6, seconds: 1),
    ),
    Song(
      id: '102',
      title: 'Night Changes',
      artist: 'One Direction',
      coverUrl: 'https://picsum.photos/seed/102/300/300',
      duration: const Duration(minutes: 3, seconds: 46),
    ),
    Song(
      id: '103',
      title: 'Heat Waves',
      artist: 'Glass Animals',
      coverUrl: 'https://picsum.photos/seed/103/300/300',
      duration: const Duration(minutes: 3, seconds: 58),
    ),
    Song(
      id: '104',
      title: 'Someone You Loved',
      artist: 'Lewis Capaldi',
      coverUrl: 'https://picsum.photos/seed/104/300/300',
      duration: const Duration(minutes: 3, seconds: 2),
    ),
  ];

}
