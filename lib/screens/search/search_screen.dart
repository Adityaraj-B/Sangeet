import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/repositories/search_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangeet/size_config.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/models/artist.dart';
import 'package:sangeet/models/album.dart';
import 'package:sangeet/screens/artist/artist_screen.dart';
import 'package:sangeet/screens/albums/albums_screen.dart';
import 'package:sangeet/services/remote_music_service.dart';
import 'package:sangeet/services/taste_profile_service.dart';
import 'components/search_field.dart';
import 'components/category_chips.dart';
import 'components/shimmer_loading.dart';
import 'components/empty_search_state.dart';
import 'components/show_more_button.dart';
import 'components/search_suggestions.dart';
import 'components/recent_searches.dart';
import 'components/search_list_item.dart';

export 'components/category_chips.dart' show SearchCategory;

enum _ResultType { song, artist, album }

class _RankedResult {
  final dynamic item;
  final int score;
  final _ResultType type;
  const _RankedResult({required this.item, required this.score, required this.type});
}

class SearchScreen extends StatefulWidget {
  final SearchRepository repository;
  final void Function(Song) onPlay;

  const SearchScreen({
    super.key,
    required this.repository,
    required this.onPlay,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  static const _kRecentKey = 'recent_searches_v1';

  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  late AnimationController _animController;

  List<Artist> _artists = [];
  List<Song> _songs = [];
  List<Album> _albums = [];
  List<String> _suggestions = [];
  List<String> _recent = [];

  bool _loading = false;
  SearchCategory _selectedCategory = SearchCategory.all;

  bool get _isSearching =>
      _focusNode.hasFocus || _ctrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadRecent();
    _ctrl.addListener(_onChange);
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _ctrl.removeListener(_onChange);
    _ctrl.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onChange() {
    final text = _ctrl.text;
    _debounce?.cancel();

    // Fire autocomplete suggestions immediately for fast feedback (like Spotify)
    if (text.trim().length >= 2) {
      _fetchAutocompleteSuggestions(text.trim());
    }

    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) _performQuery(text);
    });
  }

  /// Fetch autocomplete suggestions in parallel for instant feedback.
  /// These show as chips above results while full search is still loading.
  Future<void> _fetchAutocompleteSuggestions(String query) async {
    try {
      final suggestions = await widget.repository.suggestions(query, limit: 6);
      if (mounted && _ctrl.text.trim() == query) {
        setState(() => _suggestions = suggestions);
      }
    } catch (_) {
      // Silently fail — derived suggestions will fill in
    }
  }

  Future<void> _performQuery(String query, {bool addToRecent = false}) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _artists = [];
        _songs = [];
        _albums = [];
        _suggestions = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final words = trimmed
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 2)
          .toList();

      // Always fire the full query for songs, artists, and albums
      final futures = <Future>[
        widget.repository.search(trimmed, limit: 50),
        widget.repository.searchArtists(trimmed, limit: 15),
        widget.repository.searchAlbums(trimmed, limit: 15),
      ];

      // For multi-word queries, also fire each word independently (Saavn only — faster)
      if (words.length > 1) {
        for (final w in words) {
          if (w.length >= 3) {
            futures.add(widget.repository.searchSaavn(w, limit: 20));
            futures.add(widget.repository.searchArtists(w, limit: 8));
            futures.add(widget.repository.searchAlbums(w, limit: 8));
          }
        }
      }

      final results = await Future.wait(futures);
      if (!mounted) return;

      final seenSongIds = <String>{};
      final seenArtistIds = <String>{};
      final seenAlbumIds = <String>{};
      final songs = <Song>[];
      final artists = <Artist>[];
      final albums = <Album>[];

      for (final s in results[0] as List<Song>) {
        if (seenSongIds.add(s.id)) songs.add(s);
      }
      for (final a in results[1] as List<Artist>) {
        if (seenArtistIds.add(a.id)) artists.add(a);
      }
      for (final a in results[2] as List<Album>) {
        if (seenAlbumIds.add(a.id)) albums.add(a);
      }

      // Merge per-word results
      for (int i = 3; i < results.length; i++) {
        final r = results[i];
        if (r is List<Song>) {
          for (final s in r) if (seenSongIds.add(s.id)) songs.add(s);
        } else if (r is List<Artist>) {
          for (final a in r) if (seenArtistIds.add(a.id)) artists.add(a);
        } else if (r is List<Album>) {
          for (final a in r) if (seenAlbumIds.add(a.id)) albums.add(a);
        }
      }

      // Derive suggestions from real results — instant & accurate
      _deriveSuggestions(trimmed, songs, artists, albums);

      // ── Personalized re-ranking ──
      // Boost songs from artists / genres / languages the user prefers.
      // Blend: 75% relevance (API order) + 25% taste affinity.
      final tasteService = TasteProfileService();
      if (tasteService.hasProfile && songs.length > 3) {
        // Pre-compute original relevance index (O(n) vs O(n²) if done inside sort)
        final relevanceMap = <String, double>{};
        for (int i = 0; i < songs.length; i++) {
          relevanceMap[songs[i].id] = 1.0 - (i / songs.length);
        }
        songs.sort((a, b) {
          final aRelevance = relevanceMap[a.id] ?? 0.5;
          final bRelevance = relevanceMap[b.id] ?? 0.5;
          final aTaste = tasteService.affinityScore(a);
          final bTaste = tasteService.affinityScore(b);
          final aScore = aRelevance * 0.75 + aTaste * 0.25;
          final bScore = bRelevance * 0.75 + bTaste * 0.25;
          return bScore.compareTo(aScore);
        });
      }

      if (!mounted) return;
      setState(() {
        _songs = songs;
        _artists = _filterPopularArtists(artists);
        _albums = albums;
        _loading = false;
      });

      if (addToRecent) await _addRecent(trimmed);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── POPULAR ARTIST FILTER ────────────────────────────────────
  // Removes unverified / no-image / duplicate artists.
  List<Artist> _filterPopularArtists(List<Artist> raw) {
    final seenNames = <String>{};
    final out = <Artist>[];
    for (final a in raw) {
      if (a.id.isEmpty) continue;
      if (a.name.trim().length <= 1) continue;
      if (a.imageUrl.isEmpty) continue; // unverified artists have no image
      final key = a.name.trim().toLowerCase();
      if (!seenNames.add(key)) continue; // deduplicate
      out.add(a);
    }
    return out;
  }

  // ─── SUGGESTIONS ─────────────────────────────────────────────
  // Derived from live results — no extra API call needed.
  // Now includes albums and ranks by relevance + popularity.
  void _deriveSuggestions(
      String query, List<Song> songs, List<Artist> artists, List<Album> albums) {
    final q = query.toLowerCase().trim();
    final seen = <String>{};
    final scored = <(String, int)>[]; // (suggestion, score) — lower = better

    void add(String s, int score) {
      final k = s.trim().toLowerCase();
      if (k.isEmpty || k == q) return;
      if (!seen.add(k)) return;
      scored.add((s.trim(), score));
    }

    // Artists first (highest-intent) — Spotify always shows artist at top
    for (int i = 0; i < artists.take(5).length; i++) {
      final a = artists[i];
      if (_matchesFuzzy(a.name, q)) add(a.name, i);
    }

    // Album names — crucial for queries like "dhurandhar"
    for (int i = 0; i < albums.take(5).length; i++) {
      final a = albums[i];
      if (_matchesFuzzy(a.name, q)) add(a.name, 5 + i);
    }

    // Song titles — prefer popular songs
    // Sort by playCount before picking suggestions
    final sortedSongs = List<Song>.from(songs)
      ..sort((a, b) => (b.playCount ?? 0).compareTo(a.playCount ?? 0));

    for (int i = 0; i < sortedSongs.take(10).length; i++) {
      final s = sortedSongs[i];
      if (_matchesFuzzy(s.title, q)) add(s.title, 10 + i);
    }

    // Sort by score (lower = more relevant)
    scored.sort((a, b) => a.$2.compareTo(b.$2));

    if (mounted) {
      setState(() => _suggestions = scored.take(6).map((e) => e.$1).toList());
    }
  }

  /// Fuzzy match: starts with, contains, or any word starts with query.
  bool _matchesFuzzy(String text, String query) {
    final t = text.toLowerCase();
    final q = query.toLowerCase();
    if (t.startsWith(q)) return true;
    if (t.contains(q)) return true;
    // Any word in text starts with query
    if (t.split(' ').any((w) => w.startsWith(q))) return true;
    // Any word in query matches any word in text
    final qWords = q.split(' ').where((w) => w.length >= 2);
    if (qWords.isNotEmpty && qWords.every((qw) => t.split(' ').any((tw) => tw.startsWith(qw)))) {
      return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  // UNIFIED RANKING ENGINE
  // All types compete in one score space. Lower = shown first.
  //  0-12  exact / starts-with
  // 13-25  all words present
  // 26-35  prefix-of-word (partial typing: "ari" → "Arijit")
  // 36-50  majority tokens match
  // 51-70  single word/artist hit
  // 71-95  phonetic / fuzzy
  // 1000   no match — hidden
  // ─────────────────────────────────────────────────────────────

  static const _kStopWords = {
    'by', 'from', 'feat', 'ft', 'with', 'and', 'the', 'a', 'an',
    'in', 'on', 'of', 'ke', 'ki', 'ka', 'se', 'ne', 'ko', 'hai',
  };

  List<_RankedResult> _buildRankedResults() {
    final raw = _ctrl.text.toLowerCase().trim();
    if (raw.isEmpty) return [];
    final q = _normalize(raw);
    final qWords = q.split(' ').where((w) => w.isNotEmpty).toList();
    final tokens = qWords.where((w) => !_kStopWords.contains(w)).toList();
    final tc = tokens.isEmpty ? qWords.length : tokens.length;
    final tok = tokens.isEmpty ? qWords : tokens;

    final ranked = <_RankedResult>[];
    for (int i = 0; i < _songs.length; i++) {
      final s = _songs[i];
      final title = _normalize(s.title.toLowerCase());
      final artist = _normalize(s.artist.toLowerCase());
      final firstArt = artist.split(',').first.trim();
      final combined = '$title $artist';
      var sc = _scoreSong(q, qWords, tok, tc, title, artist, firstArt, combined, _posBonus(i, _songs.length));
      if (sc < 1000) {
        // Apply popularity bonus: high playCount songs get pushed up within
        // their relevance band (max -5 bonus for viral songs)
        sc -= _popularityBonus(s.playCount);
        sc = sc.clamp(-5, 999);
        ranked.add(_RankedResult(item: s, score: sc, type: _ResultType.song));
      }
    }
    for (int i = 0; i < _artists.length; i++) {
      final a = _artists[i];
      final name = _normalize(a.name.toLowerCase());
      final sc = _scoreArtist(q, qWords, tok, tc, name, _posBonus(i, _artists.length));
      if (sc < 1000) ranked.add(_RankedResult(item: a, score: sc, type: _ResultType.artist));
    }
    for (int i = 0; i < _albums.length; i++) {
      final a = _albums[i];
      final name = _normalize(a.name.toLowerCase());
      final artist = _normalize(a.artist.toLowerCase());
      final sc = _scoreAlbum(q, qWords, tok, tc, name, artist, '$name $artist', _posBonus(i, _albums.length));
      if (sc < 1000) ranked.add(_RankedResult(item: a, score: sc, type: _ResultType.album));
    }
    ranked.sort((a, b) => a.score.compareTo(b.score));
    return ranked;
  }

  /// Popularity bonus based on playCount.
  /// Returns 0-5: viral songs (>10M) get 5, popular (>1M) get 3, etc.
  int _popularityBonus(int? playCount) {
    if (playCount == null || playCount <= 0) return 0;
    if (playCount > 50000000) return 5; // 50M+
    if (playCount > 10000000) return 4; // 10M+
    if (playCount > 1000000) return 3;  // 1M+
    if (playCount > 100000) return 2;   // 100K+
    if (playCount > 10000) return 1;    // 10K+
    return 0;
  }

  int _posBonus(int idx, int total) {
    if (total <= 1) return 0;
    return ((total - 1 - idx) * 4 ~/ (total - 1)).clamp(0, 4);
  }

  bool _phraseOrdered(String text, List<String> words) {
    int cursor = 0;
    for (final w in words) {
      final idx = text.indexOf(w, cursor);
      if (idx == -1) return false;
      cursor = idx + w.length;
    }
    return true;
  }

  int _cov(String text, List<String> toks) =>
      toks.where((w) => text.contains(w)).length;

  /// Does any word in [text] start with [qw]? Handles "ari" → "arijit".
  bool _wordPrefix(String text, String qw) {
    if (qw.length < 2) return false;
    return text.split(' ').any((w) => w.startsWith(qw));
  }

  int _prefixCov(String text, List<String> qWords) =>
      qWords.where((qw) => _wordPrefix(text, qw)).length;

  int _scoreSong(String q, List<String> qWords, List<String> tok, int tc,
      String title, String artist, String firstArt, String combined, int bonus) {
    final qLen = q.length;
    if (title == q) return (0 - bonus).clamp(-4, 0);
    if (title.startsWith(q)) return (4 + ((title.length - qLen) ~/ 5).clamp(0, 8) - bonus).clamp(0, 12);
    if (qWords.length > 1 && qWords.every((w) => title.contains(w))) {
      return _phraseOrdered(title, qWords) ? (12 - bonus).clamp(8, 12) : (17 - bonus).clamp(13, 17);
    }
    if (tc > 1 && _cov(title, tok) == tc) return (20 - bonus).clamp(16, 20);
    if (tc > 1 && _cov(combined, tok) == tc) return (25 - bonus).clamp(21, 25);
    final prefHits = _prefixCov(combined, qWords);
    if (prefHits == qWords.length) {
      return _prefixCov(title, qWords) == qWords.length
          ? (16 - bonus).clamp(12, 16)
          : (26 - bonus).clamp(22, 26);
    }
    if (qWords.length > 1 && prefHits >= (qWords.length * 0.6).ceil()) return (32 - bonus).clamp(28, 32);
    if (qWords.length == 1 && _wordPrefix(title, q)) {
      final pos = title.split(' ').indexWhere((w) => w.startsWith(q));
      return (14 + pos.clamp(0, 5) * 3 - bonus).clamp(10, 26);
    }
    if (firstArt == q) return (30 - bonus).clamp(26, 30);
    if (firstArt.startsWith(q)) return (35 - bonus).clamp(31, 35);
    if (_wordPrefix(firstArt, q)) return (38 - bonus).clamp(34, 38);
    if (title.contains(q)) return (40 - bonus).clamp(36, 40);
    if (tc > 1) {
      final cov = _cov(combined, tok);
      if (cov >= (tc * 0.5).ceil()) return (50 - cov * 2 - bonus).clamp(38, 50);
      if (_cov(title, tok) >= 1) return (58 - bonus).clamp(54, 58);
    }
    if (artist.contains(q)) return (62 - bonus).clamp(58, 62);
    if (qWords.any((w) => w.length >= 3 && combined.contains(w))) return (66 - bonus).clamp(62, 66);
    if (qWords.any((w) => w.length >= 2 && _wordPrefix(combined, w))) return (72 - bonus).clamp(68, 72);
    final ph = _phoneticScore(q, title, artist);
    if (ph < 1000) return (ph - bonus).clamp(0, 90);
    final sim = _bigramSim(q, title);
    if (sim > 0.65) return (80 - bonus).clamp(76, 80);
    if (sim > 0.45) return (90 - bonus).clamp(86, 90);
    for (final qw in qWords) {
      if (qw.length >= 3 && _bigramSim(qw, title) > 0.55) return (94 - bonus).clamp(90, 94);
    }
    return 1000;
  }

  int _scoreArtist(String q, List<String> qWords, List<String> tok, int tc, String name, int bonus) {
    final qLen = q.length;
    if (name == q) return (0 - bonus).clamp(-4, 0);
    if (name.startsWith(q)) return (3 + ((name.length - qLen) ~/ 4).clamp(0, 8) - bonus).clamp(0, 11);
    if (qWords.length > 1 && qWords.every((w) => name.contains(w))) {
      return _phraseOrdered(name, qWords) ? (13 - bonus).clamp(9, 13) : (18 - bonus).clamp(14, 18);
    }
    final prefHits = _prefixCov(name, qWords);
    if (prefHits == qWords.length) return (20 - bonus).clamp(16, 20);
    if (qWords.length > 1 && prefHits >= (qWords.length * 0.6).ceil()) return (27 - bonus).clamp(23, 27);
    if (qWords.length == 1 && _wordPrefix(name, q)) return (16 - bonus).clamp(12, 18);
    if (name.contains(q)) return (33 - bonus).clamp(29, 33);
    if (tc > 1) {
      final cov = _cov(name, tok);
      if (cov >= (tc * 0.4).ceil()) return (44 - cov - bonus).clamp(38, 44);
    }
    if (qWords.any((w) => w.length >= 2 && _wordPrefix(name, w))) return (48 - bonus).clamp(44, 48);
    final sim = _bigramSim(q, name);
    if (sim > 0.65) return (55 - bonus).clamp(51, 55);
    if (sim > 0.45) return (68 - bonus).clamp(64, 68);
    return 1000;
  }

  int _scoreAlbum(String q, List<String> qWords, List<String> tok, int tc,
      String name, String artist, String combined, int bonus) {
    final qLen = q.length;
    if (name == q) return (0 - bonus).clamp(-4, 0);
    if (name.startsWith(q)) return (5 + ((name.length - qLen) ~/ 4).clamp(0, 8) - bonus).clamp(0, 13);
    if (qWords.length > 1 && qWords.every((w) => name.contains(w))) {
      return _phraseOrdered(name, qWords) ? (15 - bonus).clamp(11, 15) : (20 - bonus).clamp(16, 20);
    }
    if (tc > 1 && _cov(combined, tok) == tc) return (23 - bonus).clamp(19, 23);
    final prefHits = _prefixCov(combined, qWords);
    if (prefHits == qWords.length) return (24 - bonus).clamp(20, 24);
    if (qWords.length > 1 && prefHits >= (qWords.length * 0.6).ceil()) return (30 - bonus).clamp(26, 30);
    if (qWords.length == 1 && _wordPrefix(name, q)) return (26 - bonus).clamp(22, 30);
    if (artist.startsWith(q)) return (32 - bonus).clamp(28, 32);
    if (name.contains(q)) return (38 - bonus).clamp(34, 38);
    if (artist.contains(q)) return (46 - bonus).clamp(42, 46);
    if (tc > 1) {
      final cov = _cov(combined, tok);
      if (cov >= (tc * 0.4).ceil()) return (54 - cov * 2 - bonus).clamp(44, 54);
      if (_cov(name, tok) >= 1) return (60 - bonus).clamp(56, 60);
    }
    if (qWords.any((w) => w.length >= 3 && combined.contains(w))) return (64 - bonus).clamp(60, 64);
    final sim = _bigramSim(q, name);
    if (sim > 0.65) return (70 - bonus).clamp(66, 70);
    if (sim > 0.45) return (82 - bonus).clamp(78, 82);
    return 1000;
  }
  //
  //   Scores are integers where lower = better.  Each type (songs /
  //   artists / albums) is ranked in its own list so the best song
  //   always heads the Songs section, best artist heads Artists, etc.
  //
  // ─────────────────────────────────────────────────────────────
  // UTILITY HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Strip punctuation, collapse whitespace, lowercase.
  String _normalize(String s) => s
      .replaceAll(RegExp(r"[^\w\s]"), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Bigram (character-pair) similarity — much better than char-set overlap
  /// for detecting typos and romanisation variants (0.0 – 1.0).
  double _bigramSim(String a, String b) {
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) {
      // Single-char fallback: plain contains
      return (a.contains(b) || b.contains(a)) ? 0.6 : 0.0;
    }

    Set<String> bigrams(String s) {
      final set = <String>{};
      for (int i = 0; i < s.length - 1; i++) {
        set.add(s.substring(i, i + 2));
      }
      return set;
    }

    final aB = bigrams(a);
    final bB = bigrams(b);
    final intersection = aB.intersection(bB).length;
    return (2.0 * intersection) / (aB.length + bB.length);
  }

  /// Phonetic / romanisation score for Indian-language songs.
  /// Returns a score (lower = better) or 1000 if nothing matches.
  int _phoneticScore(String query, String title, String artist) {
    const Map<String, List<String>> map = {
      'aa': ['a'],  'ee': ['i'],  'oo': ['u'],
      'ae': ['e', 'ai'], 'oh': ['o', 'au'],
      'bh': ['b'],  'ch': ['c'],  'dh': ['d'],
      'gh': ['g'],  'jh': ['j'],  'kh': ['k'],
      'ph': ['f', 'p'], 'sh': ['s'], 'th': ['t'],
    };

    int best = 1000;

    for (final entry in map.entries) {
      for (final alt in entry.value) {
        if (query.contains(entry.key)) {
          final v = query.replaceAll(entry.key, alt);
          if (title.startsWith(v))  { best = best > 35 ? 35 : best; }
          else if (title.contains(v)) { best = best > 45 ? 45 : best; }
          else if (artist.contains(v)){ best = best > 51 ? 51 : best; }
        }
        if (title.contains(entry.key)) {
          final tv = title.replaceAll(entry.key, alt);
          if (tv.contains(query)) { best = best > 41 ? 41 : best; }
        }
      }
    }
    return best;
  }


  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentKey);
    if (mounted) setState(() => _recent = []);
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _recent = prefs.getStringList(_kRecentKey) ?? []);
  }

  Future<void> _addRecent(String item) async {
    final prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(_kRecentKey) ?? [];
    list.remove(item);
    list.insert(0, item);
    if (list.length > 12) list = list.sublist(0, 12);
    await prefs.setStringList(_kRecentKey, list);
    if (mounted) setState(() => _recent = list);
  }

  void _applySuggestion(String suggestion) {
    _ctrl.text = suggestion;
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: suggestion.length));
    _focusNode.unfocus();
    _performQuery(suggestion, addToRecent: true);
  }

  void _onSongTap(Song song) {
    if (song.streamUrl == null || song.streamUrl!.isEmpty) return;
    widget.onPlay(song);
  }

  void _onArtistTap(Artist artist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtistScreen(
          artistId: artist.id,
          musicService:
          RemoteMusicService('https://vercelapi-gamma.vercel.app/api'),
          onPlaySong: widget.onPlay,
        ),
      ),
    );
  }

  void _onAlbumTap(Album album) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumScreen(
          album: album,
          musicService:
          RemoteMusicService('https://vercelapi-gamma.vercel.app/api'),
          onPlaySong: widget.onPlay,
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return const ShimmerLoading();

    final ranked = _buildRankedResults();

    if (ranked.isEmpty && _ctrl.text.trim().isNotEmpty) {
      return EmptySearchState(query: _ctrl.text);
    }
    if (ranked.isEmpty) return const SizedBox.shrink();

    final songs = ranked.where((r) => r.type == _ResultType.song).map((r) => r.item as Song).toList();
    final artists = ranked.where((r) => r.type == _ResultType.artist).map((r) => r.item as Artist).toList();
    final albums = ranked.where((r) => r.type == _ResultType.album).map((r) => r.item as Album).toList();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.025), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(_ctrl.text + _selectedCategory.name),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryChips(
            selectedCategory: _selectedCategory,
            songCount: songs.length,
            artistCount: artists.length,
            albumCount: albums.length,
            onCategoryChanged: (c) => setState(() => _selectedCategory = c),
          ),
          const SizedBox(height: 20),
          if (_selectedCategory == SearchCategory.all)
            _buildUnifiedList(ranked)
          else if (_selectedCategory == SearchCategory.songs) ...[
            _SectionLabel(title: 'Songs', count: songs.length),
            const SizedBox(height: 6),
            ...songs.map((s) => SongResultItem(song: s, onTap: () => _onSongTap(s))),
          ] else if (_selectedCategory == SearchCategory.artists) ...[
            _SectionLabel(title: 'Artists', count: artists.length),
            const SizedBox(height: 6),
            ...artists.map((a) => ArtistResultItem(artist: a, onTap: () => _onArtistTap(a))),
          ] else if (_selectedCategory == SearchCategory.albums) ...[
            _SectionLabel(title: 'Albums', count: albums.length),
            const SizedBox(height: 6),
            ...albums.map((a) => AlbumResultItem(album: a, onTap: () => _onAlbumTap(a))),
          ],
        ],
      ),
    );
  }

  Widget _buildUnifiedList(List<_RankedResult> ranked) {
    // Show top 18 results in unified order (songs, artists, albums mixed by score)
    final top = ranked.take(18).toList();
    final topAlbumIds = top.where((r) => r.type == _ResultType.album).map((r) => (r.item as Album).id).toSet();

    final remainingSongs = ranked.skip(18)
        .where((r) => r.type == _ResultType.song)
        .map((r) => r.item as Song)
        .toList();

    // Only show albums in the "Albums" section that aren't already in top results
    final remainingAlbums = ranked
        .where((r) => r.type == _ResultType.album)
        .map((r) => r.item as Album)
        .where((a) => !topAlbumIds.contains(a.id))
        .take(6)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...top.map((r) {
          if (r.type == _ResultType.song) {
            final s = r.item as Song;
            return SongResultItem(song: s, onTap: () => _onSongTap(s));
          } else if (r.type == _ResultType.artist) {
            final a = r.item as Artist;
            return _ArtistInlineRow(artist: a, onTap: () => _onArtistTap(a));
          } else {
            final a = r.item as Album;
            return AlbumResultItem(album: a, onTap: () => _onAlbumTap(a));
          }
        }),
        if (remainingSongs.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionLabel(title: 'More Songs'),
          const SizedBox(height: 6),
          ...remainingSongs.take(6).map((s) => SongResultItem(song: s, onTap: () => _onSongTap(s))),
          if (remainingSongs.length > 6) ...[
            const SizedBox(height: 4),
            ShowMoreButton(
              type: 'songs',
              remaining: remainingSongs.length - 6,
              onTap: () => setState(() => _selectedCategory = SearchCategory.songs),
            ),
          ],
        ],
        if (remainingAlbums.isNotEmpty) ...[
          const SizedBox(height: 28),
          _SectionLabel(title: 'Albums'),
          const SizedBox(height: 6),
          ...remainingAlbums.map((a) => AlbumResultItem(album: a, onTap: () => _onAlbumTap(a))),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    // On desktop, use fixed padding instead of proportional
    final double sidePad = isWide ? 28 : getProportionateScreenWidth(20);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 56 + MediaQuery.of(context).padding.top,
              color: kBackgroundColor.withValues(alpha: 0.82),
              alignment: Alignment.bottomCenter,
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                  left: sidePad,
                  right: sidePad,
                  bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, -0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _isSearching
                        ? const SizedBox.shrink(key: ValueKey('no-title'))
                        : const Text(
                            key: ValueKey('title'),
                            'Search',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          sidePad,
          MediaQuery.of(context).padding.top + 56 + 12,
          sidePad,
          bottomPad + 32,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SearchField(
              controller: _ctrl,
              focusNode: _focusNode,
              onClear: () {
                _ctrl.clear();
                _focusNode.requestFocus();
                setState(() => _selectedCategory = SearchCategory.all);
              },
              onSubmitted: (_) {
                final query = _ctrl.text.trim();
                if (query.length >= 2) {
                  _addRecent(query);
                  _focusNode.unfocus();
                }
              },
            ),
            const SizedBox(height: 16),
            SearchSuggestions(
              suggestions: _suggestions,
              isSearching: _isSearching,
              onSuggestionTap: _applySuggestion,
            ),
            RecentSearches(
              recent: _recent,
              isSearching: _isSearching,
              onRecentTap: _applySuggestion,
              onClear: _clearRecent,
            ),
            _buildResults(),
          ],
        ),
      ),
    );
  }
}

/// Inline section label
class _SectionLabel extends StatelessWidget {
  final String title;
  final int? count;

  const _SectionLabel({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ARTIST INLINE ROW — shown inside the merged result list
// ─────────────────────────────────────────────────────────────

class _ArtistInlineRow extends StatefulWidget {
  final Artist artist;
  final VoidCallback onTap;
  const _ArtistInlineRow({required this.artist, required this.onTap});

  @override
  State<_ArtistInlineRow> createState() => _ArtistInlineRowState();
}

class _ArtistInlineRowState extends State<_ArtistInlineRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: _pressed
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: widget.artist.imageUrl.isNotEmpty
                    ? Image.network(
                        widget.artist.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Artist',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.18),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF1E1E22),
        child: Center(
          child: Icon(Icons.person_rounded,
              color: Colors.white.withValues(alpha: 0.12), size: 24),
        ),
      );
}
