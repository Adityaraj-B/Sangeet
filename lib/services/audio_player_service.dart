import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sangeet/services/queue.dart';
import 'package:sangeet/services/recently_played.dart';
import '../models/song.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final QueueService _queueService = QueueService();
  final RecentlyPlayedService _recentService = RecentlyPlayedService();

  StreamSubscription<PlayerState>? _completionSub;
  bool _handlingCompletion = false;
  int _playOp = 0;
  _AudioPlayerHandler? _audioHandler;
  bool _initialized = false;

  AudioPlayer get player => _audioPlayer;
  Song? get currentSong => _queueService.currentSong;
  QueueService get queue => _queueService;

  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<bool> get playingStream => _audioPlayer.playingStream;

  bool get isPlaying => _audioPlayer.playing;
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _audioPlayer.duration;

  /// Initialize audio service - call this early in app lifecycle
  Future<void> initialize() async {
    if (_initialized) {
      print('AudioPlayerService: Already initialized');
      return;
    }

    print('AudioPlayerService: Starting initialization...');
    _setupCompletionListener();

    // Initialize audio handler for notifications
    try {
      print('AudioPlayerService: Calling AudioService.init...');
      _audioHandler = await AudioService.init(
        builder: () => _AudioPlayerHandler(_audioPlayer, this),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.sangeet.audio',
          androidNotificationChannelName: 'Sangeet',
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      ) as _AudioPlayerHandler?;
      _initialized = true;
      print('AudioPlayerService: ✅ Audio service initialized successfully!');
      print('AudioPlayerService: Handler created: ${_audioHandler != null}');
    } catch (e, stackTrace) {
      print('AudioPlayerService: ❌ Failed to initialize audio service');
      print('AudioPlayerService: Error: $e');
      print('AudioPlayerService: Stack trace: $stackTrace');
      // Continue without audio service - music will still play, just no notification
      _initialized = true;
    }
  }

  void _updateMediaItem(Song song) {
    print('AudioPlayerService: _updateMediaItem called for: ${song.title}');
    print('AudioPlayerService: Handler is null: ${_audioHandler == null}');

    if (_audioHandler == null) {
      print('AudioPlayerService: ⚠️ Cannot update media item - handler is null!');
      return;
    }

    final mediaItem = MediaItem(
      id: song.id,
      album: 'Sangeet',
      title: song.title,
      artist: song.artist,
      duration: song.duration,
      artUri: Uri.parse(song.coverUrl),
    );

    print('AudioPlayerService: Created MediaItem - ${mediaItem.title}');
    _audioHandler!.updateMediaItem(mediaItem);
    _audioHandler!.updatePlaybackState(playing: true);
    print('AudioPlayerService: ✅ Media notification updated!');
  }

  /// Plays a song. If same song is already current, resumes if paused.
  /// Returns true if playback was started/resumed, false if skipped.
  Future<bool> playSong(Song song) async {
    if (song.streamUrl == null || song.streamUrl!.isEmpty) return false;

    // Spotify-like: if this song is already the current one, don't restart.
    final current = _queueService.currentSong;
    if (current != null && current.id == song.id) {
      // If it's the same song but playback is paused/stopped, resume.
      if (!_audioPlayer.playing) {
        await _audioPlayer.play();
      }
      return true;
    }

    final op = ++_playOp;

    await _recentService.addSong(song);
    await _queueService.playSong(song);

    // If another play request started while we were awaiting, abort this one.
    if (op != _playOp) return false;

    // Stop current playback immediately to avoid stale audio continuing.
    await _audioPlayer.stop();

    if (op != _playOp) return false;

    await _audioPlayer.setUrl(song.streamUrl!);

    if (op != _playOp) return false;

    // Update media notification
    _updateMediaItem(song);

    await _audioPlayer.play();
    return true;
  }

  void _setupCompletionListener() {
    _completionSub?.cancel();
    _completionSub = null;

    _completionSub = _audioPlayer.playerStateStream.listen((state) async {
      print('AudioPlayerService: PlayerState changed - processingState: ${state.processingState}, playing: ${state.playing}');

      if (state.processingState != ProcessingState.completed) return;

      print('AudioPlayerService: Song completed, handling completion...');

      if (_handlingCompletion) {
        print('AudioPlayerService: Already handling completion, skipping');
        return;
      }

      _handlingCompletion = true;
      try {
        print('AudioPlayerService: Calling playNext from completion listener');
        await playNext();
        print('AudioPlayerService: playNext completed');
      } catch (e) {
        print('AudioPlayerService: Error in completion handler: $e');
      } finally {
        _handlingCompletion = false;
      }
    });
  }

  Future<void> togglePlayPause() async {
    _audioPlayer.playing
        ? await _audioPlayer.pause()
        : await _audioPlayer.play();
  }

  Future<void> play() async => _audioPlayer.play();
  Future<void> pause() async => _audioPlayer.pause();
  Future<void> stop() async {
    await _audioPlayer.stop();
    _audioHandler?.stop();
  }
  Future<void> seek(Duration position) async => _audioPlayer.seek(position);

  Future<void> playNext() async {
    print('AudioPlayerService.playNext: Current queue length: ${_queueService.upNext.length}');

    Song? nextSong = await _queueService.playNext();

    // If no next song available, try to load similar songs and get next again
    if (nextSong == null) {
      print('AudioPlayerService.playNext: No song in queue, trying to load similar songs');
      final current = _queueService.currentSong;
      if (current != null) {
        await _queueService.loadMoreSimilar(current);
        nextSong = await _queueService.playNext();
      }
    }

    if (nextSong == null || nextSong.streamUrl?.isEmpty == true) {
      print('AudioPlayerService: No next song available or empty stream URL');
      return;
    }

    print('AudioPlayerService: Playing next song: ${nextSong.title}');

    // Add to recently played
    await _recentService.addSong(nextSong);

    try {
      // Set the new URL first (this automatically stops current playback)
      print('AudioPlayerService: Setting URL: ${nextSong.streamUrl}');
      await _audioPlayer.setUrl(nextSong.streamUrl!);

      // Update media notification
      _updateMediaItem(nextSong);

      // Play the new song
      print('AudioPlayerService: Calling play()');
      await _audioPlayer.play();

      print('AudioPlayerService: Play command sent, playing=${_audioPlayer.playing}');
    } catch (e) {
      print('AudioPlayerService: Error playing next song: $e');
    }
  }

  Future<void> playPrevious() async {
    if (_audioPlayer.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final previousSong = _queueService.playPrevious();
    if (previousSong == null || previousSong.streamUrl?.isEmpty == true) return;

    await _audioPlayer.stop();
    await _audioPlayer.setUrl(previousSong.streamUrl!);

    // Update media notification
    _updateMediaItem(previousSong);

    await _audioPlayer.play();
  }

  void addToQueue(Song song) {
    _queueService.addToQueue(song);
  }

  void playNextInQueue(Song song) {
    _queueService.playNextInQueue(song);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    await _audioPlayer.setLoopMode(mode);
  }

  Future<void> setShuffleMode(bool enabled) async {
    if (enabled) {
      _queueService.shuffleQueue();
    }
  }

  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Dispose resources - call when app is closing
  Future<void> dispose() async {
    await _completionSub?.cancel();
    _completionSub = null;
    await _audioPlayer.dispose();
  }
}

