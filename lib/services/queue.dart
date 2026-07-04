import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'remote_music_service.dart';
import 'taste_profile_service.dart';

class QueueService extends ChangeNotifier {
  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  final RemoteMusicService _musicService = RemoteMusicService(
    'https://vercelapi-gamma.vercel.app/api',
  );
  final TasteProfileService _tasteService = TasteProfileService();

  Song? _currentSong;
  final Queue<Song> _upNext = Queue<Song>();
  final List<Song> _history = [];

  // Tracks songs the user explicitly queued (so we don't wipe them when refreshing suggestions)
  final Set<String> _manualQueueIds = <String>{};

  static const int _maxHistorySize = 50;
  bool _isLoadingSimilar = false;

  // Completer that resolves when the current _loadSimilarSongs call finishes.
  // Callers that need to wait (loadMoreSimilar) await this instead of polling.
  Completer<void>? _loadingSimilarCompleter;

  /// Timestamp when the current song started playing — used for skip detection.
  DateTime? _lastPlayStartTime;

  Song? get currentSong => _currentSong;
  List<Song> get upNext => _upNext.toList();
  List<Song> get history => List.unmodifiable(_history);
  bool get hasNext => _upNext.isNotEmpty;
  bool get hasPrevious => _history.isNotEmpty;
  bool get isLoadingSimilar => _isLoadingSimilar;

  Future<void> playSong(Song song, {bool addToHistory = true}) async {
    if (_currentSong != null && addToHistory) {
      _addToHistory(_currentSong!);
    }

    final previousId = _currentSong?.id;
    _currentSong = song;
    _lastPlayStartTime = DateTime.now();
    notifyListeners();

    // Count how many manual (playlist) songs are in the queue
    final manualSongsInQueue =
        _upNext.where((s) => _manualQueueIds.contains(s.id)).length;

    // If the user picked a different song (often from another genre/artist),
    // refresh "similar" suggestions so Up Next matches the new context.
    // Preserve any manually queued items.
    // NOTE: Don't await — fire-and-forget so audio playback starts immediately.
    if (previousId == null || previousId != song.id) {
      if (manualSongsInQueue == 0) {
        unawaited(refreshSimilarForCurrent(resetAutoQueue: true));
      } else {
        debugPrint(
          'QueueService.playSong: Skipping similar songs load - $manualSongsInQueue manual songs in queue',
        );
      }
    } else {
      if (_upNext.isEmpty) {
        unawaited(_loadSimilarSongs(song));
      }
    }
  }

  /// Clears the auto-generated (suggested) part of the queue and re-loads
  /// suggestions for the current song.
  ///
  /// Manual queue items are preserved.
  Future<void> refreshSimilarForCurrent({bool resetAutoQueue = true}) async {
    final song = _currentSong;
    if (song == null) return;

    if (resetAutoQueue) {
      // Keep only manual items; drop old suggestions that were based on a different song.
      final preserved =
      _upNext.where((s) => _manualQueueIds.contains(s.id)).toList();
      _upNext
        ..clear()
        ..addAll(preserved);
      notifyListeners();
    }

    // Don't re-fetch if we're already loading.
    if (_isLoadingSimilar) return;

    await _loadSimilarSongs(song);
  }

  /// Waits for any in-progress load to finish, then triggers a fresh load.
  /// Replaces the old busy-loop polling with a proper Completer await.
  Future<void> loadMoreSimilar(Song song) async {
    if (_isLoadingSimilar && _loadingSimilarCompleter != null) {
      // Wait for the current load to complete rather than spinning.
      await _loadingSimilarCompleter!.future.catchError((_) {});
    }
    // Only load if the queue is still empty after waiting.
    if (_upNext.isEmpty) {
      await _loadSimilarSongs(song);
    }
  }

