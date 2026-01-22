import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/repositories/search_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangeet/size_config.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/models/artist.dart';
import 'package:sangeet/screens/artist/artist_screen.dart';
import 'package:sangeet/services/remote_music_service.dart';

import 'components/glass_chip.dart';
import 'components/search_list_item.dart';

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

class _SearchScreenState extends State<SearchScreen> {
  static const _kRecentKey = 'recent_searches_v1';

  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;

  List<Artist> _artists = [];
  List<Song> _songs = [];
  List<String> _suggestions = [];
  List<String> _recent = [];

  bool _loading = false;

  bool get _isSearching =>
      _focusNode.hasFocus || _ctrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _ctrl.addListener(_onChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _ctrl.removeListener(_onChange);
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChange() {
    final text = _ctrl.text;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
          () {
        if (mounted) _performQuery(text);
      },
    );
    _fetchSuggestions(text);
  }

  Future<void> _performQuery(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _artists = [];
        _songs = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        widget.repository.search(query, limit: 20),
        widget.repository.searchArtists(query, limit: 5),
      ]);

      if (!mounted) return;

      setState(() {
        _songs = results[0] as List<Song>;
        _artists = results[1] as List<Artist>;
        _loading = false;
      });

      await _addRecent(query);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Advanced global search with sophisticated ranking algorithm
  List<dynamic> _buildGlobalResults() {
    final q = _ctrl.text.toLowerCase().trim();
    if (q.isEmpty) return [];

    // Normalize query for better matching
    final normalizedQuery = _normalizeString(q);
    final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();

    // Score songs with multi-factor ranking
    int scoreSong(Song s) {
      final title = _normalizeString(s.title.toLowerCase());
      final artist = _normalizeString(s.artist.toLowerCase());

      int score = 1000; // Base score (lower is better)

      // Exact match (highest priority)
      if (title == normalizedQuery) return 0;
      if (artist == normalizedQuery) return 1;

      // Bollywood pattern matching (movie + song combinations)
      if (_matchesBollywoodPattern(s.title, s.artist, q)) {
        score = 4; // Very high priority for Bollywood patterns
      }

      // Title matching
      if (title.startsWith(normalizedQuery)) {
        score = score > 5 ? 5 : score; // Strong match
      } else if (title.contains(' $normalizedQuery ') || title.endsWith(' $normalizedQuery')) {
        score = score > 10 ? 10 : score; // Word boundary match
      } else if (title.contains(normalizedQuery)) {
        score = score > 20 ? 20 : score; // Substring match
      }

      // Multi-word query matching (all words must appear)
      if (queryWords.length > 1) {
        final allWordsInTitle = queryWords.every((word) => title.contains(word));
        final allWordsInArtist = queryWords.every((word) => artist.contains(word));
        final combinedText = '$title $artist';
        final allWordsInCombined = queryWords.every((word) => combinedText.contains(word));

        if (allWordsInTitle) {
          score = score > 15 ? 15 : score; // Boost if all words match title
        } else if (allWordsInCombined) {
          // For Bollywood: "tum hi ho aashiqui" matches title "Tum Hi Ho" + movie "Aashiqui 2"
          score = score > 18 ? 18 : score;
        } else if (allWordsInArtist) {
          score = score > 25 ? 25 : score;
        } else {
          // Partial word matching penalty
          final matchingWords = queryWords.where((word) =>
          title.contains(word) || artist.contains(word)
          ).length;
          if (matchingWords == 0) return 1000; // No match
          score += (queryWords.length - matchingWords) * 30;
        }
      }

      // Artist name matching (secondary)
      if (artist.startsWith(normalizedQuery)) {
        score = score > 30 ? (score + 30) ~/ 2 : score; // Moderate boost
      } else if (artist.contains(normalizedQuery)) {
        score = score > 40 ? (score + 40) ~/ 2 : score;
      }

      // Romanization and phonetic matching for Indian languages
      final phoneticScore = _calculatePhoneticMatch(normalizedQuery, title, artist);
      if (phoneticScore > 0) {
        score = score > phoneticScore ? phoneticScore : score;
      }

      // Fuzzy matching for typos (Levenshtein-like)
      if (score > 100) {
        final titleSimilarity = _calculateSimilarity(normalizedQuery, title);
        final artistSimilarity = _calculateSimilarity(normalizedQuery, artist);

        if (titleSimilarity > 0.7 || artistSimilarity > 0.7) {
          score = 60; // Fuzzy match
        } else if (titleSimilarity > 0.5 || artistSimilarity > 0.5) {
          score = 80;
        }
      }

      // Length penalty - prefer shorter titles for similar matches
      score += (title.length / 10).round();

      return score;
    }

    // Score artists with refined ranking
    int scoreArtist(Artist a) {
      final name = _normalizeString(a.name.toLowerCase());

      int score = 1000;

      // Exact match
      if (name == normalizedQuery) return 3; // Slightly lower priority than exact song match

      // Prefix match
      if (name.startsWith(normalizedQuery)) {
        score = 12;
      } else if (name.contains(' $normalizedQuery ') || name.endsWith(' $normalizedQuery')) {
        score = 18; // Word boundary
      } else if (name.contains(normalizedQuery)) {
        score = 30;
      }

      // Multi-word matching
      if (queryWords.length > 1) {
        final allWordsInName = queryWords.every((word) => name.contains(word));
        if (allWordsInName) {
          score = score > 20 ? 20 : score;
        } else {
          final matchingWords = queryWords.where((word) => name.contains(word)).length;
          if (matchingWords == 0) return 1000;
          score += (queryWords.length - matchingWords) * 40;
        }
      }

      // Fuzzy matching
      if (score > 100) {
        final similarity = _calculateSimilarity(normalizedQuery, name);
        if (similarity > 0.7) {
          score = 70;
        } else if (similarity > 0.5) {
          score = 90;
        }
      }

      // Length penalty
      score += (name.length / 8).round();

      return score;
    }

    // Filter and score all items
    final scoredItems = <MapEntry<dynamic, int>>[];

    for (final song in _songs) {
      final score = scoreSong(song);
      if (score < 1000) { // Only include relevant matches
        scoredItems.add(MapEntry(song, score));
      }
    }

    for (final artist in _artists) {
      final score = scoreArtist(artist);
      if (score < 1000) {
        scoredItems.add(MapEntry(artist, score));
      }
    }

    // Sort by score (lower is better)
    scoredItems.sort((a, b) => a.value.compareTo(b.value));

    // Organize results: Top 2 best matches, then interleave songs and artists
    final results = <dynamic>[];
    final topMatches = scoredItems.take(2).map((e) => e.key).toList();
    results.addAll(topMatches);

    final remaining = scoredItems.skip(2).map((e) => e.key).toList();
    final songs = remaining.whereType<Song>().toList();
    final artists = remaining.whereType<Artist>().toList();

    // Interleave: 3 songs, 1 artist pattern for variety
    int songIdx = 0, artistIdx = 0;
    while (songIdx < songs.length || artistIdx < artists.length) {
      for (int i = 0; i < 3 && songIdx < songs.length; i++) {
        results.add(songs[songIdx++]);
      }
      if (artistIdx < artists.length) {
        results.add(artists[artistIdx++]);
      }
    }

    return results.take(15).toList();
  }

  /// Normalize string by removing extra spaces and special characters
  /// Optimized for Indian/Bollywood songs with romanization support
  String _normalizeString(String s) {
    return s
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special chars
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .toLowerCase()
        .trim();
  }

  /// Check if query matches common Bollywood search patterns
  bool _matchesBollywoodPattern(String title, String artist, String query) {
    final normalizedTitle = _normalizeString(title);
    final normalizedArtist = _normalizeString(artist);
    final normalizedQuery = _normalizeString(query);

    // Check for movie name pattern (common in Bollywood)
    // e.g., "kajra re bunty aur babli" should match "Kajra Re" from movie "Bunty Aur Babli"
    if (normalizedQuery.contains(' ')) {
      final words = normalizedQuery.split(' ');

      // Check if first word(s) match title and last word(s) match artist/movie
      for (int i = 1; i < words.length; i++) {
        final titlePart = words.sublist(0, i).join(' ');
        final artistPart = words.sublist(i).join(' ');

        if (normalizedTitle.contains(titlePart) && normalizedArtist.contains(artistPart)) {
          return true;
        }
      }
    }

    // Check for "song movie" pattern
    // e.g., "tum hi ho aashiqui" should match "Tum Hi Ho" from "Aashiqui 2"
    final titleWords = normalizedTitle.split(' ');
    final queryWords = normalizedQuery.split(' ');

    if (queryWords.length >= 2 && titleWords.isNotEmpty) {
      // Check if query starts with title
      final potentialTitle = queryWords.take(titleWords.length.clamp(0, queryWords.length - 1)).join(' ');
      if (normalizedTitle.startsWith(potentialTitle)) {
        return true;
      }
    }

    return false;
  }

  /// Calculate similarity between two strings (0.0 to 1.0)
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Use longest common subsequence ratio
    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;

    // Simple contains check for performance
    if (longer.contains(shorter)) {
      return shorter.length / longer.length;
    }

    // Character overlap ratio
    final s1Chars = s1.split('').toSet();
    final s2Chars = s2.split('').toSet();
    final intersection = s1Chars.intersection(s2Chars);

    return intersection.length / s1Chars.union(s2Chars).length;
  }

  /// Phonetic matching for common romanization variations in Indian songs
  /// Handles variations like: ae/e, o/oh, a/aa, i/ee, u/oo, etc.
  int _calculatePhoneticMatch(String query, String title, String artist) {
    // Common romanization mappings for Indian languages
    final Map<String, List<String>> phoneticMappings = {
      'aa': ['a', 'aa', 'aaa'],
      'ee': ['i', 'ee', 'ii'],
      'oo': ['u', 'oo', 'uu'],
      'ae': ['e', 'ae', 'ai'],
      'oh': ['o', 'oh', 'au'],
      'ch': ['ch', 'chh'],
      'sh': ['sh', 'shh'],
      'kh': ['kh', 'khh', 'k'],
      'th': ['th', 'thh', 't'],
      'ph': ['ph', 'phh', 'f'],
      'dh': ['dh', 'dhh', 'd'],
      'bh': ['bh', 'bhh', 'b'],
      'gh': ['gh', 'ghh', 'g'],
      'jh': ['jh', 'jhh', 'j'],
      'r': ['r', 'rr'],
      'n': ['n', 'nn'],
      'y': ['y', 'yy'],
    };

    // Generate phonetic variations of query
    String generateVariation(String text, String from, String to) {
      return text.replaceAll(from, to);
    }

    // Check if any phonetic variation matches
    int bestScore = 1000;

    for (final entry in phoneticMappings.entries) {
      for (final variant in entry.value) {
        if (query.contains(entry.key)) {
          final modifiedQuery = generateVariation(query, entry.key, variant);

          if (title.contains(modifiedQuery)) {
            if (title.startsWith(modifiedQuery)) {
              bestScore = bestScore > 35 ? 35 : bestScore;
            } else {
              bestScore = bestScore > 45 ? 45 : bestScore;
            }
          }

          if (artist.contains(modifiedQuery)) {
            bestScore = bestScore > 50 ? 50 : bestScore;
          }
        }

        // Reverse check: if title/artist has the variant
        if (title.contains(entry.key) || artist.contains(entry.key)) {
          final modifiedQuery = generateVariation(query, variant, entry.key);

          if (title.contains(modifiedQuery) || artist.contains(modifiedQuery)) {
            bestScore = bestScore > 40 ? 40 : bestScore;
          }
        }
      }
    }

    return bestScore < 1000 ? bestScore : 0;
  }

  Future<void> _clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentKey);
    if (mounted) setState(() => _recent = []);
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final sug = await widget.repository.suggestions(query, limit: 5);
    if (!mounted) return;
    setState(() => _suggestions = sug);
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _recent = prefs.getStringList(_kRecentKey) ?? []);
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
    _performQuery(suggestion);
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

  Widget _buildResults() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final results = _buildGlobalResults();

    if (results.isEmpty && _ctrl.text.trim().isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No results found for "${_ctrl.text}"',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Try different keywords or check spelling',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final item = results[i];
        if (item is Artist) {
          return ArtistResultItem(
            artist: item,
            onTap: () => _onArtistTap(item),
          );
        }
        return SongResultItem(
          song: item,
          onTap: () => _onSongTap(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Discover',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          getProportionateScreenWidth(16),
          16,
          getProportionateScreenWidth(16),
          MediaQuery.of(context).padding.bottom + 24,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchField(),
            const SizedBox(height: 24),
            _buildSuggestions(),
            _buildRecent(),
            const SizedBox(height: 24),
            _buildResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.search_rounded, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search songs, artists...',
                border: InputBorder.none,
              ),
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.5)),
              onPressed: () {
                _ctrl.clear();
                _focusNode.requestFocus();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    if (_suggestions.isEmpty || !_isSearching) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _suggestions
          .map((s) => GlassChip(
        label: s,
        onTap: () => _applySuggestion(s),
        isSuggestion: true,
      ))
          .toList(),
    );
  }

  Widget _buildRecent() {
    if (_recent.isEmpty || _isSearching) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent searches',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _clearRecent,
              child: Text(
                'CLEAR',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recent
              .map(
                (r) => GlassChip(
              label: r,
              onTap: () => _applySuggestion(r),
              isSuggestion: false,
            ),
          )
              .toList(),
        ),
      ],
    );
  }
}