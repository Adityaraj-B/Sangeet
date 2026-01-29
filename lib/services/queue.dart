import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'remote_music_service.dart';

class QueueService extends ChangeNotifier {
  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  final RemoteMusicService _musicService =
  RemoteMusicService('https://vercelapi-gamma.vercel.app/api');

  Song? _currentSong;
  final Queue<Song> _upNext = Queue<Song>();
  final List<Song> _history = [];

  // Tracks songs the user explicitly queued (so we don't wipe them when refreshing suggestions)
  final Set<String> _manualQueueIds = <String>{};

  static const int _maxHistorySize = 50;
  bool _isLoadingSimilar = false;

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
    notifyListeners();

    // If the user picked a different song (often from another genre/artist),
    // refresh "similar" suggestions so Up Next matches the new context.
    // Preserve any manually queued items.
    if (previousId == null || previousId != song.id) {
      await refreshSimilarForCurrent(resetAutoQueue: true);
    } else {
      // Same song selected again; if we have no queue, ensure it's populated.
      if (_upNext.isEmpty) {
        await _loadSimilarSongs(song);
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
      final preserved = _upNext.where((s) => _manualQueueIds.contains(s.id)).toList();
      _upNext
        ..clear()
        ..addAll(preserved);
      notifyListeners();
    }

    // Don't re-fetch if we're already loading.
    if (_isLoadingSimilar) return;

    await _loadSimilarSongs(song);
  }

  Future<void> loadMoreSimilar(Song song) async {
    // Don't skip if already loading - instead wait for it to complete
    while (_isLoadingSimilar) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await _loadSimilarSongs(song);
  }

  Future<Song?> playNext() async {
    print('QueueService.playNext: hasNext=$hasNext, queue length=${_upNext.length}');

    if (!hasNext) {
      print('QueueService.playNext: Queue is empty, returning null');
      return null;
    }

    if (_currentSong != null) {
      _addToHistory(_currentSong!);
    }

    final next = _upNext.removeFirst();
    // Consumed; if it was a manual item, unmark it.
    _manualQueueIds.remove(next.id);

    _currentSong = next;

    print('QueueService.playNext: Set current song to ${next.title}, remaining queue: ${_upNext.length}');

    // Load more similar songs if queue is getting low
    if (_upNext.length < 3 && _currentSong != null) {
      print('QueueService.playNext: Queue low (${_upNext.length}), loading similar songs...');
      await _loadSimilarSongs(_currentSong!);
      print('QueueService.playNext: After loading, queue length: ${_upNext.length}');
    }

    notifyListeners();

    return _currentSong;
  }

  Song? playPrevious() {
    if (!hasPrevious) return null;

    if (_currentSong != null) {
      _upNext.addFirst(_currentSong!);
      // This is part of navigation history, not a manual queue action.
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
  /// Used to show the last song in mini player when app opens.
  void setLastPlayedSong(Song song) {
    if (_currentSong == null) {
      _currentSong = song;
      notifyListeners();
    }
  }

  Future<void> _loadSimilarSongs(Song song) async {
    if (_isLoadingSimilar) {
      print('QueueService._loadSimilarSongs: Already loading, skipping');
      return;
    }

    print('QueueService._loadSimilarSongs: Loading similar songs for ${song.title} (${song.id})');
    _isLoadingSimilar = true;
    notifyListeners();

    try {
      final suggestions = await _musicService.getSongSuggestions(song.id);
      print('QueueService._loadSimilarSongs: Received ${suggestions.length} suggestions');

      final newSongs = suggestions.where((s) {
        return !_upNext.any((q) => q.id == s.id) &&
            !_history.any((h) => h.id == s.id) &&
            _currentSong?.id != s.id;
      }).toList();

      print('QueueService._loadSimilarSongs: After filtering, ${newSongs.length} new songs to add');
      _upNext.addAll(newSongs.take(10));
      print('QueueService._loadSimilarSongs: Added songs, queue now has ${_upNext.length} songs');
    } catch (e) {
      print('QueueService._loadSimilarSongs: Error loading similar songs: $e');
    } finally {
      _isLoadingSimilar = false;
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

    // Add current song to history if it exists
    if (_currentSong != null) {
      _addToHistory(_currentSong!);
    }

    // Get the song at the specified index
    final targetSong = list[index];

    // Remove all songs before and including the target index
    final songsToHistory = list.sublist(0, index);

    // Add skipped songs to history (in order)
    for (final song in songsToHistory) {
      _addToHistory(song);
      _manualQueueIds.remove(song.id);
    }

    // Remove the target song from manual queue tracking
    _manualQueueIds.remove(targetSong.id);

    // Update the queue to only have songs after the target
    final remainingQueue = list.sublist(index + 1);
    _upNext
      ..clear()
      ..addAll(remainingQueue);

    // Set the target song as current
    _currentSong = targetSong;

    // Load more similar songs if queue is getting low
    if (_upNext.length < 3 && _currentSong != null) {
      await _loadSimilarSongs(_currentSong!);
    }

    notifyListeners();
    return _currentSong;
  }

  /// Play a song from history
  Future<Song?> playFromHistory(Song song) async {
    // Add current song to history if it exists
    if (_currentSong != null) {
      _addToHistory(_currentSong!);
    }

    // Set the selected song as current
    _currentSong = song;

    // Ensure we have songs in the queue
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
    notifyListeners();
  }
}
