import 'dart:async';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:rxdart/rxdart.dart';
import 'package:sangeet/services/queue.dart';
import 'package:sangeet/services/recently_played.dart';
import 'package:sangeet/services/music_service.dart';
import 'package:sangeet/services/taste_profile_service.dart';
import 'package:sangeet/utils/platform_utils.dart';
import '../models/song.dart';

AudioHandler? _audioHandler;
bool _audioHandlerInitialized = false;
bool _audioInitialized = false;
Completer<void>? _initializationCompleter;

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal() {
    _bindPlayerStreams();
  }

  AudioPlayer _audioPlayer = AudioPlayer();
  final QueueService _queueService = QueueService();
  final RecentlyPlayedService _recentService = RecentlyPlayedService();

  // ── Stable streams ───────────────────────────────────────────────────────
  final BehaviorSubject<Duration> _positionSubject =
  BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration?> _durationSubject =
  BehaviorSubject<Duration?>.seeded(null);
  final BehaviorSubject<PlayerState> _playerStateSubject =
  BehaviorSubject<PlayerState>.seeded(
      PlayerState(false, ProcessingState.idle));
  final BehaviorSubject<bool> _playingSubject =
  BehaviorSubject<bool>.seeded(false);

  StreamSubscription<Duration>? _positionFwd;
  StreamSubscription<Duration?>? _durationFwd;
  StreamSubscription<PlayerState>? _playerStateFwd;
  StreamSubscription<bool>? _playingFwd;

  StreamSubscription<PlayerState>? _completionSub;
  StreamSubscription<audio_session.AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;

  bool _wasPlayingBeforeInterruption = false;

  // Desktop: transition guard
  bool _desktopTransitionInProgress = false;
  Completer<void>? _transitionCompleter;

  // Desktop player fields
  double _lastVolume = 1.0;
  LoopMode _lastLoopMode = LoopMode.off;

  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(
    useLazyPreparation: true,
    children: [],
  );
  bool _playlistInitialized = false;

  AudioPlayer get player => _audioPlayer;
  Song? get currentSong => _queueService.currentSong;
  QueueService get queue => _queueService;

  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<Duration?> get durationStream => _durationSubject.stream;
  Stream<PlayerState> get playerStateStream => _playerStateSubject.stream;
  Stream<bool> get playingStream => _playingSubject.stream;

  bool get isPlaying => _audioPlayer.playing;
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _audioPlayer.duration;

  void _bindPlayerStreams() {
    _positionFwd?.cancel();
    _durationFwd?.cancel();
    _playerStateFwd?.cancel();
    _playingFwd?.cancel();

    _positionSubject.add(_audioPlayer.position);
    _durationSubject.add(_audioPlayer.duration);
    _playerStateSubject.add(_audioPlayer.playerState);
    _playingSubject.add(_audioPlayer.playing);

    _positionFwd = _audioPlayer.positionStream.listen(_positionSubject.add);
    _durationFwd = _audioPlayer.durationStream.listen(_durationSubject.add);
    _playerStateFwd =
        _audioPlayer.playerStateStream.listen(_playerStateSubject.add);
    _playingFwd = _audioPlayer.playingStream.listen(_playingSubject.add);
  }

  // ── Initialization ───────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_audioInitialized) return;

    if (_initializationCompleter != null) {
      try {
        await _initializationCompleter!.future;
        return;
      } catch (_) {}
    }

    _initializationCompleter = Completer<void>();

    try {
      if (PlatformUtils.isMobile) {
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
      } else {
        debugPrint('AudioPlayerService: Desktop — skipping AudioService.init');
        _audioHandlerInitialized = false;
      }

      _setupCompletionListener();

      if (PlatformUtils.isMobile) {
        await _setupAudioInterruptionHandling();
      }

      _audioInitialized = true;
      _initializationCompleter!.complete();
      debugPrint('AudioPlayerService: initialized');
    } catch (e, st) {
      debugPrint('AudioPlayerService: init failed: $e\n$st');
      _audioHandlerInitialized = false;
      _audioInitialized = false;
      _audioHandler = null;
      _initializationCompleter!.completeError(e);
      _initializationCompleter = null;
      rethrow;
    }
  }

  // ── Desktop playlist helpers ─────────────────────────────────────────────

  Future<void> _ensurePlaylistInitialized() async {
    if (_playlistInitialized) return;
    _playlistInitialized = true;
    await _audioPlayer.setAudioSource(_playlist, preload: false);
  }

  Future<void> _swapTrack(AudioSource source) async {
    await _ensurePlaylistInitialized();
    await _playlist.clear();
    await _playlist.add(source);
    await _audioPlayer.seek(Duration.zero, index: 0);
  }

  Future<void> _recreateWindowsPlayer() async {
    if (!PlatformUtils.isWindows) return;

    final oldPlayer = _audioPlayer;
    _completionSub?.cancel();
    _positionFwd?.cancel();
    _durationFwd?.cancel();
    _playerStateFwd?.cancel();
    _playingFwd?.cancel();

    try { await oldPlayer.stop(); } catch (_) {}
    try { await oldPlayer.dispose(); } catch (_) {}

    _audioPlayer = AudioPlayer();
    try {
      await _audioPlayer.setVolume(_lastVolume);
      await _audioPlayer.setLoopMode(_lastLoopMode);
    } catch (_) {}

    _bindPlayerStreams();
    _setupCompletionListener();
  }

  // ── Completion listener ──────────────────────────────────────────────────
  //
  // On mobile: cancelled before stop() and re-subscribed after setUrl().
  // After setUrl() the player is in `loading` state (not `completed`), so
  // the BehaviorSubject does NOT replay a stale `completed` event to the
  // new subscriber. The new subscriber only sees genuine end-of-song events.
  //
  // On desktop: uses _desktopTransitionInProgress flag as before.

  void _setupCompletionListener() {
    _completionSub?.cancel();
    _completionSub = _audioPlayer.playerStateStream.listen((state) async {
      if (state.processingState != ProcessingState.completed) return;
      if (!PlatformUtils.isMobile && _desktopTransitionInProgress) return;

      debugPrint('AudioPlayerService: song ended naturally, advancing…');
      await _advanceToNextSong();
    });
  }

  // ── Advance to next song ─────────────────────────────────────────────────

  Future<void> _advanceToNextSong() async {
    // Cancel the completion listener immediately so re-entrancy is impossible.
    // It will be re-attached inside _mobilePlaySong after setUrl().
    if (PlatformUtils.isMobile) {
      _completionSub?.cancel();
      _completionSub = null;
    }

    if (!_queueService.hasNext && _queueService.isLoadingSimilar) {
      debugPrint('AudioPlayerService: queue empty but loading, waiting…');
      const pollInterval = Duration(milliseconds: 200);
      const maxWait = Duration(seconds: 8);
      var waited = Duration.zero;
      while (_queueService.isLoadingSimilar && waited < maxWait) {
        await Future.delayed(pollInterval);
        waited += pollInterval;
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

    if (nextSong == null) {
      debugPrint('AudioPlayerService: queue empty, stopping');
      // Re-attach listener so future plays work (e.g. user adds songs manually)
      if (PlatformUtils.isMobile) _setupCompletionListener();
      return;
    }

    debugPrint('AudioPlayerService: auto-advancing to ${nextSong.title}');

    if (PlatformUtils.isMobile) {
      await _mobilePlaySong(nextSong);
    } else {
      await _withTransitionLock(() => _desktopPlaySong(nextSong!));
    }
  }

  // ── Mobile play ──────────────────────────────────────────────────────────

  Future<bool> _mobilePlaySong(Song song) async {
    final src = song.streamUrl;
    if (src == null || src.isEmpty) {
      debugPrint(
          'AudioPlayerService: [mobile] no stream URL for ${song.title}');
      if (_completionSub == null) _setupCompletionListener();
      return false;
    }

    try { await _recentService.addSong(song); } catch (_) {}
    TasteProfileService().rebuildProfile(recentService: _recentService);

    // Cancel listener before stop() so the stop()-induced `completed` event
    // is never delivered. The listener doesn't exist during the transition.
    _completionSub?.cancel();
    _completionSub = null;

    try {
      await _audioPlayer.stop();

      // After stop(), player is in `idle` state.
      await _audioPlayer.setUrl(src);

      // After setUrl(), player is in `loading` state — NOT `completed`.
      // It is now safe to re-subscribe: the BehaviorSubject will replay
      // `loading`, not `completed`, so no phantom advance fires.
      _setupCompletionListener();

      if (_audioHandlerInitialized) _updateMediaItem(song);
      await _audioPlayer.play();

      debugPrint('AudioPlayerService: [mobile] playing ${song.title}');
      return true;
    } catch (e) {
      // Always ensure listener is attached even on error.
      if (_completionSub == null) _setupCompletionListener();
      debugPrint('AudioPlayerService: [mobile] error: $e');
      return false;
    }
  }

  // ── Desktop play ─────────────────────────────────────────────────────────

  Future<bool> _desktopPlaySong(Song song) async {
    final audioSource = await _getDesktopSource(song);
    if (audioSource == null) return false;

    _desktopTransitionInProgress = true;
    try {
      if (PlatformUtils.isWindows) {
        await _recreateWindowsPlayer();
        await _audioPlayer.setAudioSource(audioSource, preload: true);
      } else {
        await _swapTrack(audioSource);
      }
      if (_audioHandlerInitialized) _updateMediaItem(song);
      await _audioPlayer.play();
      debugPrint('AudioPlayerService: [desktop] playing ${song.title}');
      return true;
    } catch (e) {
      debugPrint('AudioPlayerService: [desktop] error: $e');
      return false;
    } finally {
      _desktopTransitionInProgress = false;
    }
  }

  Future<AudioSource?> _getDesktopSource(Song song) async {
    try {
      return await MusicService().getAudioSource(song);
    } catch (e) {
      debugPrint('AudioPlayerService: _getDesktopSource error: $e');
      return null;
    }
  }

  Future<T> _withTransitionLock<T>(Future<T> Function() action) async {
    final previous = _transitionCompleter?.future;
    final mine = Completer<void>();
    _transitionCompleter = mine;
    if (previous != null) await previous.catchError((_) {});
    try {
      return await action();
    } finally {
      if (!mine.isCompleted) mine.complete();
    }
  }

  // ── Media item update ────────────────────────────────────────────────────

  void _updateMediaItem(Song song) {
    if (!_audioHandlerInitialized || _audioHandler == null) return;
    try {
      final mediaItem = MediaItem(
        id: song.id,
        album: 'Sangeet',
        title: song.title,
        artist: song.artist,
        duration: song.duration,
        artUri: song.coverUrl.isNotEmpty ? Uri.parse(song.coverUrl) : null,
      );
      final handler = _audioHandler as _AudioPlayerHandler;
      handler.mediaItem.add(mediaItem);
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
    } catch (e) {
      debugPrint('AudioPlayerService: _updateMediaItem error: $e');
    }
  }

  // ── playSong ─────────────────────────────────────────────────────────────

  Future<bool> playSong(Song song) async {
    debugPrint('AudioPlayerService: playSong: ${song.title}');

    if (!_audioInitialized) {
      try { await initialize(); } catch (e) {
        debugPrint('AudioPlayerService: init failed: $e');
      }
    }

    final current = _queueService.currentSong;
    if (current != null && current.id == song.id) {
      if (!_audioPlayer.playing) await _audioPlayer.play();
      return true;
    }

    try {
      await _queueService.playSong(song);
    } catch (e) {
      debugPrint('AudioPlayerService: queue update failed: $e');
      return false;
    }

    if (PlatformUtils.isMobile) {
      return _mobilePlaySong(song);
    } else {
      return _withTransitionLock(() => _desktopPlaySong(song));
    }
  }

  // ── Playback controls ────────────────────────────────────────────────────

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      return;
    }

    final song = _queueService.currentSong;
    if (song == null) return;

    if (_audioPlayer.processingState == ProcessingState.idle ||
        _audioPlayer.processingState == ProcessingState.completed) {
      if (PlatformUtils.isMobile) {
        await _audioPlayer.play();
      } else {
        await _withTransitionLock(() => _desktopPlaySong(song));
      }
      return;
    }

    await _audioPlayer.play();
  }

  Future<void> play() async {
    if (_audioPlayer.playing) return;

    final song = _queueService.currentSong;
    if (song == null) return;

    if (_audioPlayer.processingState == ProcessingState.idle ||
        _audioPlayer.processingState == ProcessingState.completed) {
      if (PlatformUtils.isMobile) {
        await _audioPlayer.play();
      } else {
        await _withTransitionLock(() => _desktopPlaySong(song));
      }
      return;
    }

    await _audioPlayer.play();
  }

  Future<void> pause() async => _audioPlayer.pause();

  Future<void> stop() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('AudioPlayerService: stop() error: $e');
    }
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

  Future<void> seek(Duration position) async => _audioPlayer.seek(position);

  Future<void> playNext() async {
    Song? nextSong = await _queueService.playNext();

    if (nextSong == null) {
      final current = _queueService.currentSong;
      if (current != null) {
        await _queueService.loadMoreSimilar(current);
        nextSong = await _queueService.playNext();
      }
    }

    if (nextSong == null) return;

    if (PlatformUtils.isMobile) {
      await _mobilePlaySong(nextSong);
    } else {
      await _withTransitionLock(() => _desktopPlaySong(nextSong!));
    }
  }

  Future<void> playPrevious() async {
    if (_audioPlayer.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    final prev = _queueService.playPrevious();
    if (prev == null) return;

    if (PlatformUtils.isMobile) {
      await _mobilePlaySong(prev);
    } else {
      await _withTransitionLock(() => _desktopPlaySong(prev));
    }
  }

  Future<void> skipToQueueItem(int index) async {
    final song = await _queueService.skipToQueueItem(index);
    if (song == null) return;

    if (PlatformUtils.isMobile) {
      await _mobilePlaySong(song);
    } else {
      await _withTransitionLock(() => _desktopPlaySong(song));
    }
  }

  Future<void> playFromHistory(Song song) async {
    final result = await _queueService.playFromHistory(song);
    if (result == null) return;

    if (PlatformUtils.isMobile) {
      await _mobilePlaySong(result);
    } else {
      await _withTransitionLock(() => _desktopPlaySong(result));
    }
  }

  void addToQueue(Song song) => _queueService.addToQueue(song);
  void playNextInQueue(Song song) => _queueService.playNextInQueue(song);

  Future<void> setLoopMode(LoopMode mode) async {
    _lastLoopMode = mode;
    await _audioPlayer.setLoopMode(mode);
  }

  Future<void> setShuffleMode(bool enabled) async {
    if (enabled) _queueService.shuffleQueue();
  }

  Future<void> setVolume(double volume) async {
    _lastVolume = volume.clamp(0.0, 1.0);
    await _audioPlayer.setVolume(_lastVolume);
  }

  // ── Audio interruption handling (mobile only) ────────────────────────────

  Future<void> _setupAudioInterruptionHandling() async {
    try {
      final session = await audio_session.AudioSession.instance;
      await session.configure(
        const audio_session.AudioSessionConfiguration(
          avAudioSessionCategory:
          audio_session.AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
          audio_session.AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
          androidAudioAttributes: audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.music,
            usage: audio_session.AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
          audio_session.AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );

      _interruptionSub?.cancel();
      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case audio_session.AudioInterruptionType.duck:
              _audioPlayer.setVolume(0.4);
            case audio_session.AudioInterruptionType.pause:
              _wasPlayingBeforeInterruption = _audioPlayer.playing;
              if (_wasPlayingBeforeInterruption) _audioPlayer.pause();
            case audio_session.AudioInterruptionType.unknown:
              break;
          }
        } else {
          switch (event.type) {
            case audio_session.AudioInterruptionType.duck:
              _audioPlayer.setVolume(1.0);
            case audio_session.AudioInterruptionType.pause:
              if (_wasPlayingBeforeInterruption) _audioPlayer.play();
            case audio_session.AudioInterruptionType.unknown:
              break;
          }
        }
      });

      _becomingNoisySub?.cancel();
      _becomingNoisySub =
          session.becomingNoisyEventStream.listen((_) => _audioPlayer.pause());
    } catch (e) {
      debugPrint('AudioPlayerService: interruption setup failed: $e');
    }
  }

  // ── Shutdown ─────────────────────────────────────────────────────────────

  Future<void> shutdown() async {
    await stop();
    _completionSub?.cancel();
    _interruptionSub?.cancel();
    _becomingNoisySub?.cancel();
    _positionFwd?.cancel();
    _durationFwd?.cancel();
    _playerStateFwd?.cancel();
    _playingFwd?.cancel();

    if (_audioHandlerInitialized && _audioHandler != null) {
      try { await _audioHandler!.stop(); } catch (_) {}
    }

    try { await _audioPlayer.dispose(); } catch (_) {}

    _audioHandlerInitialized = false;
    _audioInitialized = false;
    _audioHandler = null;
    _initializationCompleter = null;
    _playlistInitialized = false;
  }

  Future<void> dispose() async => shutdown();
}

