import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../models/album.dart';
import '../data/genre_mappings.dart';
import 'remote_music_service.dart';
import 'recently_played.dart';
import 'like_service.dart';
import 'taste_profile_service.dart';

/// A smart home feed service that builds a Spotify / Amazon Prime Music–style
/// home feed using:
///  • Real playCount-based popularity ranking from JioSaavn API
///  • Time-of-day mood-aware queries (morning calm → evening party → night chill)
///  • Named popular artist queries (Arijit Singh, The Weeknd, AP Dhillon…)
///  • Personalization from both recently played + liked songs
///  • Song-suggestion API for deep "more like this" recommendations
///  • Artist diversity caps & language diversity
///  • Year-based freshness boosting
///  • In-memory caching (30 min TTL)
class HomeFeedService {
  // Singleton
  static HomeFeedService? _instance;
  factory HomeFeedService(RemoteMusicService musicService) {
    _instance ??= HomeFeedService._internal(musicService);
    return _instance!;
  }
  HomeFeedService._internal(this._musicService);

  final RemoteMusicService _musicService;
  final RecentlyPlayedService _recentService = RecentlyPlayedService();
  final TasteProfileService _tasteService = TasteProfileService();

  /// Set externally from home_body (where Provider context is available)
  LikeService? likeService;

  // ── Cache ──────────────────────────────────────────────────────
  static const Duration _cacheTTL = Duration(minutes: 30);
  DateTime? _cacheTimestamp;

  List<Song>? _cachedTrendingSongs;
  List<Album>? _cachedTrendingAlbums;
  List<Song>? _cachedPersonalizedSongs;
  List<Song>? _cachedNewReleases;
  List<Song>? _cachedMoodSongs;
  List<Album>? _cachedNewReleaseAlbums;
  List<BecauseSection>? _cachedBecauseSections;
  List<DailyMix>? _cachedDailyMixes;
  List<Song>? _cachedRediscoverSongs;
  String? _cachedMoodLabel;

  bool get _isCacheValid =>
      _cacheTimestamp != null &&
      DateTime.now().difference(_cacheTimestamp!) < _cacheTTL;

  void invalidateCache() {
    _cacheTimestamp = null;
    _cachedTrendingSongs = null;
    _cachedTrendingAlbums = null;
    _cachedPersonalizedSongs = null;
    _cachedNewReleases = null;
    _cachedMoodSongs = null;
    _cachedNewReleaseAlbums = null;
    _cachedBecauseSections = null;
    _cachedDailyMixes = null;
    _cachedRediscoverSongs = null;
    _cachedMoodLabel = null;
  }

  // ─────────────────────────────────────────────────────────────────
  //  QUERY POOLS — curated for real Bollywood / Indie / International
  // ─────────────────────────────────────────────────────────────────

  /// Named popular artists that yield high-quality trending results.
  /// Tagged by category so we can ensure category diversity in selection.
  static const List<String> _popularArtistQueries = [
    // Bollywood / Hindi — Romantic
    'Arijit Singh',
    'Shreya Ghoshal',
    'Atif Aslam',
    'Jubin Nautiyal',
    'Vishal Mishra',
    'Sachet Tandon',
    'Darshan Raval',
    'Armaan Malik',
    'B Praak',
    // Bollywood — Composers / Playback
    'Pritam',
    'A.R. Rahman',
    'Neha Kakkar',
    'Amit Trivedi',
    // Bollywood — Party / Rap
    'Badshah songs',
    'Yo Yo Honey Singh',
    'Raftaar',
    // Indie / Lofi
    'Anuv Jain',
    'Talwiinder',
    'Prateek Kuhad',
    'The Local Train',
    'When Chai Met Toast',
    // Punjabi
    'AP Dhillon',
    'Diljit Dosanjh',
    'Sidhu Moose Wala',
    'Karan Aujla',
    'Shubh',
    'Guru Randhawa',
    // International — Pop / R&B
    'The Weeknd',
    'Dua Lipa',
    'Taylor Swift',
    'Ed Sheeran',
    'Bruno Mars',
    'Billie Eilish',
    'Olivia Rodrigo',
    // International — Hip-Hop
    'Drake',
    'Post Malone',
    'Travis Scott',
    'Kendrick Lamar',
    // International — Rock / Alt
    'Coldplay',
    'Imagine Dragons',
    'OneRepublic',
  ];

  /// Genre / mood / chart-style queries — broader pool for trending diversity
  static const List<String> _genreQueries = [
    // Chart-style queries (most likely to return genuinely trending results)
    'bollywood hits 2026',
    'bollywood hits 2025',
    'top hindi songs 2026',
    'top hindi songs 2025',
    'viral hindi songs',
    'most played hindi songs',
    'chartbusters hindi',
    // Genre-specific
    'hindi romantic songs',
    'bollywood party songs',
    'hindi sad songs',
    'hindi lofi songs',
    'bollywood dance songs',
    'hindi unplugged',
    'hindi workout songs',
    'hindi road trip songs',
    // Punjabi
    'punjabi hits 2026',
    'punjabi hits 2025',
    'punjabi party songs',
    'trending punjabi songs',
    // English / International
    'top english pop songs',
    'english hits 2026',
    'top global songs',
    'trending english songs',
    // Cross-genre / Indie
    'indie hindi songs',
    'chill hindi vibes',
    'bollywood retro hits',
  ];

