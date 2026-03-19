import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';
import '../data/genre_mappings.dart';
import 'recently_played.dart';
import 'like_service.dart';

/// Persistent user taste profile built from listening history + likes.
///
/// Computes decay-weighted affinity scores for artists, genres, and languages
/// so the recommendation engine can rank candidate songs against the user's
/// real preferences.
class TasteProfileService {
  // ── Singleton ──────────────────────────────────────────────────
  static TasteProfileService? _instance;
  factory TasteProfileService() {
    _instance ??= TasteProfileService._internal();
    return _instance!;
  }
  TasteProfileService._internal();

  static const _profileKey = 'taste_profile_v1';

  // ── Profile Data ───────────────────────────────────────────────

  /// Artist name (lowercase) → affinity score (higher = stronger preference).
  final Map<String, double> _artistAffinity = {};

  /// Genre name → affinity score.
  final Map<String, double> _genreAffinity = {};

  /// Language → affinity score.
  final Map<String, double> _languageAffinity = {};

  /// Song IDs the user has heard ≥ 3 times – candidates for de-prioritisation.
  final Set<String> _overplayedIds = {};

  /// Song ID → total play count for overplay detection.
  final Map<String, int> _songPlayCounts = {};

  /// Song IDs the user skipped (< 30 s) — negative signal.
  final Set<String> _skippedIds = {};

  /// Contextual listening patterns: timeSlot → genre → accumulated weight.
  /// Tracks what the user actually listens to at different times of day
  /// (and weekend vs weekday) so mood sections can be truly personal.
  final Map<String, Map<String, double>> _contextualGenres = {};

  /// Contextual listening patterns: timeSlot → artist → accumulated weight.
  final Map<String, Map<String, double>> _contextualArtists = {};

  DateTime? _lastRebuilt;

  // ── Public Getters ─────────────────────────────────────────────

  Map<String, double> get artistAffinity => Map.unmodifiable(_artistAffinity);
  Map<String, double> get genreAffinity => Map.unmodifiable(_genreAffinity);
  Map<String, double> get languageAffinity => Map.unmodifiable(_languageAffinity);
  bool get hasProfile => _artistAffinity.isNotEmpty;

