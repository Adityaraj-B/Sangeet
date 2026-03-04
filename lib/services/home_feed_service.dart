import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../models/album.dart';
import 'remote_music_service.dart';
import 'recently_played.dart';
import 'like_service.dart';

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
  }

  // ─────────────────────────────────────────────────────────────────
  //  QUERY POOLS — curated for real Bollywood / Indie / International
  // ─────────────────────────────────────────────────────────────────

  /// Named popular artists that yield high-quality trending results
  static const List<String> _popularArtistQueries = [
    // Bollywood / Hindi
    'Arijit Singh',
    'Shreya Ghoshal',
    'Atif Aslam',
    'Neha Kakkar',
    'Jubin Nautiyal',
    'Pritam',
    'A.R. Rahman',
    'Vishal Mishra',
    'Sachet Tandon',
    'B Praak',
    'Darshan Raval',
    'Armaan Malik',
    'Badshah songs',
    'Yo Yo Honey Singh',
    'Anuv Jain',
    'Talwiinder',
    // Punjabi
    'AP Dhillon',
    'Diljit Dosanjh',
    'Sidhu Moose Wala',
    'Karan Aujla',
    'Shubh',
    // International
    'The Weeknd',
    'Drake',
    'Dua Lipa',
    'Taylor Swift',
    'Ed Sheeran',
    'Post Malone',
    'Bruno Mars',
    'Billie Eilish',
    'Travis Scott',
    'Coldplay',
  ];

  /// Genre / mood based queries
  static const List<String> _genreQueries = [
    'bollywood hits 2026',
    'bollywood hits 2025',
    'top hindi songs 2026',
    'viral hindi songs',
    'hindi romantic songs',
    'bollywood party songs',
    'hindi sad songs',
    'hindi lofi songs',
    'punjabi hits 2026',
    'punjabi party songs',
    'top english pop songs',
    'english hits 2026',
    'indie hindi songs',
    'chill hindi vibes',
    'hindi unplugged',
    'bollywood dance songs',
    'hindi workout songs',
    'hindi road trip songs',
  ];

  /// Album-specific queries
  static const List<String> _trendingAlbumQueries = [
    'latest bollywood albums 2026',
    'new hindi albums 2026',
    'trending hindi albums',
    'top bollywood albums',
    'new bollywood albums',
    'Arijit Singh album',
    'A.R. Rahman album',
    'Pritam album',
    'AP Dhillon album',
    'Diljit Dosanjh album',
    'popular hindi albums',
    'latest punjabi albums',
    'bollywood soundtrack',
    'best bollywood albums',
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
        moodLabel: _moodLabel,
      );
    }

    // Fire all fetches in parallel
    final results = await Future.wait([
      _fetchSmartTrendingSongs(),       // 0
      _fetchSmartTrendingAlbums(),      // 1
      _fetchPersonalizedSongs(),        // 2
      _fetchNewReleases(),              // 3
      _fetchMoodBasedSongs(),           // 4
      _fetchNewReleaseAlbums(),         // 5
    ]);

    _cachedTrendingSongs = results[0] as List<Song>;
    _cachedTrendingAlbums = results[1] as List<Album>;
    _cachedPersonalizedSongs = results[2] as List<Song>;
    _cachedNewReleases = results[3] as List<Song>;
    _cachedMoodSongs = results[4] as List<Song>;
    _cachedNewReleaseAlbums = results[5] as List<Album>;
    _cacheTimestamp = DateTime.now();

    // Cross-section deduplication
    final trendingIds = _cachedTrendingSongs!.map((s) => s.id).toSet();
    _cachedPersonalizedSongs!.removeWhere((s) => trendingIds.contains(s.id));
    _cachedNewReleases!.removeWhere((s) => trendingIds.contains(s.id));
    _cachedMoodSongs!.removeWhere((s) => trendingIds.contains(s.id));

    final personalizedIds = _cachedPersonalizedSongs!.map((s) => s.id).toSet();
    _cachedMoodSongs!.removeWhere((s) => personalizedIds.contains(s.id));
    _cachedNewReleases!.removeWhere((s) => personalizedIds.contains(s.id));

    return HomeFeedData(
      trendingSongs: _cachedTrendingSongs!,
      trendingAlbums: _cachedTrendingAlbums!,
      personalizedSongs: _cachedPersonalizedSongs!,
      newReleases: _cachedNewReleases!,
      moodSongs: _cachedMoodSongs!,
      newReleaseAlbums: _cachedNewReleaseAlbums!,
      moodLabel: _moodLabel,
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

  /// Smart trending: mix of popular artist songs + genre hits,
  /// sorted by real playCount from API, with artist diversity.
  Future<List<Song>> _fetchSmartTrendingSongs() async {
    try {
      // Pick 3 popular artist queries + 3 genre queries = 6 parallel requests
      final artistQueries = _pickRandom(_popularArtistQueries, 3);
      final genreQs = _pickRandom(_genreQueries, 3);
      final allQueries = [...artistQueries, ...genreQs];

      final results = await Future.wait(
        allQueries.map((q) => _musicService.searchSongs(q)),
      );

      // Merge and deduplicate
      final seenIds = <String>{};
      final allSongs = <Song>[];
      for (final batch in results) {
        for (final song in batch) {
          if (song.id.isNotEmpty && seenIds.add(song.id)) {
            allSongs.add(song);
          }
        }
      }

      // Sort by playCount descending (real popularity)
      _sortByPopularity(allSongs);

      // Enforce artist diversity: max 3 songs per primary artist
      final diverseSongs = _enforceArtistDiversity(allSongs, maxPerArtist: 3);

      // Take top 40, then apply a gentle shuffle within popularity tiers
      // so it's not a rigid list but still popularity-weighted
      final top = diverseSongs.take(40).toList();
      _tieredShuffle(top);

      return top.take(30).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching smart trending songs: $e');
      return _musicService.getTrending();
    }
  }

  /// Smart trending albums with artist diversity.
  Future<List<Album>> _fetchSmartTrendingAlbums() async {
    try {
      final queries = _pickRandom(_trendingAlbumQueries, 4);

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

      final diverseAlbums = _enforceAlbumArtistDiversity(allAlbums, maxPerArtist: 2);
      _hourlyShuffleAlbums(diverseAlbums);

      return diverseAlbums.take(20).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching smart trending albums: $e');
      return _musicService.getTrendingAlbums();
    }
  }

  /// Personalized songs based on:
  ///  1. Top artists from recently played songs
  ///  2. Top artists from liked songs
  ///  3. Song suggestions API for multiple recent songs
  Future<List<Song>> _fetchPersonalizedSongs() async {
    try {
      final recentSongs = await _recentService.getRecentlyPlayed(limit: 20);
      final likedSongs = likeService?.likedSongs ?? [];

      // Collect all user songs for artist extraction
      final allUserSongs = <Song>[...recentSongs, ...likedSongs];
      if (allUserSongs.isEmpty) return [];

      // Extract artists with frequency weighting
      final artistFreq = <String, int>{};
      for (final song in allUserSongs) {
        final primary = _primaryArtist(song.artist);
        if (primary.isNotEmpty && primary.toLowerCase() != 'unknown') {
          artistFreq[primary] = (artistFreq[primary] ?? 0) + 1;
        }
      }

      if (artistFreq.isEmpty) return [];

      // Sort artists by frequency (most listened first)
      final sortedArtists = artistFreq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topArtists = sortedArtists.take(4).map((e) => e.key).toList();

      // Build parallel futures
      final futures = <Future<List<Song>>>[];

      // Search for each top artist
      for (final artist in topArtists) {
        futures.add(_musicService.searchSongs(artist));
      }

      // Get song suggestions for up to 3 recent songs
      final recentWithIds = recentSongs.where((s) => s.id.isNotEmpty).take(3);
      for (final song in recentWithIds) {
        futures.add(_musicService.getSongSuggestions(song.id));
      }

      final results = await Future.wait(futures);

      // Merge, deduplicate, exclude already-played songs
      final excludeIds = allUserSongs.map((s) => s.id).toSet();
      final seenIds = <String>{};
      final allSongs = <Song>[];

      for (final batch in results) {
        for (final song in batch) {
          if (song.id.isNotEmpty &&
              !excludeIds.contains(song.id) &&
              seenIds.add(song.id)) {
            allSongs.add(song);
          }
        }
      }

      // Sort by popularity, then enforce diversity
      _sortByPopularity(allSongs);
      final diverseSongs = _enforceArtistDiversity(allSongs, maxPerArtist: 3);
      _tieredShuffle(diverseSongs);

      return diverseSongs.take(20).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching personalized songs: $e');
      return [];
    }
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

  /// Mood-based songs according to time of day.
  Future<List<Song>> _fetchMoodBasedSongs() async {
    try {
      final mood = _currentMood;
      final moodPool = _moodQueries[mood] ?? _moodQueries['afternoon']!;
      final queries = _pickRandom(moodPool, 3);

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

      _sortByPopularity(allSongs);
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
      _hourlyShuffleAlbums(diverseAlbums);

      return diverseAlbums.take(15).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching new release albums: $e');
      return [];
    }
  }

  // ── Helpers ────────────────────────────────────────────────────

  /// Pick [count] random items from a list, seeded by
  /// current hour + day so results rotate hourly but stay stable within an hour.
  List<String> _pickRandom(List<String> pool, int count) {
    final seed = DateTime.now().hour + DateTime.now().day * 100 +
        DateTime.now().month * 10000;
    final random = Random(seed);
    final shuffled = List<String>.from(pool)..shuffle(random);
    return shuffled.take(count.clamp(1, pool.length)).toList();
  }

  /// Extract the primary (first) artist name from a comma / & separated string.
  String _primaryArtist(String artistField) {
    final parts = artistField.split(RegExp(r'[,&]'));
    return parts.first.trim();
  }

  /// Sort songs by playCount descending with freshness boost.
  /// Songs from 2025–2026 get a 1.5x multiplier on their play count
  /// so they surface higher even with fewer absolute plays.
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
      freshness = 2.0;
    } else if (y >= 2025) {
      freshness = 1.5;
    } else if (y >= 2024) {
      freshness = 1.2;
    }

    return baseCount * freshness;
  }

  /// Tiered shuffle: divide into tiers of 10 and shuffle within each tier.
  /// This keeps the overall popularity ordering but adds variety within
  /// each "tier" so it doesn't feel like a rigid leaderboard.
  void _tieredShuffle(List<Song> songs) {
    final seed = DateTime.now().hour + DateTime.now().day * 31;
    final random = Random(seed);
    const tierSize = 10;
    for (int i = 0; i < songs.length; i += tierSize) {
      final end = (i + tierSize).clamp(0, songs.length);
      final tier = songs.sublist(i, end);
      tier.shuffle(random);
      songs.replaceRange(i, end, tier);
    }
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

  void _hourlyShuffleAlbums(List<Album> albums) {
    albums.shuffle(
        Random(DateTime.now().hour + DateTime.now().day * 31));
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

  const HomeFeedData({
    required this.trendingSongs,
    required this.trendingAlbums,
    required this.personalizedSongs,
    required this.newReleases,
    required this.moodSongs,
    required this.newReleaseAlbums,
    required this.moodLabel,
  });
}
