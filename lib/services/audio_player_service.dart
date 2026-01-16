import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = 0;

  // Getters
  AudioPlayer get player => _audioPlayer;
  Song? get currentSong => _currentSong;
  List<Song> get playlist => _playlist;
  int get currentIndex => _currentIndex;

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<bool> get playingStream => _audioPlayer.playingStream;

  bool get isPlaying => _audioPlayer.playing;
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _audioPlayer.duration;

  // Play a single song
  Future<void> playSong(Song song) async {
    try {
      final url = song.streamUrl;

      if (url == null || url.isEmpty) {
        return;
      }

      _currentSong = song;
      _playlist = [song];
      _currentIndex = 0;

      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (_) {}
  }

  // Play a playlist starting from a specific song
  Future<void> playPlaylist(List<Song> songs, int startIndex) async {
    if (songs.isEmpty || startIndex < 0 || startIndex >= songs.length) {
      print('Invalid playlist or index');
      return;
    }

    _playlist = songs;
    _currentIndex = startIndex;
    await playSong(songs[startIndex]);
  }

  // Play/Pause toggle
  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  // Play
  Future<void> play() async {
    await _audioPlayer.play();
  }

  // Pause
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  // Stop
  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentSong = null;
  }

  // Seek to position
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // Next song
  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    _currentIndex = (_currentIndex + 1) % _playlist.length;
    await playSong(_playlist[_currentIndex]);
  }

  // Previous song
  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    // If more than 3 seconds into the song, restart it
    if (_audioPlayer.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    _currentIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    await playSong(_playlist[_currentIndex]);
  }

  // Set loop mode
  Future<void> setLoopMode(LoopMode mode) async {
    await _audioPlayer.setLoopMode(mode);
  }

  // Set shuffle mode
  Future<void> setShuffleMode(bool enabled) async {
    await _audioPlayer.setShuffleModeEnabled(enabled);
  }

  // Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  // Dispose
  void dispose() {
    _audioPlayer.dispose();
  }
}