  /// Top N artists sorted by affinity descending.
  List<String> topArtists(int n) {
    final sorted = _artistAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  /// Top N genres sorted by affinity descending.
  List<String> topGenres(int n) {
    final sorted = _genreAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  /// Top N languages sorted by affinity descending.
  List<String> topLanguages(int n) {
    final sorted = _languageAffinity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  /// Whether a song has been heard enough to be considered overplayed.
  bool isOverplayed(String songId) => _overplayedIds.contains(songId);

  /// Whether a song was recently skipped.
  bool wasSkipped(String songId) => _skippedIds.contains(songId);

  /// Whether an artist has never appeared in the user's listening history.
  bool isUnknownArtist(String artistName) {
    final key = artistName.trim().toLowerCase();
    return !_artistAffinity.containsKey(key);
  }

  /// Top genres the user listens to in a given time slot
  /// (e.g. 'morning', 'night', 'weekend').
  List<String> topContextualGenres(String timeSlot, int n) {
    final map = _contextualGenres[timeSlot];
    if (map == null || map.isEmpty) return [];
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  /// Top artists the user listens to in a given time slot.
  List<String> topContextualArtists(String timeSlot, int n) {
    final map = _contextualArtists[timeSlot];
    if (map == null || map.isEmpty) return [];
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  /// Composite affinity score for a candidate song (0.0–1.0).
  /// Blends artist, genre, and language signals normalised against the
  /// user's strongest affinity in each dimension.
  double affinityScore(Song song) {
    if (_artistAffinity.isEmpty) return 0.5; // neutral if no profile yet

    double score = 0.0;
    double totalWeight = 0.0;

    // ── Artist component (weight: 50%) ──
    const artistWeight = 0.50;
    final primaryArtist = _primaryArtist(song.artist).toLowerCase();
    final maxArtist = _artistAffinity.values.fold<double>(1, max);
    final artistScore = (_artistAffinity[primaryArtist] ?? 0) / maxArtist;
    score += artistScore * artistWeight;
    totalWeight += artistWeight;

    // Also check secondary artists
    final allArtists = song.artist.split(RegExp(r'[,&]')).map((a) => a.trim().toLowerCase());
    double bestArtist = artistScore;
    for (final a in allArtists) {
      final s = (_artistAffinity[a] ?? 0) / maxArtist;
      if (s > bestArtist) bestArtist = s;
    }
    if (bestArtist > artistScore) {
      score += (bestArtist - artistScore) * 0.15; // bonus for secondary match
    }

    // ── Genre component (weight: 35%) ──
    const genreWeight = 0.35;
    if (_genreAffinity.isNotEmpty) {
      final genres = inferGenres(song.artist, song.title);
      if (genres.isNotEmpty) {
        final maxGenre = _genreAffinity.values.fold<double>(1, max);
        double genreScore = 0;
        for (final g in genres) {
          genreScore = max(genreScore, (_genreAffinity[g] ?? 0) / maxGenre);
        }
        score += genreScore * genreWeight;
      }
      totalWeight += genreWeight;
    }

    // ── Language component (weight: 15%) ──
    const langWeight = 0.15;
    if (_languageAffinity.isNotEmpty && song.language != null) {
      final maxLang = _languageAffinity.values.fold<double>(1, max);
      final lang = song.language!.toLowerCase();
      final langScore = (_languageAffinity[lang] ?? 0) / maxLang;
      score += langScore * langWeight;
      totalWeight += langWeight;
    }

    // ── Penalties ──
    if (_overplayedIds.contains(song.id)) score *= 0.3;
    if (_skippedIds.contains(song.id)) score *= 0.2;

    return totalWeight > 0 ? (score / totalWeight).clamp(0.0, 1.0) : 0.5;
  }

  // ── Rebuild Profile ────────────────────────────────────────────

  /// Rebuilds the full taste profile from recent plays + likes.
  /// Call on app start and after significant events (song finished, like toggled).
  Future<void> rebuildProfile({
    RecentlyPlayedService? recentService,
    LikeService? likeService,
  }) async {
    final recent = recentService ?? RecentlyPlayedService();
    final recentWithTime = await recent.getRecentWithTimestamps(limit: 200);
    final likedSongs = likeService?.likedSongs ?? [];

    _artistAffinity.clear();
    _genreAffinity.clear();
    _languageAffinity.clear();
    _overplayedIds.clear();
    _songPlayCounts.clear();
    _contextualGenres.clear();
    _contextualArtists.clear();

    final now = DateTime.now();

    // ── Process recently played (with time-decay) ──
    for (final item in recentWithTime) {
      final song = item['song'] as Song;
      final playedAt = item['playedAt'] as DateTime;
      final playCount = item['playCount'] as int? ?? 1;

      // Time-decay: recent plays are worth more
      // Decay factor: 1.0 for today → 0.3 for 30 days ago
      final daysAgo = now.difference(playedAt).inDays.clamp(0, 90);
      final decay = 1.0 - (daysAgo / 90.0) * 0.7; // 1.0 → 0.3 over 90 days

      final weight = decay * (playCount > 1 ? min(playCount.toDouble(), 5) : 1.0);

      _addSongSignal(song, weight);

      // ── Contextual listening patterns ──
      _addContextualSignal(song, playedAt, weight);

      // Track play counts for overplay detection
      _songPlayCounts[song.id] = (_songPlayCounts[song.id] ?? 0) + playCount;
      if ((_songPlayCounts[song.id] ?? 0) >= 4) {
        _overplayedIds.add(song.id);
      }
    }

    // ── Process liked songs (2× boost, no decay) ──
    for (final song in likedSongs) {
      _addSongSignal(song, 2.0);
    }

    _lastRebuilt = now;
    await _persist();

    if (kDebugMode) {
      debugPrint('TasteProfile rebuilt: '
          '${_artistAffinity.length} artists, '
          '${_genreAffinity.length} genres, '
          '${_languageAffinity.length} languages, '
          '${_overplayedIds.length} overplayed');
    }
  }

  /// Record that a song was skipped (played < 30 seconds).
  void recordSkip(String songId) {
    _skippedIds.add(songId);
    // Keep skip set bounded
    if (_skippedIds.length > 200) {
      _skippedIds.remove(_skippedIds.first);
    }
  }

  /// Load persisted profile from disk (fast startup).
  Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_profileKey);
      if (raw == null) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;

      _artistAffinity
        ..clear()
        ..addAll((data['artists'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())));

      _genreAffinity
        ..clear()
        ..addAll((data['genres'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())));

      _languageAffinity
        ..clear()
        ..addAll((data['languages'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())));

      _overplayedIds
        ..clear()
        ..addAll((data['overplayed'] as List<dynamic>? ?? []).cast<String>());

      _songPlayCounts
        ..clear()
        ..addAll((data['playCounts'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())));

      _skippedIds
        ..clear()
        ..addAll((data['skipped'] as List<dynamic>? ?? []).cast<String>());

      // Restore contextual listening patterns
      _contextualGenres.clear();
      final ctxGenres = data['contextualGenres'] as Map<String, dynamic>? ?? {};
      for (final entry in ctxGenres.entries) {
        final inner = entry.value as Map<String, dynamic>? ?? {};
        _contextualGenres[entry.key] =
            inner.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }

      _contextualArtists.clear();
      final ctxArtists = data['contextualArtists'] as Map<String, dynamic>? ?? {};
      for (final entry in ctxArtists.entries) {
        final inner = entry.value as Map<String, dynamic>? ?? {};
        _contextualArtists[entry.key] =
            inner.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }

      final ts = data['lastRebuilt'] as String?;
      _lastRebuilt = ts != null ? DateTime.tryParse(ts) : null;

      if (kDebugMode) {
        debugPrint('TasteProfile loaded from cache: ${_artistAffinity.length} artists');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('TasteProfile loadCached error: $e');
    }
  }

  // ── Private Helpers ────────────────────────────────────────────

  void _addSongSignal(Song song, double weight) {
    // Artist affinity
    final artists = song.artist.split(RegExp(r'[,&]'));
    for (final a in artists) {
      final key = a.trim().toLowerCase();
      if (key.isNotEmpty && key != 'unknown') {
        _artistAffinity[key] = (_artistAffinity[key] ?? 0) + weight;
      }
    }

    // Genre affinity (inferred from artist + title)
    final genres = inferGenres(song.artist, song.title);
    for (final g in genres) {
      _genreAffinity[g] = (_genreAffinity[g] ?? 0) + weight;
    }

    // Language affinity
    if (song.language != null && song.language!.isNotEmpty) {
      final lang = song.language!.toLowerCase();
      _languageAffinity[lang] = (_languageAffinity[lang] ?? 0) + weight;
    }
  }

  String _primaryArtist(String artistField) {
    return artistField.split(RegExp(r'[,&]')).first.trim();
  }

  /// Classify a timestamp into a contextual time slot.
  String _timeSlot(DateTime dt) {
    // Weekend gets its own slot for different behaviour
    final isWeekend = dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;
    if (isWeekend) return 'weekend';
    final hour = dt.hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  /// Record what genres/artists the user plays at a given time.
  void _addContextualSignal(Song song, DateTime playedAt, double weight) {
    final slot = _timeSlot(playedAt);

    // Genre
    final genres = inferGenres(song.artist, song.title);
    _contextualGenres.putIfAbsent(slot, () => {});
    for (final g in genres) {
      _contextualGenres[slot]![g] = (_contextualGenres[slot]![g] ?? 0) + weight;
    }

    // Primary artist
    final artist = _primaryArtist(song.artist).toLowerCase();
    if (artist.isNotEmpty && artist != 'unknown') {
      _contextualArtists.putIfAbsent(slot, () => {});
      _contextualArtists[slot]![artist] =
          (_contextualArtists[slot]![artist] ?? 0) + weight;
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'artists': _artistAffinity,
        'genres': _genreAffinity,
        'languages': _languageAffinity,
        'overplayed': _overplayedIds.toList(),
        'playCounts': _songPlayCounts,
        'skipped': _skippedIds.toList(),
        'contextualGenres': _contextualGenres.map(
          (slot, map) => MapEntry(slot, map),
        ),
        'contextualArtists': _contextualArtists.map(
          (slot, map) => MapEntry(slot, map),
        ),
        'lastRebuilt': _lastRebuilt?.toIso8601String(),
      };
      await prefs.setString(_profileKey, jsonEncode(data));
    } catch (e) {
      if (kDebugMode) debugPrint('TasteProfile persist error: $e');
    }
  }
}

