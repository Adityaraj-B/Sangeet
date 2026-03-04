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
  String _topGenreName = '';
  String _avgSongLength = '';
  int _uniqueArtistCount = 0;
  String _listeningMood = '';

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

    // Generate genre stats based on the filtered window songs for accuracy.
    final filteredSongs = filtered.map((item) => item['song'] as Song).toList();
    final genres = _generateGenreStats(filteredSongs, artistPlayCount);

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
      // Compute extra insight values outside setState for clarity
      final topGenre = genres.isNotEmpty ? genres.first.name : '';
      final uniqueArtists = artistPlayCount.keys.length;
      final avgSeconds = filtered.isNotEmpty
          ? (totalListeningSeconds / filtered.length).round()
          : 0;
      final avgMin = avgSeconds ~/ 60;
      final avgSec = avgSeconds % 60;
      final avgLenStr = '${avgMin}m ${avgSec}s';

      // Derive a listening mood from the peak hour
      final mood = _deriveMood(peakHour ?? 12, topGenre);

      setState(() {
        _totalListeningMinutes = (totalListeningSeconds ~/ 60);
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

        _listeningByHour = hourlyListeningSeconds
            .map((k, v) => MapEntry(k, (v / 60).round()));
        _listeningByDay = dailyListeningSeconds
            .map((k, v) => MapEntry(k, (v / 60).round()));

        _mostActiveDay = dayNames[(activeDay ?? 1).clamp(1, 7)];
        _peakListeningTime = _formatHour(peakHour ?? 0);
        _currentStreak = streak;

        _topGenreName = topGenre;
        _avgSongLength = avgLenStr;
        _uniqueArtistCount = uniqueArtists;
        _listeningMood = mood;
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

  /// Derive a human-readable listening mood from peak hour + top genre.
  String _deriveMood(int peakHour, String topGenre) {
    // Time-based mood
    String timeMood;
    if (peakHour >= 5 && peakHour < 9) {
      timeMood = 'Early Bird 🌅';
    } else if (peakHour >= 9 && peakHour < 12) {
      timeMood = 'Morning Vibes ☀️';
    } else if (peakHour >= 12 && peakHour < 15) {
      timeMood = 'Afternoon Flow 🎶';
    } else if (peakHour >= 15 && peakHour < 18) {
      timeMood = 'Evening Chill 🌤️';
    } else if (peakHour >= 18 && peakHour < 21) {
      timeMood = 'Night Owl 🌙';
    } else if (peakHour >= 21 || peakHour < 1) {
      timeMood = 'Late Night 🌃';
    } else {
      timeMood = 'After Hours 🌌';
    }

    // Genre can refine the mood
    final gl = topGenre.toLowerCase();
    if (gl == 'romantic' || gl == 'lofi') return 'Soulful $timeMood';
    if (gl == 'hip-hop') return 'High Energy 🔥';
    if (gl == 'electronic') return 'Party Mode 🎧';
    if (gl == 'classical') return 'Peaceful $timeMood';
    if (gl == 'rock') return 'Headbanger 🤘';
    if (gl == 'indie') return 'Chill Explorer 🎸';

    return timeMood;
  }

  // ── Comprehensive artist → genre mapping ──────────────────────────
  // Covers Bollywood, Indie, Punjabi, Hip-Hop/Rap, International Pop,
  // R&B, Rock, Electronic, Classical, Lofi, and more.
  static const Map<String, List<String>> _artistGenreMap = {
    // ── Bollywood / Romantic ──
    'arijit singh':        ['Romantic', 'Bollywood'],
    'shreya ghoshal':      ['Bollywood', 'Romantic'],
    'atif aslam':          ['Romantic', 'Bollywood'],
    'neha kakkar':         ['Bollywood', 'Pop'],
    'jubin nautiyal':      ['Romantic', 'Bollywood'],
    'vishal mishra':       ['Romantic', 'Bollywood'],
    'sachet tandon':       ['Romantic', 'Bollywood'],
    'b praak':             ['Romantic', 'Punjabi'],
    'darshan raval':       ['Romantic', 'Indie'],
    'armaan malik':        ['Romantic', 'Pop'],
    'pritam':              ['Bollywood'],
    'a.r. rahman':         ['Bollywood', 'Classical'],
    'sonu nigam':          ['Bollywood', 'Romantic'],
    'kumar sanu':          ['Bollywood', 'Romantic'],
    'udit narayan':        ['Bollywood', 'Romantic'],
    'alka yagnik':         ['Bollywood', 'Romantic'],
    'lata mangeshkar':     ['Bollywood', 'Classical'],
    'kishore kumar':       ['Bollywood', 'Romantic'],
    'mohd rafi':           ['Bollywood', 'Classical'],
    'mohammed rafi':       ['Bollywood', 'Classical'],
    'mukesh':              ['Bollywood', 'Classical'],
    'shankar mahadevan':   ['Bollywood'],
    'shankar-ehsaan-loy':  ['Bollywood'],
    'vishal-shekhar':      ['Bollywood', 'Pop'],
    'salim-sulaiman':      ['Bollywood'],
    'amit trivedi':        ['Bollywood', 'Indie'],
    'mithoon':             ['Romantic', 'Bollywood'],
    'himesh reshammiya':   ['Bollywood', 'Pop'],
    'ankit tiwari':        ['Romantic', 'Bollywood'],
    'palak muchhal':       ['Romantic', 'Bollywood'],
    'tulsi kumar':         ['Romantic', 'Bollywood'],
    'stebin ben':          ['Romantic', 'Bollywood'],
    'papon':               ['Indie', 'Romantic'],
    'mohit chauhan':       ['Bollywood', 'Romantic'],
    'kk':                  ['Bollywood', 'Romantic'],
    'rahat fateh ali khan': ['Romantic', 'Bollywood'],
    'sunidhi chauhan':     ['Bollywood', 'Pop'],
    'monali thakur':       ['Bollywood', 'Romantic'],
    'ash king':            ['Bollywood', 'Pop'],
    'shaan':               ['Bollywood', 'Romantic'],
    'mika singh':          ['Bollywood', 'Punjabi'],
    'guru randhawa':       ['Punjabi', 'Pop'],
    'harrdy sandhu':       ['Punjabi', 'Pop'],
    'jasleen royal':       ['Indie', 'Bollywood'],
    'sachin-jigar':        ['Bollywood', 'Pop'],
    'tanishk bagchi':      ['Bollywood', 'Pop'],
    'irshad kamil':        ['Bollywood'],
    'amaal mallik':        ['Bollywood', 'Romantic'],
    'javed ali':           ['Bollywood', 'Romantic'],
    'sukhwinder singh':    ['Bollywood'],
    'benny dayal':         ['Bollywood', 'Pop'],
    'jonita gandhi':       ['Bollywood', 'Pop'],
    'asees kaur':          ['Romantic', 'Bollywood'],
    'dev negi':            ['Bollywood', 'Pop'],
    'nikhita gandhi':      ['Bollywood', 'Pop'],

    // ── Indie / Lofi / Chill ──
    'anuv jain':           ['Indie', 'Romantic'],
    'prateek kuhad':       ['Indie', 'Romantic'],
    'when chai met toast': ['Indie'],
    'the local train':     ['Indie', 'Rock'],
    'ritviz':              ['Electronic', 'Indie'],
    'zaeden':              ['Indie', 'Pop'],
    'ankur tewari':        ['Indie'],
    'lucky ali':           ['Indie', 'Romantic'],
    'euphoria':            ['Indie', 'Rock'],
    'indian ocean':        ['Indie', 'Rock'],
    'parvaaz':             ['Indie', 'Rock'],
    'taba chake':          ['Indie', 'Romantic'],
    'osho jain':           ['Indie', 'Lofi'],
    'hanita bhambri':      ['Indie', 'Romantic'],
    'lifafa':              ['Indie', 'Electronic'],
    'seedhe maut':         ['Hip-Hop', 'Indie'],
    'seedhe maut ki duniya': ['Hip-Hop', 'Indie'],
    'talwiinder':          ['R&B', 'Indie'],

    // ── Punjabi ──
    'ap dhillon':          ['Punjabi', 'Hip-Hop'],
    'diljit dosanjh':      ['Punjabi', 'Bollywood'],
    'sidhu moose wala':    ['Punjabi', 'Hip-Hop'],
    'karan aujla':         ['Punjabi', 'Hip-Hop'],
    'shubh':               ['Punjabi', 'Hip-Hop'],
    'jassie gill':         ['Punjabi', 'Romantic'],
    'amrinder gill':       ['Punjabi', 'Romantic'],
    'garry sandhu':        ['Punjabi', 'Pop'],
    'ammy virk':           ['Punjabi', 'Romantic'],
    'babbu maan':          ['Punjabi'],
    'gurdas maan':         ['Punjabi', 'Classical'],
    'jazzy b':             ['Punjabi', 'Hip-Hop'],
    'bohemia':             ['Punjabi', 'Hip-Hop'],
    'parmish verma':       ['Punjabi', 'Hip-Hop'],
    'mankirt aulakh':      ['Punjabi'],
    'singga':              ['Punjabi', 'Hip-Hop'],
    'nimrat khaira':       ['Punjabi', 'Romantic'],
    'sharry maan':         ['Punjabi', 'Romantic'],
    'r nait':              ['Punjabi', 'Hip-Hop'],
    'jordan sandhu':       ['Punjabi'],
    'deep kalsi':          ['Punjabi', 'Hip-Hop'],

    // ── Hip-Hop / Rap (Indian) ──
    'badshah':             ['Hip-Hop', 'Bollywood'],
    'yo yo honey singh':   ['Hip-Hop', 'Punjabi'],
    'honey singh':         ['Hip-Hop', 'Punjabi'],
    'raftaar':             ['Hip-Hop'],
    'divine':              ['Hip-Hop'],
    'emiway bantai':       ['Hip-Hop'],
    'emiway':              ['Hip-Hop'],
    'ikka':                ['Hip-Hop'],
    'kr\$na':               ['Hip-Hop'],
    'krsna':               ['Hip-Hop'],
    'mc stan':             ['Hip-Hop'],
    'king':                ['Hip-Hop', 'Pop'],
    'dino james':          ['Hip-Hop'],
    'fotty seven':         ['Hip-Hop'],
    'muhfaad':             ['Hip-Hop'],
    'brodha v':            ['Hip-Hop'],
    'naezy':               ['Hip-Hop'],
    'prabh deep':          ['Hip-Hop', 'Indie'],
    'slowcheeta':          ['Hip-Hop', 'Indie'],
    'karma':               ['Hip-Hop'],
    'bella':               ['Hip-Hop'],
    'young stunners':      ['Hip-Hop'],
    'talha anjum':         ['Hip-Hop'],
    'talha yunus':         ['Hip-Hop'],

    // ── International Pop ──
    'taylor swift':        ['Pop'],
    'ed sheeran':          ['Pop', 'Romantic'],
    'dua lipa':            ['Pop', 'Electronic'],
    'bruno mars':          ['Pop', 'R&B'],
    'billie eilish':       ['Pop', 'Indie'],
    'ariana grande':       ['Pop', 'R&B'],
    'justin bieber':       ['Pop'],
    'shawn mendes':        ['Pop', 'Romantic'],
    'selena gomez':        ['Pop'],
    'harry styles':        ['Pop', 'Rock'],
    'olivia rodrigo':      ['Pop', 'Rock'],
    'charlie puth':        ['Pop', 'R&B'],
    'sia':                 ['Pop'],
    'adele':               ['Pop', 'Romantic'],
    'sam smith':           ['Pop', 'R&B'],
    'lewis capaldi':       ['Pop', 'Romantic'],
    'lana del rey':        ['Pop', 'Indie'],
    'halsey':              ['Pop', 'Indie'],
    'camila cabello':      ['Pop', 'Romantic'],
    'bts':                 ['K-Pop', 'Pop'],
    'blackpink':           ['K-Pop', 'Pop'],
    'lady gaga':           ['Pop', 'Electronic'],
    'rihanna':             ['Pop', 'R&B'],
    'katy perry':          ['Pop'],
    'shakira':             ['Pop'],
    'doja cat':            ['Pop', 'Hip-Hop'],
    'lizzo':               ['Pop', 'R&B'],
    'miley cyrus':         ['Pop', 'Rock'],
    'sabrina carpenter':   ['Pop'],
    'tate mcrae':          ['Pop'],
    'chappell roan':       ['Pop', 'Indie'],

    // ── International Hip-Hop / Rap ──
    'drake':               ['Hip-Hop', 'R&B'],
    'the weeknd':          ['R&B', 'Pop'],
    'travis scott':        ['Hip-Hop'],
    'post malone':         ['Hip-Hop', 'Pop'],
    'kanye west':          ['Hip-Hop'],
    'ye':                  ['Hip-Hop'],
    'eminem':              ['Hip-Hop'],
    'kendrick lamar':      ['Hip-Hop'],
    'j. cole':             ['Hip-Hop'],
    'lil uzi vert':        ['Hip-Hop'],
    'lil baby':            ['Hip-Hop'],
    'lil nas x':           ['Hip-Hop', 'Pop'],
    'jack harlow':         ['Hip-Hop'],
    '21 savage':           ['Hip-Hop'],
    'metro boomin':        ['Hip-Hop'],
    'future':              ['Hip-Hop'],
    'megan thee stallion':['Hip-Hop'],
    'nicki minaj':         ['Hip-Hop', 'Pop'],
    'cardi b':             ['Hip-Hop'],
    'tyler, the creator':  ['Hip-Hop', 'Indie'],
    'a\$ap rocky':          ['Hip-Hop'],
    'juice wrld':          ['Hip-Hop', 'Pop'],
    'xxxtentacion':        ['Hip-Hop'],
    'kid cudi':            ['Hip-Hop', 'Indie'],
    'mac miller':          ['Hip-Hop', 'Indie'],
    'sza':                 ['R&B'],

    // ── R&B / Soul ──
    'daniel caesar':       ['R&B', 'Romantic'],
    'frank ocean':         ['R&B', 'Indie'],
    'khalid':              ['R&B', 'Pop'],
    'h.e.r.':              ['R&B'],
    'jorja smith':         ['R&B'],
    'summer walker':       ['R&B'],
    'brent faiyaz':        ['R&B'],
    'giveon':              ['R&B', 'Romantic'],

    // ── Rock / Alternative ──
    'coldplay':            ['Rock', 'Pop'],
    'imagine dragons':     ['Rock', 'Pop'],
    'one republic':        ['Rock', 'Pop'],
    'onerepublic':         ['Rock', 'Pop'],
    'maroon 5':            ['Pop', 'Rock'],
    'linkin park':         ['Rock'],
    'arctic monkeys':      ['Rock', 'Indie'],
    'the neighbourhood':   ['Indie', 'Rock'],
    'hozier':              ['Indie', 'Rock'],
    'twenty one pilots':   ['Rock', 'Pop'],
    'fall out boy':        ['Rock'],
    'green day':           ['Rock'],
    'foo fighters':        ['Rock'],
    'radiohead':           ['Rock', 'Indie'],
    'tame impala':         ['Indie', 'Rock'],
    'the 1975':            ['Indie', 'Pop'],
    'glass animals':       ['Indie', 'Electronic'],
    'bon iver':            ['Indie'],

    // ── Electronic / EDM ──
    'martin garrix':       ['Electronic'],
    'marshmello':          ['Electronic', 'Pop'],
    'alan walker':         ['Electronic'],
    'avicii':              ['Electronic'],
    'kygo':                ['Electronic', 'Pop'],
    'david guetta':        ['Electronic'],
    'calvin harris':       ['Electronic', 'Pop'],
    'tiësto':              ['Electronic'],
    'deadmau5':            ['Electronic'],
    'skrillex':            ['Electronic'],
    'zedd':                ['Electronic', 'Pop'],
    'chainsmokers':        ['Electronic', 'Pop'],
    'the chainsmokers':    ['Electronic', 'Pop'],
    'nucleya':             ['Electronic'],
    'lost stories':        ['Electronic'],

    // ── Classical / Devotional ──
    'pandit ravi shankar': ['Classical'],
    'zakir hussain':       ['Classical'],
    'ustad bismillah khan':['Classical'],
    'hariprasad chaurasia':['Classical'],
    'jagjit singh':        ['Classical', 'Romantic'],
    'ghulam ali':          ['Classical'],
    'nusrat fateh ali khan':['Classical', 'Romantic'],
  };

  // ── Song title keywords → genre hints ─────────────────────────────
  static const Map<String, String> _titleGenreKeywords = {
    'love':       'Romantic',
    'pyaar':      'Romantic',
    'ishq':       'Romantic',
    'dil':        'Romantic',
    'tere':       'Romantic',
    'tera':       'Romantic',
    'tum':        'Romantic',
    'sanam':      'Romantic',
    'romantic':   'Romantic',
    'mehboob':    'Romantic',
    'sajan':      'Romantic',
    'party':      'Pop',
    'dance':      'Pop',
    'nachle':     'Bollywood',
    'naach':      'Bollywood',
    'rap':        'Hip-Hop',
    'hustle':     'Hip-Hop',
    'diss':       'Hip-Hop',
    'drill':      'Hip-Hop',
    'lofi':       'Lofi',
    'lo-fi':      'Lofi',
    'chill':      'Lofi',
    'unplugged':  'Indie',
    'acoustic':   'Indie',
    'bhajan':     'Classical',
    'devotional': 'Classical',
    'qawwali':    'Classical',
    'ghazal':     'Classical',
    'sufi':       'Classical',
    'remix':      'Electronic',
    'edm':        'Electronic',
    'bass':       'Electronic',
    'sad':        'Romantic',
    'breakup':    'Romantic',
    'heartbreak': 'Romantic',
    'mashup':     'Bollywood',
    'punjabi':    'Punjabi',
    'jatt':       'Punjabi',
    'gabru':      'Punjabi',
    'bhangra':    'Punjabi',
  };

  List<GenreStats> _generateGenreStats(List<Song> songs, Map<String, int> artistPlayCount) {
    if (songs.isEmpty && artistPlayCount.isEmpty) {
      return [
        GenreStats(name: 'No Data', percentage: 100, color: Colors.grey),
      ];
    }

    final genreColors = {
      'Bollywood':  const Color(0xFFFF6B8A),
      'Romantic':   const Color(0xFFFF8AAE),
      'Pop':        const Color(0xFFFF9E6B),
      'Hip-Hop':    const Color(0xFF6B8AFF),
      'Punjabi':    const Color(0xFFFFB86B),
      'Indie':      const Color(0xFF6BFFCF),
      'R&B':        const Color(0xFF8AFF6B),
      'Electronic': const Color(0xFFB86BFF),
      'Rock':       const Color(0xFFFF6BFF),
      'Lofi':       const Color(0xFF6BDFFF),
      'Classical':  const Color(0xFFFFFF6B),
      'K-Pop':      const Color(0xFFFF6BD5),
      'Other':      const Color(0xFF9E9E9E),
    };

    // Weight genre by listening seconds (from artist play counts * avg duration)
    // and also use per-song analysis for more granularity.
    final Map<String, double> genreWeights = {};

    // Build a quick song lookup by artist for title/language analysis
    final Map<String, List<Song>> songsByArtist = {};
    for (final song in songs) {
      songsByArtist.putIfAbsent(song.artist, () => []).add(song);
    }

    for (final entry in artistPlayCount.entries) {
      final artistName = entry.key;
      final plays = entry.value;
      final artistLower = artistName.toLowerCase().trim();

      // 1) Try known artist mapping (check full name and each sub-artist)
      List<String>? knownGenres = _artistGenreMap[artistLower];

      // Handle "Artist1, Artist2" format — try each part
      if (knownGenres == null && artistLower.contains(',')) {
        final parts = artistLower.split(',').map((s) => s.trim());
        for (final part in parts) {
          knownGenres = _artistGenreMap[part];
          if (knownGenres != null) break;
        }
      }

      // Also try partial match for names like "Arijit Singh, Shreya Ghoshal"
      if (knownGenres == null) {
        for (final mapEntry in _artistGenreMap.entries) {
          if (artistLower.contains(mapEntry.key) ||
              mapEntry.key.contains(artistLower)) {
            knownGenres = mapEntry.value;
            break;
          }
        }
      }

      if (knownGenres != null && knownGenres.isNotEmpty) {
        // Distribute weight: primary genre gets 60%, secondary gets 40%
        final primary = knownGenres[0];
        genreWeights[primary] =
            (genreWeights[primary] ?? 0) + plays * 0.6;
        if (knownGenres.length > 1) {
          final secondary = knownGenres[1];
          genreWeights[secondary] =
              (genreWeights[secondary] ?? 0) + plays * 0.4;
        } else {
          genreWeights[primary] =
              (genreWeights[primary] ?? 0) + plays * 0.4;
        }
      } else {
        // 2) Fallback: analyse song titles + language for this artist
        final artistSongs = songsByArtist[artistName] ?? [];
        String fallbackGenre = _inferGenreFromSongs(artistSongs, artistLower);
        genreWeights[fallbackGenre] =
            (genreWeights[fallbackGenre] ?? 0) + plays.toDouble();
      }
    }

    if (genreWeights.isEmpty) {
      return [
        GenreStats(name: 'No Data', percentage: 100, color: Colors.grey),
      ];
    }

    // Convert weights to percentages
    final totalWeight = genreWeights.values.fold(0.0, (a, b) => a + b);
    final List<GenreStats> genres = [];

    for (final entry in genreWeights.entries) {
      final pct = totalWeight > 0
          ? ((entry.value / totalWeight) * 100).round()
          : 0;
      if (pct > 0) {
        genres.add(GenreStats(
          name: entry.key,
          percentage: pct,
          color: genreColors[entry.key] ?? const Color(0xFF9E9E9E),
        ));
      }
    }

    // Sort descending
    genres.sort((a, b) => b.percentage.compareTo(a.percentage));

    // Normalise so percentages sum to exactly 100
    if (genres.isNotEmpty) {
      final sum = genres.fold(0, (s, g) => s + g.percentage);
      if (sum != 100 && sum > 0) {
        final diff = 100 - sum;
        genres[0] = GenreStats(
          name: genres[0].name,
          percentage: genres[0].percentage + diff,
          color: genres[0].color,
        );
      }
    }

    return genres.take(6).toList();
  }

  /// Infer genre from song titles, language, and artist name patterns
  /// when the artist isn't found in the known mapping.
  String _inferGenreFromSongs(List<Song> songs, String artistLower) {
    // Check artist name for structural hints first
    if (artistLower.contains('dj ') || artistLower.startsWith('dj')) {
      return 'Electronic';
    }
    if (artistLower.contains('lil ') || artistLower.startsWith('lil ') ||
        artistLower.contains('yung ') || artistLower.contains('mc ') ||
        artistLower.startsWith('mc ')) {
      return 'Hip-Hop';
    }

    if (songs.isEmpty) {
      // No song data at all — use language-neutral fallback
      return 'Other';
    }

    // Tally genres from title keywords
    final Map<String, int> hints = {};
    for (final song in songs) {
      final titleLower = song.title.toLowerCase();
      final lang = (song.language ?? '').toLowerCase();

      // Check title keywords
      for (final kw in _titleGenreKeywords.entries) {
        if (titleLower.contains(kw.key)) {
          hints[kw.value] = (hints[kw.value] ?? 0) + 2;
        }
      }

      // Language-based hints
      if (lang == 'hindi') {
        hints['Bollywood'] = (hints['Bollywood'] ?? 0) + 1;
      } else if (lang == 'punjabi') {
        hints['Punjabi'] = (hints['Punjabi'] ?? 0) + 1;
      } else if (lang == 'english') {
        hints['Pop'] = (hints['Pop'] ?? 0) + 1;
      } else if (lang == 'tamil' || lang == 'telugu' || lang == 'kannada' ||
                 lang == 'malayalam' || lang == 'bengali' || lang == 'marathi' ||
                 lang == 'gujarati') {
        hints['Bollywood'] = (hints['Bollywood'] ?? 0) + 1;
      }
    }

    if (hints.isNotEmpty) {
      final sorted = hints.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted.first.key;
    }

    // Absolute fallback: check language of first song
    final lang = (songs.first.language ?? '').toLowerCase();
    if (lang == 'hindi') return 'Bollywood';
    if (lang == 'punjabi') return 'Punjabi';
    if (lang == 'english') return 'Pop';

    return 'Other';
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
          Row(
            children: [
              Expanded(
                child: InsightCard(
                  icon: Icons.album_rounded,
                  title: 'Top Genre',
                  value: _topGenreName.isNotEmpty ? _topGenreName : 'N/A',
                  subtitle: 'Your favourite',
                  gradient: const [Color(0xFFFF6B8A), Color(0xFFFF8AAE)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InsightCard(
                  icon: Icons.timer_outlined,
                  title: 'Avg Length',
                  value: _avgSongLength.isNotEmpty ? _avgSongLength : 'N/A',
                  subtitle: 'Per song',
                  gradient: const [Color(0xFF6BFFCF), Color(0xFF6BDFFF)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InsightCard(
                  icon: Icons.people_alt_rounded,
                  title: 'Artists',
                  value: '$_uniqueArtistCount',
                  subtitle: 'Explored this week',
                  gradient: const [Color(0xFFB86BFF), Color(0xFF6B8AFF)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InsightCard(
                  icon: Icons.spa_rounded,
                  title: 'Mood',
                  value: _listeningMood.isNotEmpty ? _listeningMood : 'N/A',
                  subtitle: 'Your vibe',
                  gradient: const [Color(0xFFFFB86B), Color(0xFFFF6BD5)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InsightCard(
            icon: Icons.auto_graph_rounded,
            title: 'Listening Streak',
            value: '${_calculateStreak()} days',
            subtitle: _currentStreak > 0 ? 'Keep it going! 🔥' : 'Play something today!',
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

