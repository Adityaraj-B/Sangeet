import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/repositories/search_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangeet/size_config.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/models/artist.dart';
import 'package:sangeet/screens/artist/artist_screen.dart';
import 'package:sangeet/services/remote_music_service.dart';

import 'components/search_field.dart';
import 'components/category_chips.dart';
import 'components/section_header.dart';
import 'components/shimmer_loading.dart';
import 'components/empty_search_state.dart';
import 'components/top_result_card.dart';
import 'components/artist_circle.dart';
import 'components/show_more_button.dart';
import 'components/search_suggestions.dart';
import 'components/recent_searches.dart';
import 'components/search_list_item.dart';

// Re-export SearchCategory from category_chips for backward compatibility
export 'components/category_chips.dart' show SearchCategory;

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

    // Fetch suggestions immediately (no debounce) for Spotify-like instant feel
    _fetchSuggestions(text);

    // Debounce the heavier search query
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 150), // Faster debounce for snappier feel
          () {
        if (mounted) _performQuery(text);
      },
    );
  }

  Future<void> _performQuery(String query) async {
    // Start searching after 2 characters (Spotify-like)
    if (query.trim().length < 2) {
      setState(() {
        _artists = [];
        _songs = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      // Fetch more results for better ranking/filtering
      final results = await Future.wait([
        widget.repository.search(query, limit: 25),
        widget.repository.searchArtists(query, limit: 8),
      ]);

      if (!mounted) return;

      setState(() {
        _songs = results[0] as List<Song>;
        _artists = results[1] as List<Artist>;
        _loading = false;
      });

      // Only add to recent if query is meaningful (3+ chars)
      if (query.trim().length >= 3) {
        await _addRecent(query);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Advanced global search with sophisticated ranking algorithm (Spotify-like)
  /// Prioritizes prefix matches and exact word matches for quick, relevant results
  List<dynamic> _buildGlobalResults() {
    final q = _ctrl.text.toLowerCase().trim();
    if (q.isEmpty) return [];

    // Normalize query for better matching
    final normalizedQuery = _normalizeString(q);
    final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();

    // Score songs with Spotify-like ranking (prefix matches prioritized)
    int scoreSong(Song s) {
      final title = _normalizeString(s.title.toLowerCase());
      final artist = _normalizeString(s.artist.toLowerCase());
      final firstArtist = artist.split(',').first.trim();

      int score = 1000; // Base score (lower is better)

      // === EXACT MATCHES (Highest Priority) ===
      if (title == normalizedQuery) return 0;
      if (artist == normalizedQuery || firstArtist == normalizedQuery) return 1;

      // === PREFIX MATCHES (Spotify prioritizes these heavily) ===
      // Title starts with query - this is what Spotify does best
      if (title.startsWith(normalizedQuery)) {
        // Shorter titles rank higher (more exact match)
        score = 2 + (title.length - normalizedQuery.length) ~/ 5;
        return score.clamp(2, 15);
      }

      // Artist starts with query
      if (firstArtist.startsWith(normalizedQuery)) {
        score = 10 + (firstArtist.length - normalizedQuery.length) ~/ 5;
        return score.clamp(10, 25);
      }

      // === WORD BOUNDARY MATCHES ===
      // Check if query matches the start of any word in title
      final titleWords = title.split(' ');
      for (int i = 0; i < titleWords.length; i++) {
        if (titleWords[i].startsWith(normalizedQuery)) {
          // Earlier word position = higher ranking
          score = 20 + (i * 5);
          return score.clamp(20, 50);
        }
      }

      // === MULTI-WORD QUERY MATCHING ===
      if (queryWords.length > 1) {
        // Check if all query words appear in order in title
        final allWordsInTitle = queryWords.every((word) => title.contains(word));
        final allWordsInArtist = queryWords.every((word) => artist.contains(word));
        final combinedText = '$title $artist';
        final allWordsInCombined = queryWords.every((word) => combinedText.contains(word));

        if (allWordsInTitle) {
          // Check if words appear in same order (phrase match)
          if (_isPhraseMatch(title, queryWords)) {
            return 25;
          }
          return 30;
        } else if (allWordsInCombined) {
          // Song + Artist combination match (e.g., "tum hi ho arijit")
          return 35;
        } else if (allWordsInArtist) {
          return 40;
        } else {
          // Partial word matching
          final matchingWords = queryWords.where((word) =>
            title.contains(word) || artist.contains(word)
          ).length;
          if (matchingWords == 0) return 1000; // No match
          score = 100 - (matchingWords * 20);
        }
      }

      // === CONTAINS MATCHES (Lower priority) ===
      if (title.contains(normalizedQuery)) {
        score = score > 60 ? 60 : score;
      } else if (artist.contains(normalizedQuery)) {
        score = score > 70 ? 70 : score;
      }

      // Bollywood pattern matching
      if (_matchesBollywoodPattern(s.title, s.artist, q)) {
        score = score > 25 ? 25 : score;
      }

      // Phonetic matching for Indian romanization
      final phoneticScore = _calculatePhoneticMatch(normalizedQuery, title, artist);
      if (phoneticScore > 0 && phoneticScore < score) {
        score = phoneticScore;
      }

      // Fuzzy matching for typos (only if no better match found)
      if (score > 100) {
        final titleSimilarity = _calculateSimilarity(normalizedQuery, title);
        final artistSimilarity = _calculateSimilarity(normalizedQuery, artist);

        if (titleSimilarity > 0.8) {
          score = 50;
        } else if (titleSimilarity > 0.6 || artistSimilarity > 0.7) {
          score = 70;
        } else if (titleSimilarity > 0.4 || artistSimilarity > 0.5) {
          score = 90;
        }
      }

      return score;
    }

    // Score artists with Spotify-like ranking
    int scoreArtist(Artist a) {
      final name = _normalizeString(a.name.toLowerCase());

      int score = 1000;

      // Exact match
      if (name == normalizedQuery) return 1; // Artists rank very high on exact match

      // Prefix match (Spotify-style)
      if (name.startsWith(normalizedQuery)) {
        score = 5 + (name.length - normalizedQuery.length) ~/ 3;
        return score.clamp(5, 20);
      }

      // Word boundary match
      final nameWords = name.split(' ');
      for (int i = 0; i < nameWords.length; i++) {
        if (nameWords[i].startsWith(normalizedQuery)) {
          score = 25 + (i * 5);
          return score.clamp(25, 45);
        }
      }

      // Multi-word matching
      if (queryWords.length > 1) {
        final allWordsInName = queryWords.every((word) => name.contains(word));
        if (allWordsInName) {
          return 30;
        }
        final matchingWords = queryWords.where((word) => name.contains(word)).length;
        if (matchingWords == 0) return 1000;
        score = 80 - (matchingWords * 15);
      }

      // Contains match
      if (name.contains(normalizedQuery)) {
        score = score > 55 ? 55 : score;
      }

      // Fuzzy matching
      if (score > 100) {
        final similarity = _calculateSimilarity(normalizedQuery, name);
        if (similarity > 0.7) {
          score = 60;
        } else if (similarity > 0.5) {
          score = 80;
        }
      }

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

    // Build results with Spotify-like organization
    final results = <dynamic>[];

    // Take top matches as they are (best relevance)
    final topMatches = scoredItems.take(3).map((e) => e.key).toList();
    results.addAll(topMatches);

    // Organize remaining: prioritize diversity with songs and artists mixed
    final remaining = scoredItems.skip(3).toList();
    final remainingSongs = remaining.where((e) => e.key is Song).toList();
    final remainingArtists = remaining.where((e) => e.key is Artist).toList();

    // Interleave: 3 songs, 1 artist pattern
    int songIdx = 0, artistIdx = 0;
    while (songIdx < remainingSongs.length || artistIdx < remainingArtists.length) {
      for (int i = 0; i < 3 && songIdx < remainingSongs.length; i++) {
        results.add(remainingSongs[songIdx++].key);
      }
      if (artistIdx < remainingArtists.length) {
        results.add(remainingArtists[artistIdx++].key);
      }
    }

    return results.take(20).toList(); // Return more results for better UX
  }

  /// Check if query words appear as a phrase (in order) in text
  bool _isPhraseMatch(String text, List<String> queryWords) {
    int lastIndex = -1;
    for (final word in queryWords) {
      final index = text.indexOf(word, lastIndex + 1);
      if (index == -1) return false;
      lastIndex = index;
    }
    return true;
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
    // Start suggesting after 2 characters (Spotify-like behavior)
    if (query.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }

    try {
      final sug = await widget.repository.suggestions(query, limit: 6);
      if (!mounted) return;
      setState(() => _suggestions = sug);
    } catch (_) {
      // Silently fail - suggestions are non-critical
    }
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
      return const ShimmerLoading();
    }

    final results = _buildGlobalResults();

    if (results.isEmpty && _ctrl.text.trim().isNotEmpty) {
      return EmptySearchState(query: _ctrl.text);
    }

    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    // Separate items by type
    final songs = results.whereType<Song>().toList();
    final artists = results.whereType<Artist>().toList();
    final topResult = results.isNotEmpty ? results.first : null;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey(_ctrl.text),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category filter chips
          CategoryChips(
            selectedCategory: _selectedCategory,
            songCount: songs.length,
            artistCount: artists.length,
            onCategoryChanged: (category) => setState(() => _selectedCategory = category),
          ),
          const SizedBox(height: 20),

          // Filtered results based on category
          if (_selectedCategory == SearchCategory.all) ...[
            // Top Result Section (Spotify-style)
            if (topResult != null) ...[
              const SectionHeader(title: 'Top result'),
              const SizedBox(height: 12),
              TopResultCard(
                item: topResult,
                onTap: () {
                  if (topResult is Song) {
                    _onSongTap(topResult);
                  } else {
                    _onArtistTap(topResult);
                  }
                },
              ),
              const SizedBox(height: 28),
            ],

            // Songs Section
            if (songs.isNotEmpty) ...[
              SectionHeader(title: 'Songs', count: songs.length),
              const SizedBox(height: 12),
              ...songs.take(4).map((song) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SongResultItem(
                  song: song,
                  onTap: () => _onSongTap(song),
                ),
              )),
              if (songs.length > 4)
                ShowMoreButton(
                  type: 'songs',
                  remaining: songs.length - 4,
                  onTap: () => setState(() => _selectedCategory = SearchCategory.songs),
                ),
              const SizedBox(height: 24),
            ],

            // Artists Section
            if (artists.isNotEmpty) ...[
              SectionHeader(title: 'Artists', count: artists.length),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: artists.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) => ArtistCircle(
                    artist: artists[i],
                    onTap: () => _onArtistTap(artists[i]),
                  ),
                ),
              ),
            ],
          ] else if (_selectedCategory == SearchCategory.songs) ...[
            SectionHeader(title: 'Songs', count: songs.length),
            const SizedBox(height: 12),
            ...songs.map((song) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SongResultItem(
                song: song,
                onTap: () => _onSongTap(song),
              ),
            )),
          ] else if (_selectedCategory == SearchCategory.artists) ...[
            SectionHeader(title: 'Artists', count: artists.length),
            const SizedBox(height: 12),
            ...artists.map((artist) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ArtistResultItem(
                artist: artist,
                onTap: () => _onArtistTap(artist),
              ),
            )),
          ],
        ],
      ),
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
            SearchField(
              controller: _ctrl,
              focusNode: _focusNode,
              onClear: () {
                _ctrl.clear();
                _focusNode.requestFocus();
                setState(() => _selectedCategory = SearchCategory.all);
              },
              onSubmitted: (_) => _performQuery(_ctrl.text),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
            _buildResults(),
          ],
        ),
      ),
    );
  }
}