  Future<Song?> playNext() async {
    debugPrint(
      'QueueService.playNext: hasNext=$hasNext, queue length=${_upNext.length}',
    );

    if (!hasNext) {
      // If suggestions are still loading, wait for them to finish.
      if (_isLoadingSimilar && _loadingSimilarCompleter != null) {
        debugPrint('QueueService.playNext: waiting for similar songs…');
        await _loadingSimilarCompleter!.future.catchError((_) {});
      }
      if (!hasNext) {
        debugPrint('QueueService.playNext: Queue is empty, returning null');
        return null;
      }
    }

    // Detect skip: if the previous song played for < 30 seconds, record it
    if (_currentSong != null && _lastPlayStartTime != null) {
      final elapsed = DateTime.now().difference(_lastPlayStartTime!);
      if (elapsed.inSeconds < 30) {
        _tasteService.recordSkip(_currentSong!.id);
        debugPrint(
          'QueueService: Detected skip for "${_currentSong!.title}" (${elapsed.inSeconds}s)',
        );
      }
      _addToHistory(_currentSong!);
    }

    Song next;
    try {
      next = _upNext.removeFirst();
    } on StateError {
      debugPrint(
        'QueueService.playNext: removeFirst failed due to concurrent queue mutation',
      );
      return null;
    }

    while ((next.streamUrl == null || next.streamUrl!.isEmpty) &&
        _upNext.isNotEmpty) {
      debugPrint(
        'QueueService.playNext: Skipping unplayable queued song: ${next.title}',
      );
      _manualQueueIds.remove(next.id);
      try {
        next = _upNext.removeFirst();
      } on StateError {
        debugPrint(
          'QueueService.playNext: removeFirst failed while skipping unplayable songs',
        );
        return null;
      }
    }

    if (next.streamUrl == null || next.streamUrl!.isEmpty) {
      debugPrint('QueueService.playNext: No playable song found in queue');
      _manualQueueIds.remove(next.id);
      notifyListeners();
      return null;
    }

    // Consumed; if it was a manual item, unmark it.
    _manualQueueIds.remove(next.id);

    _currentSong = next;
    _lastPlayStartTime = DateTime.now();

    debugPrint(
      'QueueService.playNext: Set current song to ${next.title}, remaining queue: ${_upNext.length}',
    );

    // Count how many manual (playlist) songs remain in queue
    final manualSongsRemaining =
        _upNext.where((s) => _manualQueueIds.contains(s.id)).length;
    debugPrint(
      'QueueService.playNext: Manual songs remaining in queue: $manualSongsRemaining',
    );

    // Only load similar songs if:
    // 1. Queue is getting low (< 3 songs), AND
    // 2. There are no manual (playlist) songs remaining
    // NOTE: Don't await — load in background so playback isn't blocked.
    if (_upNext.length < 3 &&
        manualSongsRemaining == 0 &&
        _currentSong != null) {
      debugPrint(
        'QueueService.playNext: Queue low (${_upNext.length}) and no manual songs, loading similar songs in background…',
      );
      unawaited(_loadSimilarSongs(_currentSong!));
    }

    notifyListeners();

    return _currentSong;
  }

  Song? playPrevious() {
    if (!hasPrevious) return null;

    if (_currentSong != null) {
      _upNext.addFirst(_currentSong!);
      _manualQueueIds.remove(_currentSong!.id);
    }

    _currentSong = _history.removeLast();
    notifyListeners();

    return _currentSong;
  }

  void addToQueue(Song song) {
    _manualQueueIds.add(song.id);
    _upNext.add(song);
    notifyListeners();
  }

  void playNextInQueue(Song song) {
    _manualQueueIds.add(song.id);
    _upNext.addFirst(song);
    notifyListeners();
  }

  void addAllToQueue(List<Song> songs) {
    for (final s in songs) {
      _manualQueueIds.add(s.id);
    }
    _upNext.addAll(songs);
    notifyListeners();
  }

