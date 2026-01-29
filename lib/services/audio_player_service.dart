import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:rxdart/rxdart.dart';
import 'package:sangeet/services/queue.dart';
import 'package:sangeet/services/recently_played.dart';
import '../models/song.dart';

// Top-level handler that persists across the app
AudioHandler? _audioHandler;
bool _audioHandlerInitialized = false;
Completer<void>? _initializationCompleter;

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final QueueService _queueService = QueueService();
  final RecentlyPlayedService _recentService = RecentlyPlayedService();

  StreamSubscription<PlayerState>? _completionSub;
  StreamSubscription<audio_session.AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;
  bool _handlingCompletion = false;
  int _playOp = 0;
  bool _wasPlayingBeforeInterruption = false;

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
    // If already initialized, return immediately
    if (_audioHandlerInitialized && _audioHandler != null) {
      debugPrint('AudioPlayerService: Already initialized');
      return;
    }

    // If initialization is in progress, wait for it to complete
    if (_initializationCompleter != null) {
      debugPrint('AudioPlayerService: Initialization in progress, waiting...');
      try {
        await _initializationCompleter!.future;
        return;
      } catch (e) {
        // Previous initialization failed, we'll try again
        debugPrint('AudioPlayerService: Previous initialization failed: $e');
      }
    }

    // Create a new completer for this initialization attempt
    _initializationCompleter = Completer<void>();

    try {
      debugPrint('AudioPlayerService: Initializing audio service...');
      _audioHandler = await AudioService.init(
        builder: () => _AudioPlayerHandler(_audioPlayer, this),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.example.sangeet.audio',
          androidNotificationChannelName: 'Sangeet Music',
          androidNotificationChannelDescription: 'Music playback controls',
          androidNotificationIcon: 'drawable/ic_notification',
          androidShowNotificationBadge: true,
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: true,
          artDownscaleWidth: 300,
          artDownscaleHeight: 300,
          notificationColor: Color(0xFFE6D690),
          fastForwardInterval: Duration(seconds: 10),
          rewindInterval: Duration(seconds: 10),
          preloadArtwork: true,
        ),
      );
      _audioHandlerInitialized = true;
      _setupCompletionListener();
      await _setupAudioInterruptionHandling();
      _initializationCompleter!.complete();
      debugPrint('AudioPlayerService: Audio service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('AudioPlayerService: Failed to initialize audio service: $e');
      debugPrint('AudioPlayerService: Stack trace: $stackTrace');
      _audioHandlerInitialized = false;
      _audioHandler = null;
      _initializationCompleter!.completeError(e);
      _initializationCompleter = null; // Allow retry
      rethrow;
    }
  }

  void _updateMediaItem(Song song) {
    if (!_audioHandlerInitialized || _audioHandler == null) {
      debugPrint('AudioPlayerService: Cannot update media item - handler not initialized');
      return;
    }

    try {
      debugPrint('AudioPlayerService: Updating media item for: ${song.title}');

      final mediaItem = MediaItem(
        id: song.id,
        album: 'Sangeet',
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        artUri: song.coverUrl.isNotEmpty ? Uri.parse(song.coverUrl) : null,
      );

      final handler = _audioHandler as _AudioPlayerHandler;

      // Update media item
      handler.mediaItem.add(mediaItem);

      // Update playback state with duration
      final currentState = handler.playbackState.value;
      handler.playbackState.add(currentState.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          _audioPlayer.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: _audioPlayer.playing,
        updatePosition: _audioPlayer.position,
        bufferedPosition: Duration.zero,
        speed: 1.0,
      ));

      debugPrint('AudioPlayerService: Media item and playback state updated');
    } catch (e) {
      debugPrint('AudioPlayerService: Error updating media item: $e');
    }
  }

  /// Plays a song. If same song is already current, resumes if paused.
  Future<bool> playSong(Song song) async {
    debugPrint('AudioPlayerService: playSong called for: ${song.title}');

    // Try to initialize if not already initialized
    if (!_audioHandlerInitialized) {
      debugPrint('AudioPlayerService: Not initialized, attempting initialization...');
      try {
        await initialize();
      } catch (e) {
        debugPrint('AudioPlayerService: Initialization failed: $e');
        // Continue anyway - try to play without notification
      }
    }

    if (song.streamUrl == null || song.streamUrl!.isEmpty) {
      debugPrint('AudioPlayerService: Cannot play song - no stream URL');
      return false;
    }

    final current = _queueService.currentSong;
    if (current != null && current.id == song.id) {
      debugPrint('AudioPlayerService: Same song, resuming if paused');
      if (!_audioPlayer.playing) {
        await _audioPlayer.play();
      }
      return true;
    }

    final op = ++_playOp;

    await _recentService.addSong(song);
    await _queueService.playSong(song);

    if (op != _playOp) {
      debugPrint('AudioPlayerService: Operation cancelled');
      return false;
    }

    try {
      await _audioPlayer.stop();

      if (op != _playOp) return false;

      debugPrint('AudioPlayerService: Setting URL: ${song.streamUrl}');
      await _audioPlayer.setUrl(song.streamUrl!);

      if (op != _playOp) return false;

      // Only update media item if handler is initialized
      if (_audioHandlerInitialized) {
        _updateMediaItem(song);
      }

      debugPrint('AudioPlayerService: Starting playback');
      await _audioPlayer.play();

      debugPrint('AudioPlayerService: Playback started successfully');
      return true;
    } catch (e) {
      debugPrint('AudioPlayerService: Error playing song: $e');
      return false;
    }
  }

  void _setupCompletionListener() {
    _completionSub?.cancel();
    _completionSub = null;

    _completionSub = _audioPlayer.playerStateStream.listen((state) async {
      if (state.processingState != ProcessingState.completed) return;

      if (_handlingCompletion) return;

      _handlingCompletion = true;
      try {
        await playNext();
      } catch (e) {
        debugPrint('AudioPlayerService: Error in completion handler: $e');
      } finally {
        _handlingCompletion = false;
      }
    });
  }

  /// Setup audio interruption handling for device changes
  Future<void> _setupAudioInterruptionHandling() async {
    try {
      final session = await audio_session.AudioSession.instance;

      // Configure for music with Bluetooth support
      await session.configure(const audio_session.AudioSessionConfiguration(
        avAudioSessionCategory: audio_session.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: audio_session.AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
        androidAudioAttributes: audio_session.AndroidAudioAttributes(
          contentType: audio_session.AndroidAudioContentType.music,
          usage: audio_session.AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: audio_session.AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));

      // Handle audio interruptions (phone calls, other apps, device changes)
      _interruptionSub?.cancel();
      _interruptionSub = session.interruptionEventStream.listen((event) {
        debugPrint('AudioPlayerService: Interruption: begin=${event.begin}, type=${event.type}');

        if (event.begin) {
          // Interruption started
          switch (event.type) {
            case audio_session.AudioInterruptionType.duck:
              // Lower volume temporarily (don't pause)
              _audioPlayer.setVolume(0.4);
              break;
            case audio_session.AudioInterruptionType.pause:
              // Temporary pause (like phone call) - remember state
              _wasPlayingBeforeInterruption = _audioPlayer.playing;
              if (_wasPlayingBeforeInterruption) {
                _audioPlayer.pause();
              }
              break;
            case audio_session.AudioInterruptionType.unknown:
              // Device change or unknown - don't pause, just refresh
              debugPrint('AudioPlayerService: Unknown interruption - likely device change');
              break;
          }
        } else {
          // Interruption ended
          switch (event.type) {
            case audio_session.AudioInterruptionType.duck:
              // Restore volume
              _audioPlayer.setVolume(1.0);
              break;
            case audio_session.AudioInterruptionType.pause:
              // Resume if was playing before
              if (_wasPlayingBeforeInterruption) {
                _audioPlayer.play();
              }
              break;
            case audio_session.AudioInterruptionType.unknown:
              // Continue playing on device change
              break;
          }
        }
      });

      // Handle becoming noisy (headphones unplugged)
      _becomingNoisySub?.cancel();
      _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
        debugPrint('AudioPlayerService: Becoming noisy - headphones unplugged');
        // Pause when headphones are unplugged (standard behavior)
        _audioPlayer.pause();
      });

      debugPrint('AudioPlayerService: Audio interruption handling setup complete');
    } catch (e) {
      debugPrint('AudioPlayerService: Failed to setup interruption handling: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      // Check if audio source is loaded, if not load it from current song
      final song = _queueService.currentSong;
      if (song == null) {
        debugPrint('AudioPlayerService: No current song to play');
        return;
      }

      // If player is idle or completed, we need to load the URL
      if (_audioPlayer.processingState == ProcessingState.idle ||
          _audioPlayer.processingState == ProcessingState.completed) {
        if (song.streamUrl == null || song.streamUrl!.isEmpty) {
          debugPrint('AudioPlayerService: No stream URL for song: ${song.title}');
          return;
        }

        try {
          debugPrint('AudioPlayerService: Loading URL for: ${song.title}');
          await _audioPlayer.setUrl(song.streamUrl!);
          if (_audioHandlerInitialized) {
            _updateMediaItem(song);
          }
          _setupCompletionListener(); // Ensure completion listener is set
        } catch (e) {
          debugPrint('AudioPlayerService: Error loading URL: $e');
          return;
        }
      }

      await _audioPlayer.play();
    }
  }

  Future<void> play() async => _audioPlayer.play();
  Future<void> pause() async => _audioPlayer.pause();
  Future<void> stop() async {
    await _audioPlayer.stop();
    // Clear the notification by updating state to idle
    if (_audioHandlerInitialized && _audioHandler != null) {
      final handler = _audioHandler as _AudioPlayerHandler;
      handler.playbackState.add(PlaybackState(
        controls: [],
        systemActions: const {},
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      handler.mediaItem.add(null);
    }
  }

  /// Fully shutdown audio service - call when app is being closed
  Future<void> shutdown() async {
    await stop();
    await _completionSub?.cancel();
    _completionSub = null;
    await _interruptionSub?.cancel();
    _interruptionSub = null;
    await _becomingNoisySub?.cancel();
    _becomingNoisySub = null;

    // Stop the audio service to remove notification
    if (_audioHandlerInitialized && _audioHandler != null) {
      try {
        await _audioHandler!.stop();
      } catch (e) {
        debugPrint('AudioPlayerService: Error stopping handler: $e');
      }
    }

    await _audioPlayer.dispose();
    _audioHandlerInitialized = false;
    _audioHandler = null;
    _initializationCompleter = null;
  }
  Future<void> seek(Duration position) async => _audioPlayer.seek(position);

  Future<void> playNext() async {
    // If nothing is playing but we have a current song (after app restart), play it first
    if (_audioPlayer.processingState == ProcessingState.idle &&
        _queueService.currentSong != null &&
        !_audioPlayer.playing) {
      final currentSong = _queueService.currentSong!;
      if (currentSong.streamUrl != null && currentSong.streamUrl!.isNotEmpty) {
        try {
          await _audioPlayer.setUrl(currentSong.streamUrl!);
          if (_audioHandlerInitialized) {
            _updateMediaItem(currentSong);
          }
          await _audioPlayer.play();
          return;
        } catch (e) {
          debugPrint('AudioPlayerService: Error playing current song: $e');
        }
      }
    }

    Song? nextSong = await _queueService.playNext();

    if (nextSong == null) {
      final current = _queueService.currentSong;
      if (current != null) {
        await _queueService.loadMoreSimilar(current);
        nextSong = await _queueService.playNext();
      }
    }

    if (nextSong == null || nextSong.streamUrl?.isEmpty == true) return;

    await _recentService.addSong(nextSong);

    try {
      await _audioPlayer.setUrl(nextSong.streamUrl!);
      if (_audioHandlerInitialized) {
        _updateMediaItem(nextSong);
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('AudioPlayerService: Error playing next: $e');
    }
  }

  Future<void> playPrevious() async {
    // If nothing is playing but we have a current song (after app restart), play it
    if (_audioPlayer.processingState == ProcessingState.idle &&
        _queueService.currentSong != null &&
        !_audioPlayer.playing) {
      final currentSong = _queueService.currentSong!;
      if (currentSong.streamUrl != null && currentSong.streamUrl!.isNotEmpty) {
        try {
          await _audioPlayer.setUrl(currentSong.streamUrl!);
          if (_audioHandlerInitialized) {
            _updateMediaItem(currentSong);
          }
          await _audioPlayer.play();
          return;
        } catch (e) {
          debugPrint('AudioPlayerService: Error playing current song: $e');
        }
      }
    }

    if (_audioPlayer.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final previousSong = _queueService.playPrevious();
    if (previousSong == null || previousSong.streamUrl?.isEmpty == true) return;

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(previousSong.streamUrl!);
      if (_audioHandlerInitialized) {
        _updateMediaItem(previousSong);
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('AudioPlayerService: Error playing previous: $e');
    }
  }

  void addToQueue(Song song) => _queueService.addToQueue(song);
  void playNextInQueue(Song song) => _queueService.playNextInQueue(song);

  /// Skip to a specific position in the queue and start playing
  Future<void> skipToQueueItem(int index) async {
    final song = await _queueService.skipToQueueItem(index);
    if (song == null || song.streamUrl?.isEmpty == true) return;

    await _recentService.addSong(song);

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(song.streamUrl!);
      if (_audioHandlerInitialized) {
        _updateMediaItem(song);
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('AudioPlayerService: Error skipping to queue item: $e');
    }
  }

  /// Play a song from history
  Future<void> playFromHistory(Song song) async {
    final resultSong = await _queueService.playFromHistory(song);
    if (resultSong == null || resultSong.streamUrl?.isEmpty == true) return;

    await _recentService.addSong(resultSong);

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(resultSong.streamUrl!);
      if (_audioHandlerInitialized) {
        _updateMediaItem(resultSong);
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('AudioPlayerService: Error playing from history: $e');
    }
  }

  Future<void> setLoopMode(LoopMode mode) async => _audioPlayer.setLoopMode(mode);

  Future<void> setShuffleMode(bool enabled) async {
    if (enabled) _queueService.shuffleQueue();
  }

  Future<void> setVolume(double volume) async => _audioPlayer.setVolume(volume.clamp(0.0, 1.0));

  Future<void> dispose() async {
    // For backwards compatibility - just call shutdown
    await shutdown();
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

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;

  // Throttle position updates to reduce lag
  DateTime _lastPositionUpdate = DateTime.now();
  static const _positionUpdateInterval = Duration(seconds: 1);

  _AudioPlayerHandler(this._player, this._service) {
    debugPrint('_AudioPlayerHandler: Constructor called, setting up listeners...');

    // Listen to position changes - throttled
    _positionSubscription = _player.positionStream.listen((position) {
      final now = DateTime.now();
      if (now.difference(_lastPositionUpdate) >= _positionUpdateInterval) {
        _lastPositionUpdate = now;
        _updatePosition(position);
      }
    });

    // Listen to playing state changes
    _playingSubscription = _player.playingStream.listen((playing) {
      debugPrint('_AudioPlayerHandler: Playing state changed to: $playing');
      updatePlaybackStateForNotification(playing: playing);
    });

    debugPrint('_AudioPlayerHandler: Initialization complete');
  }

  @override
  BehaviorSubject<MediaItem?> get mediaItem => _mediaItemSubject;

  @override
  BehaviorSubject<PlaybackState> get playbackState => _playbackStateSubject;

  void _updatePosition(Duration position) {
    final current = _playbackStateSubject.value;
    _playbackStateSubject.add(current.copyWith(
      updatePosition: position,
    ));
  }

  void updatePlaybackStateForNotification({bool? playing}) {
    final current = _playbackStateSubject.value;
    final isPlaying = playing ?? current.playing;

    _playbackStateSubject.add(current.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: isPlaying,
      speed: 1.0,
    ));
  }

  @override
  Future<void> play() => _service.play();

  @override
  Future<void> pause() => _service.pause();

  @override
  Future<void> stop() async {
    await _player.pause();
    updatePlaybackStateForNotification(playing: false);
  }

  void dispose() {
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
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