// ── Media notification handler (mobile only) ─────────────────────────────────

class _AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  final AudioPlayerService _service;

  final BehaviorSubject<MediaItem?> _mediaItemSubject =
  BehaviorSubject<MediaItem?>();
  final BehaviorSubject<PlaybackState> _playbackStateSubject =
  BehaviorSubject<PlaybackState>.seeded(
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

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  DateTime _lastPositionUpdate = DateTime.now();
  static const _positionUpdateInterval = Duration(seconds: 1);

  _AudioPlayerHandler(this._player, this._service) {
    _positionSub = _player.positionStream.listen((position) {
      final now = DateTime.now();
      if (now.difference(_lastPositionUpdate) >= _positionUpdateInterval) {
        _lastPositionUpdate = now;
        final current = _playbackStateSubject.value;
        _playbackStateSubject.add(current.copyWith(updatePosition: position));
      }
    });

    _playingSub = _player.playingStream.listen((playing) {
      updatePlaybackStateForNotification(playing: playing);
    });
  }

  @override
  BehaviorSubject<MediaItem?> get mediaItem => _mediaItemSubject;

  @override
  BehaviorSubject<PlaybackState> get playbackState => _playbackStateSubject;

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
    _positionSub?.cancel();
    _playingSub?.cancel();
  }

  @override
  Future<void> seek(Duration position) => _service.seek(position);
  @override
  Future<void> skipToNext() => _service.playNext();
  @override
  Future<void> skipToPrevious() => _service.playPrevious();
  @override
  Future<void> fastForward() =>
      _service.seek(_player.position + const Duration(seconds: 10));
  @override
  Future<void> rewind() =>
      _service.seek(_player.position - const Duration(seconds: 10));
}