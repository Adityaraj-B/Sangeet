import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants.dart';
import '../../models/song.dart';
import '../../services/recently_played.dart';
import '../../services/like_service.dart';

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
  List<_ArtistStats> _topArtists = [];
  List<_GenreStats> _topGenres = [];
  Map<int, int> _listeningByHour = {};
  Map<int, int> _listeningByDay = {};
  List<Song> _recentSongs = [];
  String _mostActiveDay = '';
  String _peakListeningTime = '';

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
    final recentWithTime = await _recentService.getRecentWithTimestamps(limit: 100);
    final recentSongs = await _recentService.getRecentlyPlayed(limit: 50);

    // Calculate stats
    final Map<String, int> artistPlayCount = {};
    final Map<String, String> artistImages = {};
    final Map<int, int> hourlyListening = {};
    final Map<int, int> dailyListening = {};
    int totalMinutes = 0;

    for (var item in recentWithTime) {
      final song = item['song'] as Song;
      final playedAt = item['playedAt'] as DateTime;

      // Artist stats
      artistPlayCount[song.artist] = (artistPlayCount[song.artist] ?? 0) + 1;
      artistImages[song.artist] = song.coverUrl;

      // Time stats
      totalMinutes += song.duration.inMinutes;

      // Hourly distribution
      hourlyListening[playedAt.hour] = (hourlyListening[playedAt.hour] ?? 0) + 1;

      // Daily distribution (1 = Monday, 7 = Sunday)
      dailyListening[playedAt.weekday] = (dailyListening[playedAt.weekday] ?? 0) + 1;
    }

    // Sort artists by play count
    final sortedArtists = artistPlayCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Generate genre stats (simulated based on variety)
    final genres = _generateGenreStats(recentSongs);

    // Find peak listening time
    int peakHour = 0;
    int peakCount = 0;
    hourlyListening.forEach((hour, count) {
      if (count > peakCount) {
        peakCount = count;
        peakHour = hour;
      }
    });

    // Find most active day
    int activeDay = 1;
    int activeDayCount = 0;
    dailyListening.forEach((day, count) {
      if (count > activeDayCount) {
        activeDayCount = count;
        activeDay = day;
      }
    });

    final dayNames = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    if (mounted) {
      setState(() {
        _totalListeningMinutes = totalMinutes;
        _totalSongsPlayed = recentWithTime.length;
        _likedSongsCount = _likeService.likedSongs.length;
        _topArtists = sortedArtists.take(5).map((e) => _ArtistStats(
          name: e.key,
          playCount: e.value,
          imageUrl: artistImages[e.key] ?? '',
        )).toList();
        _topGenres = genres;
        _listeningByHour = hourlyListening;
        _listeningByDay = dailyListening;
        _recentSongs = recentSongs;
        _mostActiveDay = dayNames[activeDay];
        _peakListeningTime = _formatHour(peakHour);
      });
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  List<_GenreStats> _generateGenreStats(List<Song> songs) {
    // Simulated genre distribution based on listening patterns
    final genres = [
      _GenreStats(name: 'Pop', percentage: 35, color: const Color(0xFFFF6B8A)),
      _GenreStats(name: 'Hip-Hop', percentage: 25, color: const Color(0xFF6B8AFF)),
      _GenreStats(name: 'R&B', percentage: 20, color: const Color(0xFF8AFF6B)),
      _GenreStats(name: 'Electronic', percentage: 12, color: const Color(0xFFFFB86B)),
      _GenreStats(name: 'Rock', percentage: 8, color: const Color(0xFFB86BFF)),
    ];
    return genres;
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
        background: _InsightsHeader(
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
            child: _StatCard(
              icon: Icons.access_time_rounded,
              value: _formatListeningTime(_totalListeningMinutes),
              label: 'Listening Time',
              color: kAccentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.music_note_rounded,
              value: '$_totalSongsPlayed',
              label: 'Songs Played',
              color: const Color(0xFF6B8AFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
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
      child: _GlassCard(
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
              child: _HourlyChart(data: _listeningByHour),
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
        child: _GlassCard(
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
          return _TopArtistCard(
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
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Genre bars
              ..._topGenres.map((genre) => _GenreBar(genre: genre)),
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
                child: _InsightCard(
                  icon: Icons.wb_sunny_rounded,
                  title: 'Peak Time',
                  value: _peakListeningTime.isNotEmpty ? _peakListeningTime : 'N/A',
                  subtitle: 'Most active hour',
                  gradient: const [Color(0xFFFFB86B), Color(0xFFFF8A6B)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InsightCard(
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
          _InsightCard(
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
    // Simplified streak calculation
    return min(7, _totalSongsPlayed ~/ 5 + 1);
  }

  Widget _buildWeeklyActivity() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxCount = _listeningByDay.values.fold(1, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final dayIndex = index + 1; // 1 = Monday
              final count = _listeningByDay[dayIndex] ?? 0;
              final intensity = maxCount > 0 ? count / maxCount : 0.0;

              return _WeekdayBar(
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

// Header Widget
class _InsightsHeader extends StatelessWidget {
  final int totalMinutes;
  final int totalSongs;
  final int likedSongs;
  final AnimationController pulseAnimation;

  const _InsightsHeader({
    required this.totalMinutes,
    required this.totalSongs,
    required this.likedSongs,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Animated gradient background
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      const Color(0xFF6B8AFF),
                      const Color(0xFF8A6BFF),
                      pulseAnimation.value,
                    )!.withValues(alpha: 0.8),
                    Color.lerp(
                      const Color(0xFFFF6B8A),
                      const Color(0xFFFFB86B),
                      pulseAnimation.value,
                    )!.withValues(alpha: 0.6),
                    kBackgroundColor,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            );
          },
        ),

        // Liquid glass orbs
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  top: -60 + (pulseAnimation.value * 20),
                  right: -40,
                  child: _GlassOrb(
                    size: 200,
                    color: const Color(0xFF6B8AFF).withValues(alpha: 0.3),
                  ),
                ),
                Positioned(
                  top: 100 - (pulseAnimation.value * 15),
                  left: -60,
                  child: _GlassOrb(
                    size: 150,
                    color: const Color(0xFFFF6B8A).withValues(alpha: 0.2),
                  ),
                ),
                Positioned(
                  bottom: 40 + (pulseAnimation.value * 10),
                  right: 40,
                  child: _GlassOrb(
                    size: 80,
                    color: kAccentColor.withValues(alpha: 0.25),
                  ),
                ),
              ],
            );
          },
        ),

        // Blur overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  kBackgroundColor.withValues(alpha: 0.5),
                  kBackgroundColor,
                ],
                stops: const [0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your Insights',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discover your listening habits',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Glass Orb Widget
class _GlassOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlassOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// Glass Card Widget
class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Top Artist Card
class _TopArtistCard extends StatelessWidget {
  final _ArtistStats artist;
  final int rank;

  const _TopArtistCard({
    required this.artist,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final rankColors = [
      kAccentColor,
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
      Colors.white.withValues(alpha: 0.5),
      Colors.white.withValues(alpha: 0.5),
    ];

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: rankColors[rank - 1],
                          width: 2,
                        ),
                        image: artist.imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(artist.imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: artist.imageUrl.isEmpty
                          ? Center(
                              child: Text(
                                artist.name[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: rankColors[rank - 1],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: kBackgroundColor,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: rank <= 3 ? kBackgroundColor : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  artist.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  '${artist.playCount} plays',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Genre Bar
class _GenreBar extends StatelessWidget {
  final _GenreStats genre;

  const _GenreBar({required this.genre});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                genre.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                '${genre.percentage}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: genre.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: genre.percentage / 100,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        genre.color,
                        genre.color.withValues(alpha: 0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: genre.color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Insight Card
class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final List<Color> gradient;
  final bool isWide;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.gradient,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(isWide ? 20 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                gradient[0].withValues(alpha: 0.2),
                gradient[1].withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: gradient[0].withValues(alpha: 0.3),
            ),
          ),
          child: isWide
              ? Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: gradient[0].withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: gradient[0], size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: gradient[0],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: gradient[0], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: gradient[0],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// Hourly Chart
class _HourlyChart extends StatelessWidget {
  final Map<int, int> data;

  const _HourlyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxCount = data.values.fold(1, (a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (hour) {
          final count = data[hour] ?? 0;
          final height = maxCount > 0 ? (count / maxCount) * 80 + 10 : 10.0;
          final isActive = count > 0;

          // Only show labels for key hours
          final showLabel = hour % 6 == 0;

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              kAccentColor.withValues(alpha: 0.3),
                              kAccentColor,
                            ],
                          )
                        : null,
                    color: isActive ? null : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formatChartHour(hour),
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ] else
                  const SizedBox(height: 20),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _formatChartHour(int hour) {
    if (hour == 0) return '12a';
    if (hour == 6) return '6a';
    if (hour == 12) return '12p';
    if (hour == 18) return '6p';
    return '';
  }
}

// Weekday Bar
class _WeekdayBar extends StatelessWidget {
  final String day;
  final double intensity;
  final int count;

  const _WeekdayBar({
    required this.day,
    required this.intensity,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count > 0 ? '$count' : '-',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 32,
              height: 60 * intensity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    kAccentColor.withValues(alpha: 0.4),
                    kAccentColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: intensity > 0
                    ? [
                        BoxShadow(
                          color: kAccentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: intensity > 0.5
                ? kAccentColor
                : Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

// Data Models
class _ArtistStats {
  final String name;
  final int playCount;
  final String imageUrl;

  _ArtistStats({
    required this.name,
    required this.playCount,
    required this.imageUrl,
  });
}

class _GenreStats {
  final String name;
  final int percentage;
  final Color color;

  _GenreStats({
    required this.name,
    required this.percentage,
    required this.color,
  });
}