  void clearQueue() {
    _upNext.clear();
    _manualQueueIds.clear();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  /// Set the last played song without starting playback.
  void setLastPlayedSong(Song song) {
    if (_currentSong == null) {
      _currentSong = song;
      notifyListeners();
    }
  }

  /// Blended auto-fill: combines contextual similarity (Saavn suggestions for
  /// the current song) with taste-based exploration (top-affinity artists from
  /// the user's taste profile).  Results are re-ranked by taste affinity,
  /// deduplicated, and diversity-capped.
  Future<void> _loadSimilarSongs(Song song) async {
    if (_isLoadingSimilar) {
      debugPrint('QueueService._loadSimilarSongs: Already loading, skipping');
      return;
    }

    debugPrint(
      'QueueService._loadSimilarSongs: Loading blended queue for "${song.title}" (${song.id})',
    );
    _isLoadingSimilar = true;
    _loadingSimilarCompleter = Completer<void>();
    notifyListeners();

    try {
      final futures = <Future<List<Song>>>[];

      // 1. Contextual: Saavn suggestions for the current song
      futures.add(_musicService.getSongSuggestions(song.id));

      // 2. Taste-based exploration: search for 1-2 top-affinity artists
      final topArtists = _tasteService.topArtists(3);
      final currentArtist =
      song.artist.split(RegExp(r'[,&]')).first.trim().toLowerCase();
      final explorationArtists =
      topArtists.where((a) => a != currentArtist).take(2);
      for (final artist in explorationArtists) {
        futures.add(_musicService.searchSongs(artist));
      }

      final results = await Future.wait(futures);
      debugPrint(
        'QueueService._loadSimilarSongs: Got ${results.map((r) => r.length).join(", ")} results from ${results.length} sources',
      );

      // Merge all results, dedup by id
      final allCandidates = <Song>[];
      final seenIds = <String>{};
      for (final batch in results) {
        for (final s in batch) {
          if (seenIds.add(s.id)) allCandidates.add(s);
        }
      }

      // Filter out songs already in queue, history, or current
      final existingIds = <String>{
        ..._upNext.map((s) => s.id),
        ..._history.map((s) => s.id),
        if (_currentSong != null) _currentSong!.id,
      };

      var filtered = allCandidates.where((s) {
        return !existingIds.contains(s.id) &&
            s.streamUrl != null &&
            s.streamUrl!.isNotEmpty &&
            !_tasteService.isOverplayed(s.id) &&
            !_tasteService.wasSkipped(s.id);
      }).toList();

      // Re-rank by taste affinity
      if (_tasteService.hasProfile && filtered.isNotEmpty) {
        filtered.sort((a, b) {
          final aScore = _tasteService.affinityScore(a);
          final bScore = _tasteService.affinityScore(b);
          return bScore.compareTo(aScore);
        });
      }

      // Enforce diversity: max 2 songs per artist in auto-queue
      final artistCount = <String, int>{};
      final diverse = <Song>[];
      for (final s in filtered) {
        final artist =
        s.artist.split(RegExp(r'[,&]')).first.trim().toLowerCase();
        final count = artistCount[artist] ?? 0;
        if (count < 2) {
          diverse.add(s);
          artistCount[artist] = count + 1;
        }
      }

      debugPrint(
        'QueueService._loadSimilarSongs: After filtering & diversity, ${diverse.length} songs available',
      );
      _upNext.addAll(diverse.take(10));
      debugPrint(
        'QueueService._loadSimilarSongs: Queue now has ${_upNext.length} songs',
      );

      _loadingSimilarCompleter!.complete();
    } catch (e) {
      debugPrint('QueueService._loadSimilarSongs: Error: $e');
      _loadingSimilarCompleter!.completeError(e);
    } finally {
      _isLoadingSimilar = false;
      _loadingSimilarCompleter = null;
      notifyListeners();
    }
  }

  void _addToHistory(Song song) {
    _history.removeWhere((s) => s.id == song.id);
    _history.add(song);

    if (_history.length > _maxHistorySize) {
      _history.removeRange(0, _history.length - _maxHistorySize);
    }
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= _upNext.length) return;

    final list = _upNext.toList();
    final removed = list.removeAt(index);
    _manualQueueIds.remove(removed.id);

    _upNext
      ..clear()
      ..addAll(list);

    notifyListeners();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final list = _upNext.toList();

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    _upNext
      ..clear()
      ..addAll(list);

    notifyListeners();
  }

  void shuffleQueue() {
    final list = _upNext.toList()..shuffle();
    _upNext
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  /// Skip to a specific position in the queue and play that song
  Future<Song?> skipToQueueItem(int index) async {
    if (index < 0 || index >= _upNext.length) return null;

    final list = _upNext.toList();

    if (_currentSong != null) {
      _addToHistory(_currentSong!);
    }

    final targetSong = list[index];
    final songsToHistory = list.sublist(0, index);

    for (final song in songsToHistory) {
      _addToHistory(song);
      _manualQueueIds.remove(song.id);
    }

    _manualQueueIds.remove(targetSong.id);

    final remainingQueue = list.sublist(index + 1);
    _upNext
      ..clear()
      ..addAll(remainingQueue);

    _currentSong = targetSong;

    if (_upNext.length < 3 && _currentSong != null) {
      await _loadSimilarSongs(_currentSong!);
    }

    notifyListeners();
    return _currentSong;
  }

  /// Play a song from history
  Future<Song?> playFromHistory(Song song) async {
    if (_currentSong != null) {
      _addToHistory(_currentSong!);
    }

    _currentSong = song;

    if (_upNext.isEmpty) {
      await _loadSimilarSongs(song);
    }

    notifyListeners();
    return _currentSong;
  }

  void reset() {
    _currentSong = null;
    _upNext.clear();
    _history.clear();
    _manualQueueIds.clear();
    _isLoadingSimilar = false;
    _loadingSimilarCompleter = null;
    notifyListeners();
  }
}