// Audio Handler for media notifications
class _AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  final AudioPlayerService _service;
  final BehaviorSubject<MediaItem?> _mediaItemSubject = BehaviorSubject<MediaItem?>();
  final BehaviorSubject<PlaybackState> _playbackStateSubject = BehaviorSubject<PlaybackState>.seeded(
    PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.idle,
      playing: false,
    ),
  );

  late StreamSubscription<Duration> _positionSubscription;
  late StreamSubscription<bool> _playingSubscription;

  _AudioPlayerHandler(this._player, this._service) {
    print('_AudioPlayerHandler: Constructor called - creating handler');
    // Listen to player state changes
    _positionSubscription = _player.positionStream.listen((position) {
      _updatePlaybackState(position: position);
    });

    _playingSubscription = _player.playingStream.listen((playing) {
      print('_AudioPlayerHandler: Playing state changed to: $playing');
      _updatePlaybackState(playing: playing);
    });
    print('_AudioPlayerHandler: ✅ Handler fully initialized with listeners');
  }

  @override
  BehaviorSubject<MediaItem?> get mediaItem => _mediaItemSubject;

  @override
  BehaviorSubject<PlaybackState> get playbackState => _playbackStateSubject;

  @override
  Future<void> updateMediaItem(MediaItem item) async {
    print('_AudioPlayerHandler: updateMediaItem called - ${item.title}');
    _mediaItemSubject.add(item);
    print('_AudioPlayerHandler: MediaItem added to subject');
  }

  void updatePlaybackState({bool? playing, Duration? position}) {
    print('_AudioPlayerHandler: updatePlaybackState - playing: $playing, position: $position');
    final current = _playbackStateSubject.value;
    _playbackStateSubject.add(current.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        (playing ?? current.playing) ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: playing ?? current.playing,
      updatePosition: position ?? current.updatePosition,
      speed: 1.0,
    ));
    print('_AudioPlayerHandler: PlaybackState updated');
  }

  void _updatePlaybackState({bool? playing, Duration? position}) {
    updatePlaybackState(playing: playing, position: position);
  }

  @override
  Future<void> play() => _service.play();

  @override
  Future<void> pause() => _service.pause();

  @override
  Future<void> stop() async {
    await _service.stop();
    await _positionSubscription.cancel();
    await _playingSubscription.cancel();
    await _mediaItemSubject.close();
    await _playbackStateSubject.close();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _service.seek(position);

  @override
  Future<void> skipToNext() => _service.playNext();

  @override
  Future<void> skipToPrevious() => _service.playPrevious();

  @override
  Future<void> fastForward() => _service.seek(_player.position + const Duration(seconds: 10));

  @override
  Future<void> rewind() => _service.seek(_player.position - const Duration(seconds: 10));
}
