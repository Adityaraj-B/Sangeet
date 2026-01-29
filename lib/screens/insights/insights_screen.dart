import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants.dart';
import '../../models/song.dart';
import '../../services/recently_played.dart';
import '../../services/like_service.dart';
import 'components/components.dart';
import 'models/insights_models.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeIn;

  final RecentlyPlayedService _recentService = RecentlyPlayedService();
  final LikeService _likeService = LikeService();

  // Stats data
  int _totalListeningMinutes = 0;
  int _totalSongsPlayed = 0;
  int _likedSongsCount = 0;
  List<ArtistStats> _topArtists = [];
  List<GenreStats> _topGenres = [];
  Map<int, int> _listeningByHour = {};
  Map<int, int> _listeningByDay = {};
  String _mostActiveDay = '';
  String _peakListeningTime = '';
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _loadInsightsData();
    _controller.forward();
  }

  Future<void> _loadInsightsData() async {
    await _likeService.load();

    // RecentlyPlayedService stores unique songs with their latest playedAt.
    // For more "spot on" insights, we treat each entry as the latest play event
    // for that song and compute a strict last-7-days window.
    final recentWithTime =
        await _recentService.getRecentWithTimestamps(limit: 100);
    final recentSongs = await _recentService.getRecentlyPlayed(limit: 50);

    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: 7));

    // Filter to last 7 days (inclusive) and drop any malformed timestamps.
    final filtered = recentWithTime.where((item) {
      final playedAt = item['playedAt'];
      if (playedAt is! DateTime) return false;
      return !playedAt.isBefore(windowStart) && !playedAt.isAfter(now);
    }).toList();

    // Calculate stats (duration-weighted where applicable)
    final Map<String, int> artistPlayCount = {}; // play-events (unique songs here)
    final Map<String, String> artistImages = {};
    final Map<String, int> artistListeningSeconds = {};

    // Hour/day activity is based on listening *seconds* for better accuracy.
    final Map<int, int> hourlyListeningSeconds = {};
    final Map<int, int> dailyListeningSeconds = {};

    final Set<String> uniqueDates = {};
    final List<DateTime> playDates = [];

    int totalListeningSeconds = 0;

    // Keep a recency map for deterministic tie-breaking (newest wins).
    final Map<int, DateTime> hourMostRecent = {};
    final Map<int, DateTime> dayMostRecent = {};

    for (var item in filtered) {
      final song = item['song'] as Song;
      final playedAt = item['playedAt'] as DateTime;

      // Normalize duration: clamp to [0s, 60m] to avoid inflated stats
      // from bad metadata.
      final rawSeconds = song.duration.inSeconds;
      final clampedSeconds = rawSeconds.isFinite
          ? rawSeconds.clamp(0, 60 * 60)
          : 0;

      // Track unique dates for averages + streak.
      uniqueDates.add(_dateKey(playedAt));
      playDates.add(playedAt);

      // Artist aggregates.
      artistPlayCount[song.artist] = (artistPlayCount[song.artist] ?? 0) + 1;
      artistImages[song.artist] = song.coverUrl;
      artistListeningSeconds[song.artist] =
          (artistListeningSeconds[song.artist] ?? 0) + clampedSeconds;

      totalListeningSeconds += clampedSeconds;

      // Duration-weighted distributions.
      hourlyListeningSeconds[playedAt.hour] =
          (hourlyListeningSeconds[playedAt.hour] ?? 0) + clampedSeconds;
      dailyListeningSeconds[playedAt.weekday] =
          (dailyListeningSeconds[playedAt.weekday] ?? 0) + clampedSeconds;

      // Tie-breaker helpers (most recent).
      final existingHour = hourMostRecent[playedAt.hour];
      if (existingHour == null || playedAt.isAfter(existingHour)) {
        hourMostRecent[playedAt.hour] = playedAt;
      }
      final existingDay = dayMostRecent[playedAt.weekday];
      if (existingDay == null || playedAt.isAfter(existingDay)) {
        dayMostRecent[playedAt.weekday] = playedAt;
      }
    }

    // Sort artists by total listening time, then by play count, then by name.
    final sortedArtists = artistPlayCount.keys.toList()
      ..sort((a, b) {
        final secCompare =
            (artistListeningSeconds[b] ?? 0).compareTo(artistListeningSeconds[a] ?? 0);
        if (secCompare != 0) return secCompare;

        final countCompare =
            (artistPlayCount[b] ?? 0).compareTo(artistPlayCount[a] ?? 0);
        if (countCompare != 0) return countCompare;

        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    // Generate genre stats based on (filtered) songs and listening patterns.
    // Keep existing heuristic, but feed it the same window for consistency.
    final genres = _generateGenreStats(recentSongs, artistPlayCount);

    // Peak listening hour: max seconds, tiebreak by most recent play.
    final peakHour = _maxKeyBy(
      hourlyListeningSeconds,
      tieBreakerMostRecent: hourMostRecent,
    );

    // Most active day: max seconds, tiebreak by most recent play.
    final activeDay = _maxKeyBy(
      dailyListeningSeconds,
      tieBreakerMostRecent: dayMostRecent,
      defaultKey: 1,
    );

    // Calculate listening streak from normalized unique days in the window.
    final streak = _calculateListeningStreak(playDates);

    // Average per day is computed from the same 7-day window.
    final avgPerDay = uniqueDates.isNotEmpty ? filtered.length / uniqueDates.length : 0.0;
    (avgPerDay); // keep for potential future UI; intentionally unused now.

    final dayNames = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    if (mounted) {
      setState(() {
        // Use floor minutes to avoid inflating totals (more "spot on").
        _totalListeningMinutes = (totalListeningSeconds ~/ 60);

        // Note: due to de-duping in storage this represents unique songs
        // played in the last 7 days.
        _totalSongsPlayed = filtered.length;
        _likedSongsCount = _likeService.likedSongs.length;

        _topArtists = sortedArtists.take(5).map((name) {
          final seconds = artistListeningSeconds[name] ?? 0;
          return ArtistStats(
            name: name,
            playCount: artistPlayCount[name] ?? 0,
            imageUrl: artistImages[name] ?? '',
            totalMinutes: seconds ~/ 60,
          );
        }).toList();

        _topGenres = genres;

        // Convert seconds distributions back to an int scale for the existing chart.
        // We store minutes here to keep values smaller and more stable.
        _listeningByHour = hourlyListeningSeconds
            .map((k, v) => MapEntry(k, (v / 60).round()));
        _listeningByDay = dailyListeningSeconds
            .map((k, v) => MapEntry(k, (v / 60).round()));

        _mostActiveDay = dayNames[(activeDay ?? 1).clamp(1, 7)];
        _peakListeningTime = _formatHour(peakHour ?? 0);
        _currentStreak = streak;
      });
    }
  }

  String _dateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Returns the key with the maximum value. If tied, prefers the most recent
  /// timestamp in [tieBreakerMostRecent].
  int? _maxKeyBy(
    Map<int, int> values, {
    Map<int, DateTime>? tieBreakerMostRecent,
    int? defaultKey,
  }) {
    if (values.isEmpty) return defaultKey;

    int? bestKey;
    int bestValue = -1;
    DateTime bestRecent = DateTime.fromMillisecondsSinceEpoch(0);

    for (final entry in values.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value > bestValue) {
        bestKey = key;
        bestValue = value;
        bestRecent = tieBreakerMostRecent?[key] ?? bestRecent;
        continue;
      }

      if (value == bestValue && bestKey != null) {
        final candidateRecent = tieBreakerMostRecent?[key];
        final currentRecent = tieBreakerMostRecent?[bestKey];

        // Prefer the one with the more recent play within the window.
        if (candidateRecent != null &&
            (currentRecent == null || candidateRecent.isAfter(currentRecent))) {
          bestKey = key;
          bestRecent = candidateRecent;
        }
      }
    }

    return bestKey;
  }

  /// Calculate consecutive days listening streak
  int _calculateListeningStreak(List<DateTime> playDates) {
    if (playDates.isEmpty) return 0;

    // Use normalized dates (at midnight) to avoid timezone/clock-time issues.
    final normalized = playDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (normalized.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // If most recent play isn't today or yesterday, streak is broken.
    if (normalized.first != today && normalized.first != yesterday) {
      return 0;
    }

    int streak = 1;
    DateTime currentDate = normalized.first;

    for (int i = 1; i < normalized.length; i++) {
      final prevDate = normalized[i];
      final difference = currentDate.difference(prevDate).inDays;

      if (difference == 1) {
        streak++;
        currentDate = prevDate;
      } else if (difference > 1) {
        break;
      }
    }

    return streak;
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  List<GenreStats> _generateGenreStats(List<Song> songs, Map<String, int> artistPlayCount) {
    // Genre inference based on artist names and listening patterns
    // This provides a more realistic distribution based on actual data

    if (songs.isEmpty || artistPlayCount.isEmpty) {
      return [
        GenreStats(name: 'No Data', percentage: 100, color: Colors.grey),
      ];
    }

    // Common genre keywords that might appear in artist names or can be inferred
    final Map<String, int> genreCounts = {};
    final genreColors = {
      'Pop': const Color(0xFFFF6B8A),
      'Hip-Hop': const Color(0xFF6B8AFF),
      'R&B': const Color(0xFF8AFF6B),
      'Electronic': const Color(0xFFFFB86B),
      'Rock': const Color(0xFFB86BFF),
      'Indie': const Color(0xFF6BFFFF),
      'Classical': const Color(0xFFFF6BFF),
      'Jazz': const Color(0xFFFFFF6B),
      'Other': const Color(0xFF9E9E9E),
    };

    // Analyze each song/artist to infer genre
    int totalPlays = 0;
    for (var entry in artistPlayCount.entries) {
      final artist = entry.key.toLowerCase();
      final plays = entry.value;
      totalPlays += plays;

      // Simple genre inference based on patterns
      // In a real app, this would use actual genre metadata
      String inferredGenre = 'Other';

      // Check for common genre indicators in artist name
      if (artist.contains('dj') || artist.contains('electronic') ||
          artist.contains('edm') || artist.contains('remix')) {
        inferredGenre = 'Electronic';
      } else if (artist.contains('rap') || artist.contains('hip') ||
                 artist.contains('hop') || artist.contains('lil ')) {
        inferredGenre = 'Hip-Hop';
      } else if (artist.contains('rock') || artist.contains('metal') ||
                 artist.contains('punk')) {
        inferredGenre = 'Rock';
      } else if (artist.contains('jazz') || artist.contains('blues')) {
        inferredGenre = 'Jazz';
      } else if (artist.contains('classical') || artist.contains('orchestra') ||
                 artist.contains('symphony')) {
        inferredGenre = 'Classical';
      } else if (artist.contains('indie') || artist.contains('alternative')) {
        inferredGenre = 'Indie';
      } else if (artist.contains('r&b') || artist.contains('soul') ||
                 artist.contains('rnb')) {
        inferredGenre = 'R&B';
      } else {
        // Default distribution based on listening diversity
        // Spread across popular genres weighted by artist variety
        final artistCount = artistPlayCount.keys.length;
        if (artistCount > 5) {
          inferredGenre = 'Pop'; // Diverse listening often includes pop
        } else if (artistCount > 2) {
          inferredGenre = 'Pop';
        } else {
          inferredGenre = 'Other';
        }
      }

      genreCounts[inferredGenre] = (genreCounts[inferredGenre] ?? 0) + plays;
    }

    // Convert counts to percentages and sort
    final List<GenreStats> genres = [];
    for (var entry in genreCounts.entries) {
      final percentage = totalPlays > 0
          ? ((entry.value / totalPlays) * 100).round()
          : 0;
      if (percentage > 0) {
        genres.add(GenreStats(
          name: entry.key,
          percentage: percentage,
          color: genreColors[entry.key] ?? Colors.grey,
        ));
      }
    }

    // Sort by percentage descending
    genres.sort((a, b) => b.percentage.compareTo(a.percentage));

    // Ensure percentages sum to 100 (adjust largest if needed)
    if (genres.isNotEmpty) {
      final sum = genres.fold(0, (sum, g) => sum + g.percentage);
      if (sum != 100 && sum > 0) {
        final diff = 100 - sum;
        genres[0] = GenreStats(
          name: genres[0].name,
          percentage: genres[0].percentage + diff,
          color: genres[0].color,
        );
      }
    }

    // Return top 5 genres
    return genres.take(5).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildHeader(),
            SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: kBackgroundColor,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: InsightsHeader(
          totalMinutes: _totalListeningMinutes,
          totalSongs: _totalSongsPlayed,
          likedSongs: _likedSongsCount,
          pulseAnimation: _pulseController,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: kBackgroundColor.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildHandle(),
              const SizedBox(height: 28),

              // Quick Stats Row
              _buildQuickStats(),
              const SizedBox(height: 32),

              // Listening Activity Section
              _buildSectionLabel('Listening Activity'),
              const SizedBox(height: 16),
              _buildListeningChart(),
              const SizedBox(height: 32),

              // Top Artists Section
              _buildSectionLabel('Top Artists'),
              const SizedBox(height: 16),
              _buildTopArtists(),
              const SizedBox(height: 32),

              // Genre Distribution
              _buildSectionLabel('Your Music Taste'),
              const SizedBox(height: 16),
              _buildGenreDistribution(),
              const SizedBox(height: 32),

              // Listening Insights
              _buildSectionLabel('Insights'),
              const SizedBox(height: 16),
              _buildInsightCards(),
              const SizedBox(height: 32),

              // Weekly Activity
              _buildSectionLabel('Weekly Activity'),
              const SizedBox(height: 16),
              _buildWeeklyActivity(),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              icon: Icons.access_time_rounded,
              value: _formatListeningTime(_totalListeningMinutes),
              label: 'Listening Time',
              color: kAccentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.music_note_rounded,
              value: '$_totalSongsPlayed',
              label: 'Songs Played',
              color: const Color(0xFF6B8AFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.favorite_rounded,
              value: '$_likedSongsCount',
              label: 'Liked Songs',
              color: const Color(0xFFFF6B8A),
            ),
          ),
        ],
      ),
    );
  }

  String _formatListeningTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours < 24) return '${hours}h ${mins}m';
    final days = hours ~/ 24;
    return '${days}d ${hours % 24}h';
  }

  Widget _buildListeningChart() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daily Listening Pattern',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kAccentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Last 7 days',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kAccentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 120,
              child: HourlyChart(data: _listeningByHour),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTopArtists() {
    if (_topArtists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.person_outline_rounded, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text(
                    'Start listening to see your top artists',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _topArtists.length,
        itemBuilder: (context, index) {
          final artist = _topArtists[index];
          return TopArtistCard(
            artist: artist,
            rank: index + 1,
          );
        },
      ),
    );
  }

  Widget _buildGenreDistribution() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Genre bars
              ..._topGenres.map((genre) => GenreBar(genre: genre)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InsightCard(
                  icon: Icons.wb_sunny_rounded,
                  title: 'Peak Time',
                  value: _peakListeningTime.isNotEmpty ? _peakListeningTime : 'N/A',
                  subtitle: 'Most active hour',
                  gradient: const [Color(0xFFFFB86B), Color(0xFFFF8A6B)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InsightCard(
                  icon: Icons.calendar_today_rounded,
                  title: 'Best Day',
                  value: _mostActiveDay.isNotEmpty ? _mostActiveDay : 'N/A',
                  subtitle: 'Most listening',
                  gradient: const [Color(0xFF6B8AFF), Color(0xFF8A6BFF)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InsightCard(
            icon: Icons.auto_graph_rounded,
            title: 'Listening Streak',
            value: '${_calculateStreak()} days',
            subtitle: 'Keep it going! 🔥',
            gradient: const [Color(0xFFFF6B8A), Color(0xFFFF8A6B)],
            isWide: true,
          ),
        ],
      ),
    );
  }

  int _calculateStreak() {
    // Return the accurately calculated streak from _loadInsightsData
    return _currentStreak;
  }

  Widget _buildWeeklyActivity() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxCount = _listeningByDay.values.fold(1, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final dayIndex = index + 1; // 1 = Monday
              final count = _listeningByDay[dayIndex] ?? 0;
              final intensity = maxCount > 0 ? count / maxCount : 0.0;

              return WeekdayBar(
                day: days[index],
                intensity: intensity,
                count: count,
              );
            }),
          ),
        ),
      ),
    );
  }
}