  /// Album-specific queries — wider range of album discovery angles
  static const List<String> _trendingAlbumQueries = [
    // Chart / recency queries
    'latest bollywood albums 2026',
    'latest bollywood albums 2025',
    'new hindi albums 2026',
    'new hindi albums 2025',
    'trending hindi albums',
    'top bollywood albums',
    'best bollywood albums',
    'new bollywood albums',
    'popular hindi albums',
    // Composer / artist-anchored (high-quality album results)
    'Arijit Singh album',
    'A.R. Rahman album',
    'Pritam album',
    'Amit Trivedi album',
    'Vishal-Shekhar album',
    'AP Dhillon album',
    'Diljit Dosanjh album',
    // Language diversity
    'latest punjabi albums',
    'new punjabi albums 2026',
    'bollywood soundtrack',
    'hindi movie soundtrack 2026',
    'hindi movie soundtrack 2025',
  ];

  /// New release queries
  static const List<String> _newReleaseQueries = [
    'new songs 2026',
    'latest hindi songs 2026',
    'new bollywood songs 2026',
    'new releases hindi',
    'new punjabi songs 2026',
    'new english songs 2026',
    'just released songs',
    'brand new hindi songs',
  ];

  // ── Mood / Time-of-Day Queries ─────────────────────────────────

  static const Map<String, List<String>> _moodQueries = {
    'morning': [
      'hindi morning songs',
      'bollywood soulful songs',
      'hindi unplugged',
      'peaceful hindi songs',
      'hindi devotional songs',
      'soft bollywood songs',
      'morning vibes hindi',
      'calm hindi music',
    ],
    'afternoon': [
      'bollywood feel good songs',
      'hindi upbeat songs',
      'happy bollywood songs',
      'hindi pop songs',
      'bollywood road trip songs',
      'motivational hindi songs',
      'bollywood summer songs',
      'hindi chill songs',
    ],
    'evening': [
      'bollywood party songs',
      'hindi dance songs',
      'punjabi party songs',
      'bollywood club songs',
      'hindi party hits',
      'AP Dhillon party',
      'hindi workout songs',
      'bollywood dj songs',
    ],
    'night': [
      'hindi lofi songs',
      'bollywood romantic songs',
      'hindi sad songs',
      'late night bollywood',
      'hindi chill songs',
      'bollywood unplugged night',
      'Arijit Singh romantic',
      'hindi sleep songs',
    ],
  };

  String get _currentMood {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  // ── Public API ─────────────────────────────────────────────────

  /// Fetch all home feed data in one optimized call.
  Future<HomeFeedData> loadHomeFeed() async {
    if (_isCacheValid &&
        _cachedTrendingSongs != null &&
        _cachedTrendingAlbums != null) {
      return HomeFeedData(
        trendingSongs: _cachedTrendingSongs!,
        trendingAlbums: _cachedTrendingAlbums!,
        personalizedSongs: _cachedPersonalizedSongs ?? [],
        newReleases: _cachedNewReleases ?? [],
        moodSongs: _cachedMoodSongs ?? [],
        newReleaseAlbums: _cachedNewReleaseAlbums ?? [],
        moodLabel: _cachedMoodLabel ?? _moodLabel,
        becauseSections: _cachedBecauseSections ?? [],
        dailyMixes: _cachedDailyMixes ?? [],
        rediscoverSongs: _cachedRediscoverSongs ?? [],
      );
    }

    // Rebuild the taste profile before generating the feed
    await _tasteService.rebuildProfile(
      recentService: _recentService,
      likeService: likeService,
    );

    // Fire all fetches in parallel.
    // _fetchRediscoverSongs is purely local (no API calls).
    // _fetchDailyMixes uses 2-3 targeted queries per mix (max 9 new API calls).
    final results = await Future.wait([
      _fetchSmartTrendingSongs(),       // 0
      _fetchSmartTrendingAlbums(),      // 1
      _fetchPersonalizedSongs(),        // 2
      _fetchNewReleases(),              // 3
      _fetchMoodBasedSongs(),           // 4
      _fetchNewReleaseAlbums(),         // 5
      _fetchBecauseYouListened(),       // 6
      _fetchRediscoverSongs(),          // 7  (no API calls — local data only)
      _fetchDailyMixes(),              // 8
    ]);

    _cachedTrendingSongs = results[0] as List<Song>;
    _cachedTrendingAlbums = results[1] as List<Album>;
    _cachedPersonalizedSongs = results[2] as List<Song>;
    _cachedNewReleases = results[3] as List<Song>;
    _cachedMoodSongs = results[4] as List<Song>;
    _cachedNewReleaseAlbums = results[5] as List<Album>;
    _cachedBecauseSections = results[6] as List<BecauseSection>;
    _cachedRediscoverSongs = results[7] as List<Song>;
    _cachedDailyMixes = results[8] as List<DailyMix>;
    _cachedMoodLabel = _moodLabel;
    _cacheTimestamp = DateTime.now();

    // Cross-section deduplication + overplayed filtering
    final trendingIds = _cachedTrendingSongs!.map((s) => s.id).toSet();
    _cachedPersonalizedSongs!.removeWhere((s) =>
        trendingIds.contains(s.id) || _tasteService.isOverplayed(s.id));
    _cachedNewReleases!.removeWhere((s) =>
        trendingIds.contains(s.id) || _tasteService.isOverplayed(s.id));
    _cachedMoodSongs!.removeWhere((s) =>
        trendingIds.contains(s.id) || _tasteService.isOverplayed(s.id));

    final personalizedIds = _cachedPersonalizedSongs!.map((s) => s.id).toSet();
    _cachedMoodSongs!.removeWhere((s) => personalizedIds.contains(s.id));
    _cachedNewReleases!.removeWhere((s) => personalizedIds.contains(s.id));

    // Filter "because" section songs against all other sections
    final allShownIds = {
      ...trendingIds,
      ...personalizedIds,
      ..._cachedNewReleases!.map((s) => s.id),
      ..._cachedMoodSongs!.map((s) => s.id),
    };
    for (final section in _cachedBecauseSections!) {
      section.recommendations.removeWhere((s) =>
          allShownIds.contains(s.id) || _tasteService.isOverplayed(s.id));
    }
    _cachedBecauseSections!.removeWhere((s) => s.recommendations.isEmpty);

    // Deduplicate daily mix songs against all shown sections
    for (final mix in _cachedDailyMixes!) {
      mix.songs.removeWhere((s) => allShownIds.contains(s.id));
    }
    _cachedDailyMixes!.removeWhere((m) => m.songs.length < 5);

    return HomeFeedData(
      trendingSongs: _cachedTrendingSongs!,
      trendingAlbums: _cachedTrendingAlbums!,
      personalizedSongs: _cachedPersonalizedSongs!,
      newReleases: _cachedNewReleases!,
      moodSongs: _cachedMoodSongs!,
      newReleaseAlbums: _cachedNewReleaseAlbums!,
      moodLabel: _cachedMoodLabel!,
      becauseSections: _cachedBecauseSections!,
      dailyMixes: _cachedDailyMixes!,
      rediscoverSongs: _cachedRediscoverSongs!,
    );
  }

  String get _moodLabel {
    switch (_currentMood) {
      case 'morning':
        return 'Morning Calm';
      case 'afternoon':
        return 'Afternoon Vibes';
      case 'evening':
        return 'Evening Energy';
      case 'night':
        return 'Late Night Chill';
      default:
        return 'For Your Mood';
    }
  }

  // ── Private Fetchers ───────────────────────────────────────────

  /// Smart trending songs with multi-signal ranking:
  ///  1. Blend native trending API + artist queries + genre/chart queries
  ///  2. Cross-appearance boost — songs appearing in multiple query results
  ///     are genuinely viral and get a score multiplier
  ///  3. Freshness-weighted popularity scoring
  ///  4. Language diversity enforcement (Hindi / Punjabi / English mix)
  ///  5. Artist diversity cap
  Future<List<Song>> _fetchSmartTrendingSongs() async {
    try {
      // ── Build a wide query pool ──
      // Pick 4 popular artist queries + 4 genre/chart queries + native trending
      final artistQueries = _pickRandom(_popularArtistQueries, 4);
      final genreQs = _pickRandom(_genreQueries, 4);
      final allQueries = [...artistQueries, ...genreQs];

      // Fire all searches + native trending endpoint in parallel
      final searchFutures = allQueries.map(
        (q) => _musicService.searchSongs(q, limit: 30),
      );
      final results = await Future.wait([
        ...searchFutures,
        _musicService.getTrending(), // native trending as baseline signal
      ]);

      // ── Merge, deduplicate, and track cross-appearance ──
      final songById = <String, Song>{};
      final appearanceCount = <String, int>{}; // how many queries returned this song

      for (final batch in results) {
        final batchIds = <String>{}; // track within this batch to avoid double-counting
        for (final song in batch) {
          if (song.id.isEmpty) continue;
          songById.putIfAbsent(song.id, () => song);
          if (batchIds.add(song.id)) {
            appearanceCount[song.id] = (appearanceCount[song.id] ?? 0) + 1;
          }
        }
      }

      final allSongs = songById.values.toList();

      // ── Multi-signal popularity scoring ──
      // Blend: playCount × freshness × cross-appearance boost
      allSongs.sort((a, b) {
        final aScore = _trendingScore(a, appearanceCount[a.id] ?? 1);
        final bScore = _trendingScore(b, appearanceCount[b.id] ?? 1);
        return bScore.compareTo(aScore);
      });

      // ── Artist diversity: max 3 songs per primary artist ──
      final diverseSongs = _enforceArtistDiversity(allSongs, maxPerArtist: 3);

      // ── Language diversity: ensure a mix ──
      final balanced = _enforceLanguageDiversity(diverseSongs, targetSize: 40);

      // ── Tiered shuffle for organic feel (tiers of 8) ──
      _tieredShuffle(balanced, tierSize: 8);

      return balanced.take(30).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching smart trending songs: $e');
      return _musicService.getTrending();
    }
  }

  /// Smart trending albums with multi-signal ranking:
  ///  1. Blend native trending albums API + search queries
  ///  2. Year-based freshness scoring (recent albums rank higher)
  ///  3. Song count as quality proxy (bigger albums = more significant releases)
  ///  4. Artist diversity cap
  ///  5. Filter out very old albums that aren't genuinely trending
  Future<List<Album>> _fetchSmartTrendingAlbums() async {
    try {
      final queries = _pickRandom(_trendingAlbumQueries, 6);

      // Fire all search queries + native trending albums endpoint in parallel
      final searchFutures = queries.map(
        (q) => _musicService.searchAlbums(q, limit: 30),
      );
      final results = await Future.wait([
        ...searchFutures,
        _musicService.getTrendingAlbums(), // native trending baseline
      ]);

      // ── Merge, deduplicate, and track cross-appearance ──
      final albumById = <String, Album>{};
      final appearanceCount = <String, int>{};

      for (final batch in results) {
        final batchIds = <String>{};
        for (final album in batch) {
          if (album.id.isEmpty) continue;
          albumById.putIfAbsent(album.id, () => album);
          if (batchIds.add(album.id)) {
            appearanceCount[album.id] = (appearanceCount[album.id] ?? 0) + 1;
          }
        }
      }

      final allAlbums = albumById.values.toList();

      // ── Multi-signal scoring: year freshness + songCount + cross-appearance ──
      allAlbums.sort((a, b) {
        final aScore = _albumTrendingScore(a, appearanceCount[a.id] ?? 1);
        final bScore = _albumTrendingScore(b, appearanceCount[b.id] ?? 1);
        return bScore.compareTo(aScore);
      });

      // ── Artist diversity: max 2 albums per artist ──
      final diverseAlbums = _enforceAlbumArtistDiversity(allAlbums, maxPerArtist: 2);

      // ── Gentle tiered shuffle within quality tiers of 6 ──
      _hourlyShuffleAlbumsTiered(diverseAlbums, tierSize: 6);

      return diverseAlbums.take(20).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching smart trending albums: $e');
      return _musicService.getTrendingAlbums();
    }
  }

  /// Personalized songs based on the user's full taste profile:
  ///  1. Top artists from taste profile (up to 6)
  ///  2. Top genre queries from taste profile (up to 3)
  ///  3. Song suggestions API for recent songs (up to 3)
  ///  4. Re-ranked by taste affinity score blended with API playCount
  Future<List<Song>> _fetchPersonalizedSongs() async {
    try {
      final recentSongs = await _recentService.getRecentlyPlayed(limit: 30);
      final likedSongs = likeService?.likedSongs ?? [];

      if (recentSongs.isEmpty && likedSongs.isEmpty) return [];

      // Use taste profile for deeper artist + genre queries
      final topArtists = _tasteService.topArtists(6);
      final topGenres = _tasteService.topGenres(3);

      final futures = <Future<List<Song>>>[];

      // Search for each top artist from the taste profile
      for (final artist in topArtists) {
        futures.add(_musicService.searchSongs(artist));
      }

      // Genre-based discovery queries from the taste profile
      for (final genre in topGenres) {
        final queries = genreSearchQueries[genre];
        if (queries != null && queries.isNotEmpty) {
          final query = (queries.toList()..shuffle()).first;
          futures.add(_musicService.searchSongs(query));
        }
      }

      // Song suggestions for up to 3 diverse recent songs
      final diverseRecent = _pickDiverseSeeds(recentSongs, 3);
      for (final song in diverseRecent) {
        futures.add(_musicService.getSongSuggestions(song.id));
      }

      final results = await Future.wait(futures);

      // Merge, deduplicate, exclude already-played songs
      final excludeIds = <String>{
        ...recentSongs.take(20).map((s) => s.id),
        ...likedSongs.map((s) => s.id),
      };
      final seenIds = <String>{};
      final allSongs = <Song>[];

      for (final batch in results) {
        for (final song in batch) {
          if (song.id.isNotEmpty &&
              !excludeIds.contains(song.id) &&
              !_tasteService.isOverplayed(song.id) &&
              !_tasteService.wasSkipped(song.id) &&
              seenIds.add(song.id)) {
            allSongs.add(song);
          }
        }
      }

      // Re-rank by blending taste affinity with API popularity
      _rankByTasteAffinity(allSongs);
      final diverseSongs = _enforceArtistDiversity(allSongs, maxPerArtist: 3);
      _tieredShuffle(diverseSongs);

      // ── Discovery boost: reserve ~20% of slots for unknown artists ──
      // This prevents the "filter bubble" — always show some fresh discovery.
      final knownSlots = (20 * 0.80).round(); // 16 familiar songs
      final discoverySlots = 20 - knownSlots;  // 4 discovery songs

      final known = <Song>[];
      final discovery = <Song>[];
      for (final song in diverseSongs) {
        final primaryArtist = _primaryArtist(song.artist);
        if (_tasteService.isUnknownArtist(primaryArtist) && discovery.length < discoverySlots) {
          discovery.add(song);
        } else if (known.length < knownSlots) {
          known.add(song);
        }
        if (known.length + discovery.length >= 20) break;
      }

      // Interleave: insert discovery songs at positions 4, 9, 14, 19
      final merged = <Song>[...known];
      for (int i = 0; i < discovery.length; i++) {
        final insertAt = ((i + 1) * 5 - 1).clamp(0, merged.length);
        merged.insert(insertAt, discovery[i]);
      }

      return merged.take(20).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching personalized songs: $e');
      return [];
    }
  }

  /// "Because you listened to X" — pick 3 diverse seed songs and get
  /// suggestions for each, returned as labelled sections.
  Future<List<BecauseSection>> _fetchBecauseYouListened() async {
    try {
      final recentSongs = await _recentService.getRecentlyPlayed(limit: 20);
      if (recentSongs.length < 2) return [];

      final seeds = _pickDiverseSeeds(recentSongs, 3);
      final sections = <BecauseSection>[];

      for (final seed in seeds) {
        if (seed.id.isEmpty) continue;
        try {
          var suggestions = await _musicService.getSongSuggestions(seed.id);

          // Filter out overplayed and the seed itself
          suggestions = suggestions.where((s) =>
              s.id != seed.id &&
              !_tasteService.isOverplayed(s.id) &&
              !_tasteService.wasSkipped(s.id)
          ).toList();

          // Re-rank by affinity
          _rankByTasteAffinity(suggestions);
          final diverse = _enforceArtistDiversity(suggestions, maxPerArtist: 2);

          if (diverse.isNotEmpty) {
            sections.add(BecauseSection(
              seedSong: seed,
              recommendations: diverse.take(10).toList(),
            ));
          }
        } catch (_) {
          continue;
        }
      }

      return sections.take(3).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching because-you-listened: $e');
      return [];
    }
  }

  /// Pick up to [count] seeds from [songs] with distinct primary artists
  /// so that "because" sections cover different tastes.
  List<Song> _pickDiverseSeeds(List<Song> songs, int count) {
    final seenArtists = <String>{};
    final seeds = <Song>[];
    for (final song in songs) {
      final artist = _primaryArtist(song.artist).toLowerCase();
      if (seenArtists.add(artist) && song.id.isNotEmpty) {
        seeds.add(song);
        if (seeds.length >= count) break;
      }
    }
    return seeds;
  }

  /// Rank songs by blending taste affinity (70%) with normalised API
  /// popularity (30%). Songs the user would love surface higher even
  /// if their absolute play count is lower.
  void _rankByTasteAffinity(List<Song> songs) {
    if (!_tasteService.hasProfile) {
      _sortByPopularity(songs);
      return;
    }

    // Find max play count for normalisation
    final maxPC = songs.fold<int>(1, (m, s) => max(m, s.playCount ?? 0));

    songs.sort((a, b) {
      final aAffinity = _tasteService.affinityScore(a);
      final bAffinity = _tasteService.affinityScore(b);
      final aPop = (a.playCount ?? 0) / maxPC;
      final bPop = (b.playCount ?? 0) / maxPC;
      final aScore = aAffinity * 0.7 + aPop * 0.3;
      final bScore = bAffinity * 0.7 + bPop * 0.3;
      return bScore.compareTo(aScore);
    });
  }

  /// New releases: recent songs from 2025–2026, sorted by play count.
  Future<List<Song>> _fetchNewReleases() async {
    try {
      final queries = _pickRandom(_newReleaseQueries, 3);

      final results = await Future.wait(
        queries.map((q) => _musicService.searchSongs(q)),
      );

      final seenIds = <String>{};
      final allSongs = <Song>[];
      for (final batch in results) {
        for (final song in batch) {
          if (song.id.isNotEmpty && seenIds.add(song.id)) {
            allSongs.add(song);
          }
        }
      }

      // Boost songs from 2025/2026, filter out very old songs
      final recentSongs = allSongs.where((s) {
        final y = int.tryParse(s.year ?? '') ?? 0;
        return y >= 2024; // Only keep songs from last ~2 years
      }).toList();

      // If filter removed too many, fall back to all
      final pool = recentSongs.length >= 5 ? recentSongs : allSongs;

      _sortByPopularity(pool);
      final diverseSongs = _enforceArtistDiversity(pool, maxPerArtist: 2);

      return diverseSongs.take(15).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching new releases: $e');
      return [];
    }
  }

  /// Mood-based songs according to time of day, personalised by:
  ///  1. The user's contextual listening patterns (what they actually play at
  ///     this time of day / weekends).
  ///  2. Language preference from taste profile.
  ///  3. Fallback to curated generic mood queries.
  Future<List<Song>> _fetchMoodBasedSongs() async {
    try {
      final mood = _currentMood;
      final moodPool = _moodQueries[mood] ?? _moodQueries['afternoon']!;

      // ── Contextual personalisation ──
      // Check what the user actually listens to at this time slot.
      // Also check 'weekend' slot if today is a weekend.
      final isWeekend = DateTime.now().weekday == DateTime.saturday ||
          DateTime.now().weekday == DateTime.sunday;
      final contextSlot = isWeekend ? 'weekend' : mood;
      final contextGenres = _tasteService.topContextualGenres(contextSlot, 2);
      final contextArtists = _tasteService.topContextualArtists(contextSlot, 2);

      List<String> augmentedPool = List.from(moodPool);

      // Add queries based on what the user actually listens to at this time
      for (final genre in contextGenres) {
        final queries = genreSearchQueries[genre];
        if (queries != null && queries.isNotEmpty) {
          augmentedPool.add((queries.toList()..shuffle()).first);
        }
      }
      for (final artist in contextArtists) {
        augmentedPool.add('$artist songs');
      }

      // If user has a language preference, add language-specific mood queries
      final topLangs = _tasteService.topLanguages(1);
      if (topLangs.isNotEmpty) {
        final lang = topLangs.first;
        if (lang != 'hindi' && lang != 'english') {
          augmentedPool.addAll([
            '$lang $mood songs',
            '$lang chill songs',
            'best $lang songs',
          ]);
        }
      }

      final queries = _pickRandom(augmentedPool, 3);

      final results = await Future.wait(
        queries.map((q) => _musicService.searchSongs(q)),
      );

      final seenIds = <String>{};
      final allSongs = <Song>[];
      for (final batch in results) {
        for (final song in batch) {
          if (song.id.isNotEmpty &&
              seenIds.add(song.id) &&
              !_tasteService.isOverplayed(song.id)) {
            allSongs.add(song);
          }
        }
      }

      _rankByTasteAffinity(allSongs);
      final diverseSongs = _enforceArtistDiversity(allSongs, maxPerArtist: 2);
      _tieredShuffle(diverseSongs);

      return diverseSongs.take(15).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching mood songs: $e');
      return [];
    }
  }

  /// New release albums.
  Future<List<Album>> _fetchNewReleaseAlbums() async {
    try {
      final queries = _pickRandom([
        'new album releases 2026',
        'latest bollywood albums 2026',
        'new hindi albums',
        'new punjabi albums 2026',
      ], 2);

      final results = await Future.wait(
        queries.map((q) => _musicService.searchAlbums(q)),
      );

      final seenIds = <String>{};
      final allAlbums = <Album>[];
      for (final batch in results) {
        for (final album in batch) {
          if (album.id.isNotEmpty && seenIds.add(album.id)) {
            allAlbums.add(album);
          }
        }
      }

      final diverseAlbums =
          _enforceAlbumArtistDiversity(allAlbums, maxPerArtist: 2);
      _hourlyShuffleAlbumsTiered(diverseAlbums);

      return diverseAlbums.take(15).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching new release albums: $e');
      return [];
    }
  }

  // ── Rediscover / Throwback ────────────────────────────────────

  /// Songs the user loved (played 2+ times) but hasn't played in 14–90 days.
  /// Purely local — no API calls at all.
  Future<List<Song>> _fetchRediscoverSongs() async {
    try {
      final allRecent = await _recentService.getRecentWithTimestamps(limit: 200);
      if (allRecent.isEmpty) return [];

      final now = DateTime.now();
      final candidates = <Song>[];

      for (final item in allRecent) {
        final song = item['song'] as Song;
        final playedAt = item['playedAt'] as DateTime;
        final playCount = item['playCount'] as int? ?? 1;
        final daysAgo = now.difference(playedAt).inDays;

        // Songs played 2+ times, between 14 and 90 days ago
        if (daysAgo >= 14 && daysAgo <= 90 && playCount >= 2) {
          candidates.add(song);
        }
      }

      // Enforce artist diversity so it's not all one artist
      final diverse = _enforceArtistDiversity(candidates, maxPerArtist: 2);

      // Light shuffle seeded by day so it changes daily
      final seed = now.day + now.month * 31;
      diverse.shuffle(Random(seed));

      return diverse.take(10).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching rediscover songs: $e');
      return [];
    }
  }

  // ── Daily Mixes ───────────────────────────────────────────────

  /// Generate up to 3 daily mixes based on the user's taste clusters.
  /// Each mix makes at most 3 API calls to keep rate limits in check.
  ///
  ///  • Mix 1 — "Your Top Artists": songs by user's top 3 artists
  ///  • Mix 2 — "Genre Discovery": top genre, but prefer unknown artists
  ///  • Mix 3 — "Time Capsule": contextual (what you play at this time)
  Future<List<DailyMix>> _fetchDailyMixes() async {
    try {
      if (!_tasteService.hasProfile) return [];

      final mixes = <DailyMix>[];

      // ── Mix 1: Top Artists Mix ──
      // Search for user's top 3 artists (3 API calls)
      final topArtists = _tasteService.topArtists(3);
      if (topArtists.isNotEmpty) {
        final artistResults = await Future.wait(
          topArtists.map((a) => _musicService.searchSongs(a)),
        );

        final seenIds = <String>{};
        final mixSongs = <Song>[];
        for (final batch in artistResults) {
          for (final song in batch) {
            if (song.id.isNotEmpty &&
                !_tasteService.isOverplayed(song.id) &&
                !_tasteService.wasSkipped(song.id) &&
                seenIds.add(song.id)) {
              mixSongs.add(song);
            }
          }
        }
        _sortByPopularity(mixSongs);
        final diverse = _enforceArtistDiversity(mixSongs, maxPerArtist: 4);
        _tieredShuffle(diverse, tierSize: 6);

        if (diverse.length >= 5) {
          mixes.add(DailyMix(
            title: 'Your Top Artists',
            subtitle: topArtists.take(3).join(', '),
            icon: '🎤',
            songs: diverse.take(20).toList(),
            accentColorHex: 0xFFFF6B6B,
          ));
        }
      }

      // ── Mix 2: Genre Discovery Mix ──
      // Search by top genre but filter to artists the user hasn't heard
      final topGenres = _tasteService.topGenres(2);
      if (topGenres.isNotEmpty) {
        final genreQueryPool = <String>[];
        for (final genre in topGenres) {
          final queries = genreSearchQueries[genre];
          if (queries != null) {
            genreQueryPool.addAll(queries);
          }
        }

        if (genreQueryPool.isNotEmpty) {
          // Pick 2 random genre queries (2 API calls)
          final pickedGenreQs = _pickRandom(genreQueryPool, 2);
          final genreResults = await Future.wait(
            pickedGenreQs.map((q) => _musicService.searchSongs(q)),
          );

          final seenIds = <String>{};
          final mixSongs = <Song>[];
          for (final batch in genreResults) {
            for (final song in batch) {
              if (song.id.isNotEmpty &&
                  !_tasteService.isOverplayed(song.id) &&
                  seenIds.add(song.id)) {
                mixSongs.add(song);
              }
            }
          }

          // Prefer songs from unknown artists (discovery!)
          final unknownArtistSongs = <Song>[];
          final knownArtistSongs = <Song>[];
          for (final song in mixSongs) {
            if (_tasteService.isUnknownArtist(_primaryArtist(song.artist))) {
              unknownArtistSongs.add(song);
            } else {
              knownArtistSongs.add(song);
            }
          }

          // Merge: unknown first, then fill with known
          final merged = [...unknownArtistSongs, ...knownArtistSongs];
          final diverse = _enforceArtistDiversity(merged, maxPerArtist: 2);
          _tieredShuffle(diverse, tierSize: 6);

          if (diverse.length >= 5) {
            mixes.add(DailyMix(
              title: 'Discover ${topGenres.first}',
              subtitle: 'Fresh finds in your favourite genre',
              icon: '🔮',
              songs: diverse.take(20).toList(),
              accentColorHex: 0xFF6B8AFF,
            ));
          }
        }
      }

      // ── Mix 3: Contextual / Time Capsule Mix ──
      // Based on what the user plays at the current time slot.
      // Uses contextual artists (2 API calls max).
      final isWeekend = DateTime.now().weekday == DateTime.saturday ||
          DateTime.now().weekday == DateTime.sunday;
      final slot = isWeekend ? 'weekend' : _currentMood;
      final ctxArtists = _tasteService.topContextualArtists(slot, 2);

      if (ctxArtists.isNotEmpty) {
        final ctxResults = await Future.wait(
          ctxArtists.map((a) => _musicService.searchSongs(a)),
        );

        final seenIds = <String>{};
        final mixSongs = <Song>[];
        for (final batch in ctxResults) {
          for (final song in batch) {
            if (song.id.isNotEmpty &&
                !_tasteService.isOverplayed(song.id) &&
                seenIds.add(song.id)) {
              mixSongs.add(song);
            }
          }
        }
        _rankByTasteAffinity(mixSongs);
        final diverse = _enforceArtistDiversity(mixSongs, maxPerArtist: 3);
        _tieredShuffle(diverse, tierSize: 6);

        final slotLabel = isWeekend
            ? 'Weekend'
            : {
                'morning': 'Morning',
                'afternoon': 'Afternoon',
                'evening': 'Evening',
                'night': 'Late Night',
              }[slot] ?? 'Your';

        if (diverse.length >= 5) {
          mixes.add(DailyMix(
            title: '$slotLabel Mix',
            subtitle: 'What you love at this hour',
            icon: isWeekend ? '🌴' : {'morning': '☀️', 'afternoon': '🌤️', 'evening': '🌆', 'night': '🌙'}[slot] ?? '🎵',
            songs: diverse.take(20).toList(),
            accentColorHex: 0xFFFFB86B,
          ));
        }
      }

      return mixes;
    } catch (e) {
      if (kDebugMode) debugPrint('Error generating daily mixes: $e');
      return [];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  /// Pick [count] random items from a list, seeded by
  /// current hour + day so results rotate hourly but stay stable within an hour.
  List<String> _pickRandom(List<String> pool, int count) {
    final now = DateTime.now();
    final seed = now.hour + now.day * 100 + now.month * 10000;
    final random = Random(seed);
    final shuffled = List<String>.from(pool)..shuffle(random);
    return shuffled.take(count.clamp(1, pool.length)).toList();
  }

  /// Extract the primary (first) artist name from a comma / & separated string.
  String _primaryArtist(String artistField) {
    final parts = artistField.split(RegExp(r'[,&]'));
    return parts.first.trim();
  }

  // ── Trending Song Scoring ──────────────────────────────────────

  /// Multi-signal trending score for a song.
  ///  • playCount (log-scaled so mega-hits don't crush everything)
  ///  • freshness multiplier (2026 > 2025 > 2024 > older)
  ///  • cross-appearance boost (appeared in N query results → multiplier)
  double _trendingScore(Song song, int appearances) {
    // Log-scale the play count to avoid mega-hits dominating.
    // +1 to handle 0/null; log10(1) = 0, log10(1M) ≈ 6.
    final rawPC = (song.playCount ?? 0).toDouble();
    final logPopularity = rawPC > 0 ? log(rawPC + 1) / ln10 : 0.0;

    // Freshness multiplier
    final y = int.tryParse(song.year ?? '') ?? 0;
    double freshness = 1.0;
    if (y >= 2026) {
      freshness = 2.5;
    } else if (y >= 2025) {
      freshness = 1.8;
    } else if (y >= 2024) {
      freshness = 1.3;
    } else if (y >= 2022) {
      freshness = 1.0;
    } else if (y >= 2020) {
      freshness = 0.8;
    } else if (y > 0) {
      freshness = 0.5; // classics still appear but rank lower
    }

    // Cross-appearance boost: if a song shows up in multiple query results,
    // it's genuinely trending across categories. Each extra appearance adds 30%.
    final crossBoost = 1.0 + (appearances - 1) * 0.3;

    return logPopularity * freshness * crossBoost;
  }

  // ── Trending Album Scoring ─────────────────────────────────────

  /// Multi-signal trending score for an album.
  ///  • Year freshness (recent albums score higher)
  ///  • Song count as quality proxy (full albums > singles)
  ///  • Cross-appearance boost
  double _albumTrendingScore(Album album, int appearances) {
    final y = int.tryParse(album.year) ?? 0;

    // Freshness score: 0.0–10.0
    double freshness = 1.0;
    if (y >= 2026) {
      freshness = 10.0;
    } else if (y >= 2025) {
      freshness = 7.0;
    } else if (y >= 2024) {
      freshness = 5.0;
    } else if (y >= 2022) {
      freshness = 3.0;
    } else if (y >= 2020) {
      freshness = 2.0;
    } else if (y > 0) {
      freshness = 1.0;
    }

    // Song count quality signal: albums with more songs are more significant.
    // Clamp to avoid penalizing singles too much and capping large compilations.
    final songCountBonus = (album.songCount.clamp(1, 20)).toDouble() / 10.0;

    // Cross-appearance boost
    final crossBoost = 1.0 + (appearances - 1) * 0.4;

    return freshness * (1.0 + songCountBonus) * crossBoost;
  }

  // ── Sorting & Diversity Helpers ────────────────────────────────

  /// Sort songs by playCount descending with freshness boost.
  /// Songs from 2025–2026 get a multiplier so they surface higher.
  void _sortByPopularity(List<Song> songs) {
    songs.sort((a, b) {
      final aScore = _popularityScore(a);
      final bScore = _popularityScore(b);
      return bScore.compareTo(aScore);
    });
  }

  double _popularityScore(Song song) {
    final baseCount = (song.playCount ?? 0).toDouble();
    final y = int.tryParse(song.year ?? '') ?? 0;

    double freshness = 1.0;
    if (y >= 2026) {
      freshness = 2.5;
    } else if (y >= 2025) {
      freshness = 1.8;
    } else if (y >= 2024) {
      freshness = 1.3;
    } else if (y >= 2022) {
      freshness = 1.0;
    } else if (y > 0) {
      freshness = 0.7;
    }

    return baseCount * freshness;
  }

  /// Tiered shuffle: divide into tiers of [tierSize] and shuffle within each
  /// tier. This keeps overall quality ordering but adds organic variety.
  void _tieredShuffle(List<Song> songs, {int tierSize = 10}) {
    final seed = DateTime.now().hour + DateTime.now().day * 31;
    final random = Random(seed);
    for (int i = 0; i < songs.length; i += tierSize) {
      final end = (i + tierSize).clamp(0, songs.length);
      final tier = songs.sublist(i, end);
      tier.shuffle(random);
      songs.replaceRange(i, end, tier);
    }
  }

  /// Enforce language diversity: ensure the top [targetSize] songs have a mix
  /// of languages. Reserves slots: ~60% Hindi, ~20% Punjabi, ~15% English,
  /// ~5% other, but fills greedily from whatever is available.
  List<Song> _enforceLanguageDiversity(List<Song> songs, {int targetSize = 40}) {
    if (songs.length <= targetSize) return songs;

    // Bucket songs by language
    final hindi = <Song>[];
    final punjabi = <Song>[];
    final english = <Song>[];
    final other = <Song>[];

    for (final song in songs) {
      final lang = (song.language ?? '').toLowerCase();
      if (lang == 'hindi') {
        hindi.add(song);
      } else if (lang == 'punjabi') {
        punjabi.add(song);
      } else if (lang == 'english') {
        english.add(song);
      } else {
        other.add(song);
      }
    }

    // Allocate proportional slots, but fill from what's available
    final result = <Song>[];
    final seenIds = <String>{};

    void addFromBucket(List<Song> bucket, int maxCount) {
      int added = 0;
      for (final song in bucket) {
        if (added >= maxCount) break;
        if (seenIds.add(song.id)) {
          result.add(song);
          added++;
        }
      }
    }

    // Primary allocation
    addFromBucket(hindi, (targetSize * 0.55).round());
    addFromBucket(punjabi, (targetSize * 0.20).round());
    addFromBucket(english, (targetSize * 0.15).round());
    addFromBucket(other, (targetSize * 0.10).round());

    // Fill remaining slots from the full sorted list
    if (result.length < targetSize) {
      for (final song in songs) {
        if (result.length >= targetSize) break;
        if (seenIds.add(song.id)) {
          result.add(song);
        }
      }
    }

    return result;
  }

  /// Limit songs to [maxPerArtist] per primary artist.
  List<Song> _enforceArtistDiversity(
      List<Song> songs, {int maxPerArtist = 3}) {
    final artistCount = <String, int>{};
    final result = <Song>[];

    for (final song in songs) {
      final artist = _primaryArtist(song.artist).toLowerCase();
      final count = artistCount[artist] ?? 0;
      if (count < maxPerArtist) {
        result.add(song);
        artistCount[artist] = count + 1;
      }
    }
    return result;
  }

  /// Limit albums to [maxPerArtist] per primary artist.
  List<Album> _enforceAlbumArtistDiversity(
      List<Album> albums, {int maxPerArtist = 2}) {
    final artistCount = <String, int>{};
    final result = <Album>[];

    for (final album in albums) {
      final artist = _primaryArtist(album.artist).toLowerCase();
      final count = artistCount[artist] ?? 0;
      if (count < maxPerArtist) {
        result.add(album);
        artistCount[artist] = count + 1;
      }
    }
    return result;
  }

  /// Tiered shuffle for albums: keeps quality ordering but shuffles within
  /// tiers of [tierSize] for organic variety.
  void _hourlyShuffleAlbumsTiered(List<Album> albums, {int tierSize = 6}) {
    final seed = DateTime.now().hour + DateTime.now().day * 31;
    final random = Random(seed);
    for (int i = 0; i < albums.length; i += tierSize) {
      final end = (i + tierSize).clamp(0, albums.length);
      final tier = albums.sublist(i, end);
      tier.shuffle(random);
      albums.replaceRange(i, end, tier);
    }
  }
}

/// Data class holding all home feed sections.
class HomeFeedData {
  final List<Song> trendingSongs;
  final List<Album> trendingAlbums;
  final List<Song> personalizedSongs;
  final List<Song> newReleases;
  final List<Song> moodSongs;
  final List<Album> newReleaseAlbums;
  final String moodLabel;
  final List<BecauseSection> becauseSections;
  final List<DailyMix> dailyMixes;
  final List<Song> rediscoverSongs;

  const HomeFeedData({
    required this.trendingSongs,
    required this.trendingAlbums,
    required this.personalizedSongs,
    required this.newReleases,
    required this.moodSongs,
    required this.newReleaseAlbums,
    required this.moodLabel,
    this.becauseSections = const [],
    this.dailyMixes = const [],
    this.rediscoverSongs = const [],
  });
}

/// A "Because you listened to X" section with seed song and recommendations.
class BecauseSection {
  final Song seedSong;
  final List<Song> recommendations;

  BecauseSection({
    required this.seedSong,
    required this.recommendations,
  });
}

/// A generated daily mix playlist.
class DailyMix {
  final String title;
  final String subtitle;
  final String icon;
  final List<Song> songs;
  final int accentColorHex;

  DailyMix({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.songs,
    this.accentColorHex = 0xFF6B8AFF,
  });
}

