import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/album.dart';
import '../../models/song.dart';
import '../../services/remote_music_service.dart';
import '../../services/home_feed_service.dart';
import '../../services/playlist_provider.dart';
import '../../services/recently_played.dart';
import '../../services/like_service.dart';
import '../../services/queue.dart';
import '../albums/albums_screen.dart';
import '../playlist/playlist_body.dart';
import '../playlist/components/playlist_screen.dart';
import '../profile/profile_body.dart';
import '../profile/components/liked_songs.dart';
import '../spotify_import_screen.dart';
import 'components/home_banner.dart';
import 'components/home_header.dart';
import 'components/song_cards.dart';
import 'components/playlist_widgets.dart';
import 'components/quick_play_grid.dart';
import 'components/for_you_section.dart';
import 'components/old components/trending_songs.dart';
import 'components/old components/trending_albums.dart';
import 'package:sangeet/constants.dart';

class HomeScreen extends StatefulWidget {
  final void Function(Song) onPlaySong;

  const HomeScreen({super.key, required this.onPlaySong});

  static const routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollCtrl = ScrollController();
  late final RemoteMusicService _musicService;
  late final HomeFeedService _feedService;

  bool _loading = true;
  List<Song> _trending = [];
  List<Album> _trendingAlbums = [];
  List<Song> _personalizedSongs = [];
  List<Song> _newReleases = [];
  List<Song> _moodSongs = [];
  String _moodLabel = '';
  List<Album> _newReleaseAlbums = [];
  List<DailyMix> _dailyMixes = [];
  List<Song> _rediscoverSongs = [];

  @override
  void initState() {
    super.initState();
    _musicService =
        RemoteMusicService('https://vercelapi-gamma.vercel.app/api');
    _feedService = HomeFeedService(_musicService);
    _loadHomeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _feedService.likeService = context.read<LikeService>();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    _feedService.invalidateCache();
    await _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() => _loading = true);
    try {
      final feedData = await _feedService.loadHomeFeed();
      setState(() {
        _trending = feedData.trendingSongs;
        _trendingAlbums = feedData.trendingAlbums;
        _newReleases = feedData.newReleases;
        _moodSongs = feedData.moodSongs;
        _moodLabel = feedData.moodLabel;
        _newReleaseAlbums = feedData.newReleaseAlbums;

        final mergedPersonalized = <Song>[...feedData.personalizedSongs];
        final seenIds = mergedPersonalized.map((s) => s.id).toSet();
        for (final section in feedData.becauseSections) {
          for (final song in section.recommendations) {
            if (seenIds.add(song.id)) mergedPersonalized.add(song);
          }
        }
        _personalizedSongs = mergedPersonalized;
        _dailyMixes = feedData.dailyMixes;
        _rediscoverSongs = feedData.rediscoverSongs;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  IconData get _moodIcon {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return Icons.wb_sunny_rounded;
    if (hour >= 12 && hour < 17) return Icons.wb_cloudy_rounded;
    if (hour >= 17 && hour < 21) return Icons.nightlife_rounded;
    return Icons.dark_mode_rounded;
  }

  Color get _moodColor {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return const Color(0xFFFFA726);
    if (hour >= 12 && hour < 17) return const Color(0xFF42A5F5);
    if (hour >= 17 && hour < 21) return const Color(0xFFAB47BC);
    return const Color(0xFF5C6BC0);
  }

  Future<void> _showCreatePlaylistDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => CreatePlaylistDialog(controller: controller),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      context.read<PlaylistProvider>().createPlaylist(name);
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileBody(onPlaySong: widget.onPlaySong),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    if (_loading) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
              const SizedBox(height: 16),
              Text(
                'Loading your music...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isDesktop) {
      return _DesktopHomeLayout(
        greeting: _greeting,
        moodIcon: _moodIcon,
        moodColor: _moodColor,
        moodLabel: _moodLabel,
        trending: _trending,
        trendingAlbums: _trendingAlbums,
        personalizedSongs: _personalizedSongs,
        newReleases: _newReleases,
        moodSongs: _moodSongs,
        dailyMixes: _dailyMixes,
        rediscoverSongs: _rediscoverSongs,
        musicService: _musicService,
        onPlaySong: widget.onPlaySong,
        onRefresh: _onRefresh,
        onProfileTap: _navigateToProfile,
        onCreatePlaylist: _showCreatePlaylistDialog,
        onNavigateToPlaylist: _navigateToPlaylist,
        onNavigateToAllPlaylists: _navigateToAllPlaylists,
        onNavigateToAlbum: _navigateToAlbum,
        onNavigateToLikedSongs: _navigateToLikedSongs,
        onNavigateToTrendingSongs: _navigateToTrendingSongs,
        onNavigateToTrendingAlbums: _navigateToTrendingAlbums,
        onNavigateToSpotifyImport: _navigateToSpotifyImport,
        onShowPlaylistOptions: _showPlaylistOptions,
        onPlayDailyMix: _playDailyMix,
      );
    }

    // ── Mobile layout (unchanged) ────────────────────────────────────────
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 100;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: kSurfaceColor,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: topPadding + 20)),
            SliverToBoxAdapter(
              child: HomeHeader(
                  greeting: _greeting, onProfileTap: _navigateToProfile),
            ),
            SliverToBoxAdapter(
              child: ValueListenableBuilder<List<Song>>(
                valueListenable: RecentlyPlayedService.recentSongsNotifier,
                builder: (context, recentSongs, _) {
                  return QuickPlayGrid(
                    songs: recentSongs.isEmpty
                        ? _trending.take(4).toList()
                        : recentSongs.take(4).toList(),
                    onPlaySong: widget.onPlaySong,
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: HomeBanner(
                  songs: _trending, onPlaySong: widget.onPlaySong),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            if (_personalizedSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: HomeSectionHeader(
                  title: 'Based on Your Plays',
                  icon: Icons.auto_awesome_rounded,
                  accentColor: const Color(0xFFFF9800),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                  child: _buildMobileSongRow(_personalizedSongs)),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'For You',
                icon: Icons.explore_rounded,
                accentColor: const Color(0xFFE040FB),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: ForYouSection(
                  musicService: _musicService,
                  onPlaySong: widget.onPlaySong),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            if (_dailyMixes.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: HomeSectionHeader(
                  title: 'Your Daily Mixes',
                  icon: Icons.auto_fix_high_rounded,
                  accentColor: const Color(0xFF8B6BFF),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(child: _buildMobileDailyMixes()),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'Trending Albums',
                icon: Icons.album_rounded,
                accentColor: const Color(0xFF1DB954),
                onSeeAll: _navigateToTrendingAlbums,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(child: _buildMobileAlbumsRow()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'Trending Songs',
                icon: Icons.trending_up_rounded,
                accentColor: const Color(0xFFFF6B6B),
                onSeeAll: _navigateToTrendingSongs,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
                child: _buildMobileSongRow(_trending.take(10).toList())),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            if (_newReleases.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: HomeSectionHeader(
                  title: 'New Releases',
                  icon: Icons.new_releases_rounded,
                  accentColor: const Color(0xFF00BCD4),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(child: _buildMobileSongRow(_newReleases)),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
            if (_moodSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: HomeSectionHeader(
                  title: _moodLabel,
                  icon: _moodIcon,
                  accentColor: _moodColor,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(child: _buildMobileSongRow(_moodSongs)),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
            if (_rediscoverSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: HomeSectionHeader(
                  title: 'Rediscover',
                  icon: Icons.history_rounded,
                  accentColor: const Color(0xFFFFB86B),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                  child: _buildMobileSongRow(_rediscoverSongs)),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'Liked Songs',
                icon: Icons.favorite_rounded,
                accentColor: const Color(0xFFFF6B8A),
                onSeeAll: _navigateToLikedSongs,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(child: _buildMobileLikedSongs()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'Your Playlists',
                icon: Icons.queue_music_rounded,
                accentColor: const Color(0xFFBB86FC),
                onSeeAll: _navigateToAllPlaylists,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(child: _buildMobilePlaylistsRow()),
            SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
          ],
        ),
      ),
    );
  }

  // ── Mobile-only widget builders ──────────────────────────────────────────

  Widget _buildMobileSongRow(List<Song> songs) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => HorizontalSongCard(
          song: songs[index],
          width: 140,
          height: 140,
          onTap: () => widget.onPlaySong(songs[index]),
        ),
      ),
    );
  }

  Widget _buildMobileAlbumsRow() {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _trendingAlbums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => _AlbumCard(
          album: _trendingAlbums[index],
          onTap: () => _navigateToAlbum(_trendingAlbums[index]),
        ),
      ),
    );
  }

  Widget _buildMobileDailyMixes() {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _dailyMixes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => _DailyMixCard(
          mix: _dailyMixes[index],
          onTap: () => _playDailyMix(_dailyMixes[index]),
        ),
      ),
    );
  }

  Widget _buildMobileLikedSongs() {
    return Consumer<LikeService>(
      builder: (context, likeService, _) {
        final likedSongs = likeService.likedSongs.take(10).toList();
        if (likedSongs.isEmpty) {
          return _buildMobileEmptyState('No liked songs yet',
              icon: Icons.favorite_border);
        }
        return _buildMobileSongRow(likedSongs);
      },
    );
  }

  Widget _buildMobilePlaylistsRow() {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        final playlists = provider.playlists;
        return SizedBox(
          height: 190,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: playlists.length + 2,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                return EmptyPlaylistCard(onTap: _showCreatePlaylistDialog);
              }
              if (index == 1) {
                return _SpotifyImportCard(
                    onTap: _navigateToSpotifyImport);
              }
              final playlist = playlists[index - 2];
              return PlaylistCard(
                playlist: playlist,
                onTap: () => _navigateToPlaylist(playlist),
                onLongPress: () => _showPlaylistOptions(playlist),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMobileEmptyState(String message,
      {IconData icon = Icons.music_note}) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.25), size: 36),
            const SizedBox(height: 10),
            Text(message,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Navigation ───────────────────────────────────────────────────────────

  void _playDailyMix(DailyMix mix) {
    if (mix.songs.isEmpty) return;
    final queueService = QueueService();
    queueService.clearQueue();
    if (mix.songs.length > 1) {
      queueService.addAllToQueue(mix.songs.sublist(1));
    }
    widget.onPlaySong(mix.songs.first);
  }

  void _navigateToAlbum(Album album) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumScreen(
          album: album,
          musicService: _musicService,
          onPlaySong: widget.onPlaySong,
        ),
      ),
    );
  }

  void _navigateToTrendingSongs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrendingSongsPage(
          trendingSongs: _trending,
          onPlay: widget.onPlaySong,
          surfaceColor: kBackgroundColor,
          softWhite: const Color(0xFFF5F5F5),
        ),
      ),
    );
  }

  void _navigateToTrendingAlbums() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrendingAlbumsPage(
          trendingAlbums: _trendingAlbums,
          musicService: _musicService,
          onPlaySong: widget.onPlaySong,
        ),
      ),
    );
  }

  void _navigateToLikedSongs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LikedSongsScreen(onPlaySong: widget.onPlaySong),
      ),
    );
  }

  void _navigateToPlaylist(dynamic playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistBody(
          playlist: playlist,
          onPlaySong: widget.onPlaySong,
        ),
      ),
    );
  }

  void _navigateToAllPlaylists() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaylistsScreen(onPlaySong: widget.onPlaySong),
      ),
    );
  }

  void _navigateToSpotifyImport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SpotifyImportScreen()),
    );
  }

  void _showPlaylistOptions(dynamic playlist) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PlaylistOptionsSheet(playlist: playlist),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

// ── Desktop Home Layout ───────────────────────────────────────────────────────

class _DesktopHomeLayout extends StatelessWidget {
  final String greeting;
  final IconData moodIcon;
  final Color moodColor;
  final String moodLabel;
  final List<Song> trending;
  final List<Album> trendingAlbums;
  final List<Song> personalizedSongs;
  final List<Song> newReleases;
  final List<Song> moodSongs;
  final List<DailyMix> dailyMixes;
  final List<Song> rediscoverSongs;
  final RemoteMusicService musicService;
  final void Function(Song) onPlaySong;
  final Future<void> Function() onRefresh;
  final VoidCallback onProfileTap;
  final VoidCallback onCreatePlaylist;
  final void Function(dynamic) onNavigateToPlaylist;
  final VoidCallback onNavigateToAllPlaylists;
  final void Function(Album) onNavigateToAlbum;
  final VoidCallback onNavigateToLikedSongs;
  final VoidCallback onNavigateToTrendingSongs;
  final VoidCallback onNavigateToTrendingAlbums;
  final VoidCallback onNavigateToSpotifyImport;
  final void Function(dynamic) onShowPlaylistOptions;
  final void Function(DailyMix) onPlayDailyMix;

  const _DesktopHomeLayout({
    required this.greeting,
    required this.moodIcon,
    required this.moodColor,
    required this.moodLabel,
    required this.trending,
    required this.trendingAlbums,
    required this.personalizedSongs,
    required this.newReleases,
    required this.moodSongs,
    required this.dailyMixes,
    required this.rediscoverSongs,
    required this.musicService,
    required this.onPlaySong,
    required this.onRefresh,
    required this.onProfileTap,
    required this.onCreatePlaylist,
    required this.onNavigateToPlaylist,
    required this.onNavigateToAllPlaylists,
    required this.onNavigateToAlbum,
    required this.onNavigateToLikedSongs,
    required this.onNavigateToTrendingSongs,
    required this.onNavigateToTrendingAlbums,
    required this.onNavigateToSpotifyImport,
    required this.onShowPlaylistOptions,
    required this.onPlayDailyMix,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: kSurfaceColor,
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Listen Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onProfileTap,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: Colors.white70, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Quick Play + Banner side by side ────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick play grid — compact 2×2
                    Expanded(
                      flex: 5,
                      child: ValueListenableBuilder<List<Song>>(
                        valueListenable:
                        RecentlyPlayedService.recentSongsNotifier,
                        builder: (context, recentSongs, _) {
                          final songs = (recentSongs.isEmpty
                              ? trending.take(4)
                              : recentSongs.take(4))
                              .toList();
                          return _DesktopQuickGrid(
                              songs: songs, onPlaySong: onPlaySong);
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Banner — clipped to exactly 220px, overflow hidden
                    Expanded(
                      flex: 7,
                      child: SizedBox(
                        height: 220,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxHeight: double.infinity,
                            child: HomeBanner(
                                songs: trending, onPlaySong: onPlaySong),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 36)),

            // ── Based on Your Plays ──────────────────────────────────────
            if (personalizedSongs.isNotEmpty) ...[
              _desktopSectionHeader(
                'Based on Your Plays',
                Icons.auto_awesome_rounded,
                const Color(0xFFFF9800),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: _DesktopSongRow(
                    songs: personalizedSongs, onPlaySong: onPlaySong),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            // ── For You ─────────────────────────────────────────────────
            _desktopSectionHeader(
                'For You', Icons.explore_rounded, const Color(0xFFE040FB)),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ForYouSection(
                    musicService: musicService, onPlaySong: onPlaySong),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── Daily Mixes ──────────────────────────────────────────────
            if (dailyMixes.isNotEmpty) ...[
              _desktopSectionHeader('Your Daily Mixes',
                  Icons.auto_fix_high_rounded, const Color(0xFF8B6BFF)),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: _DesktopDailyMixRow(
                    mixes: dailyMixes, onPlay: onPlayDailyMix),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            // ── Trending Albums ──────────────────────────────────────────
            _desktopSectionHeader(
              'Trending Albums',
              Icons.album_rounded,
              const Color(0xFF1DB954),
              onSeeAll: onNavigateToTrendingAlbums,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: _DesktopAlbumRow(
                  albums: trendingAlbums, onTap: onNavigateToAlbum),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── Trending Songs ───────────────────────────────────────────
            _desktopSectionHeader(
              'Trending Songs',
              Icons.trending_up_rounded,
              const Color(0xFFFF6B6B),
              onSeeAll: onNavigateToTrendingSongs,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: _DesktopSongRow(
                  songs: trending.take(10).toList(), onPlaySong: onPlaySong),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── New Releases ─────────────────────────────────────────────
            if (newReleases.isNotEmpty) ...[
              _desktopSectionHeader('New Releases', Icons.new_releases_rounded,
                  const Color(0xFF00BCD4)),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: _DesktopSongRow(
                    songs: newReleases, onPlaySong: onPlaySong),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            // ── Mood ─────────────────────────────────────────────────────
            if (moodSongs.isNotEmpty) ...[
              _desktopSectionHeader(moodLabel, moodIcon, moodColor),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child:
                _DesktopSongRow(songs: moodSongs, onPlaySong: onPlaySong),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            // ── Rediscover ───────────────────────────────────────────────
            if (rediscoverSongs.isNotEmpty) ...[
              _desktopSectionHeader('Rediscover', Icons.history_rounded,
                  const Color(0xFFFFB86B)),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: _DesktopSongRow(
                    songs: rediscoverSongs, onPlaySong: onPlaySong),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],

            // ── Liked Songs ──────────────────────────────────────────────
            _desktopSectionHeader(
              'Liked Songs',
              Icons.favorite_rounded,
              const Color(0xFFFF6B8A),
              onSeeAll: onNavigateToLikedSongs,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: Consumer<LikeService>(
                builder: (context, likeService, _) {
                  final liked = likeService.likedSongs.take(10).toList();
                  if (liked.isEmpty) {
                    return _desktopEmptyState(
                        'No liked songs yet', Icons.favorite_border);
                  }
                  return _DesktopSongRow(songs: liked, onPlaySong: onPlaySong);
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── Playlists ────────────────────────────────────────────────
            _desktopSectionHeader(
              'Your Playlists',
              Icons.queue_music_rounded,
              const Color(0xFFBB86FC),
              onSeeAll: onNavigateToAllPlaylists,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: Consumer<PlaylistProvider>(
                builder: (context, provider, _) {
                  return _DesktopPlaylistRow(
                    playlists: provider.playlists,
                    onCreatePlaylist: onCreatePlaylist,
                    onNavigateToPlaylist: onNavigateToPlaylist,
                    onShowPlaylistOptions: onShowPlaylistOptions,
                    onNavigateToSpotifyImport: onNavigateToSpotifyImport,
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _desktopSectionHeader(
      String title,
      IconData icon,
      Color accent, {
        VoidCallback? onSeeAll,
      }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _desktopEmptyState(String message, IconData icon) {
    return Container(
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.25), size: 20),
            const SizedBox(width: 10),
            Text(message,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Desktop component widgets ─────────────────────────────────────────────────

/// Compact 2×2 quick-play grid for desktop — tighter and denser than mobile.
class _DesktopQuickGrid extends StatelessWidget {
  final List<Song> songs;
  final void Function(Song) onPlaySong;

  const _DesktopQuickGrid({required this.songs, required this.onPlaySong});

  @override
  Widget build(BuildContext context) {
    final items = songs.take(4).toList();
    while (items.length < 4) {
      items.add(items.first);
    }

    return SizedBox(
      height: 220,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _QuickItem(song: items[0], onTap: () => onPlaySong(items[0]))),
                const SizedBox(width: 10),
                Expanded(child: _QuickItem(song: items[1], onTap: () => onPlaySong(items[1]))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _QuickItem(song: items[2], onTap: () => onPlaySong(items[2]))),
                const SizedBox(width: 10),
                Expanded(child: _QuickItem(song: items[3], onTap: () => onPlaySong(items[3]))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickItem extends StatefulWidget {
  final Song song;
  final VoidCallback onTap;

  const _QuickItem({required this.song, required this.onTap});

  @override
  State<_QuickItem> createState() => _QuickItemState();
}

class _QuickItemState extends State<_QuickItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(10)),
                child: widget.song.coverUrl.isNotEmpty
                    ? Image.network(
                  widget.song.coverUrl,
                  width: 52,
                  height: double.infinity,
                  fit: BoxFit.cover,
                )
                    : Container(
                  width: 52,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: const Icon(Icons.music_note,
                      color: Colors.white24, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.play_circle_filled_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal song row for desktop — smaller cards, more visible at once.
class _DesktopSongRow extends StatelessWidget {
  final List<Song> songs;
  final void Function(Song) onPlaySong;

  const _DesktopSongRow({required this.songs, required this.onPlaySong});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = songs[index];
          return _DesktopSongCard(
              song: song, onTap: () => onPlaySong(song));
        },
      ),
    );
  }
}

class _DesktopSongCard extends StatefulWidget {
  final Song song;
  final VoidCallback onTap;

  const _DesktopSongCard({required this.song, required this.onTap});

  @override
  State<_DesktopSongCard> createState() => _DesktopSongCardState();
}

class _DesktopSongCardState extends State<_DesktopSongCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: widget.song.coverUrl.isNotEmpty
                        ? Image.network(
                      widget.song.coverUrl,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      width: 120,
                      height: 120,
                      color: Colors.white.withValues(alpha: 0.06),
                      child: const Icon(Icons.music_note,
                          color: Colors.white24),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                      child: const Center(
                        child: Icon(Icons.play_circle_filled_rounded,
                            color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Album row for desktop.
class _DesktopAlbumRow extends StatelessWidget {
  final List<Album> albums;
  final void Function(Album) onTap;

  const _DesktopAlbumRow({required this.albums, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: albums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final album = albums[index];
          return _AlbumCard(album: album, onTap: () => onTap(album));
        },
      ),
    );
  }
}

/// Daily mix row for desktop.
class _DesktopDailyMixRow extends StatelessWidget {
  final List<DailyMix> mixes;
  final void Function(DailyMix) onPlay;

  const _DesktopDailyMixRow({required this.mixes, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: mixes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final mix = mixes[index];
          return _DailyMixCard(mix: mix, onTap: () => onPlay(mix));
        },
      ),
    );
  }
}

/// Playlist row for desktop.
class _DesktopPlaylistRow extends StatelessWidget {
  final List<dynamic> playlists;
  final VoidCallback onCreatePlaylist;
  final void Function(dynamic) onNavigateToPlaylist;
  final void Function(dynamic) onShowPlaylistOptions;
  final VoidCallback onNavigateToSpotifyImport;

  const _DesktopPlaylistRow({
    required this.playlists,
    required this.onCreatePlaylist,
    required this.onNavigateToPlaylist,
    required this.onShowPlaylistOptions,
    required this.onNavigateToSpotifyImport,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,   // was 170 — cards include image + two text lines below
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: playlists.length + 2,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return EmptyPlaylistCard(onTap: onCreatePlaylist);
          }
          if (index == 1) {
            return _SpotifyImportCard(onTap: onNavigateToSpotifyImport);
          }
          final playlist = playlists[index - 2];
          return PlaylistCard(
            playlist: playlist,
            onTap: () => onNavigateToPlaylist(playlist),
            onLongPress: () => onShowPlaylistOptions(playlist),
          );
        },
      ),
    );
  }
}

// ── Shared card widgets (used by both mobile and desktop) ─────────────────────

class _AlbumCard extends StatefulWidget {
  final Album album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: widget.album.coverUrl.isNotEmpty
                      ? Image.network(
                    widget.album.coverUrl,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _placeholder(),
                  )
                      : _placeholder(),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.album.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
      ),
      child: Center(
        child: Icon(Icons.album_rounded,
            color: Colors.white.withValues(alpha: 0.15), size: 32),
      ),
    );
  }
}

class _SpotifyImportCard extends StatefulWidget {
  final VoidCallback onTap;

  const _SpotifyImportCard({required this.onTap});

  @override
  State<_SpotifyImportCard> createState() => _SpotifyImportCardState();
}

class _SpotifyImportCardState extends State<_SpotifyImportCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 120,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _hovered
                ? const Color(0xFF1DB954).withValues(alpha: 0.15)
                : const Color(0xFF1DB954).withValues(alpha: 0.08),
            border: Border.all(
              color: const Color(0xFF1DB954).withValues(alpha: 0.3),
              width: 0.6,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download_rounded,
                  color: Color(0xFF1DB954), size: 28),
              const SizedBox(height: 10),
              const Text(
                'Import from\nSpotify',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1DB954),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyMixCard extends StatefulWidget {
  final DailyMix mix;
  final VoidCallback onTap;

  const _DailyMixCard({required this.mix, required this.onTap});

  @override
  State<_DailyMixCard> createState() => _DailyMixCardState();
}

class _DailyMixCardState extends State<_DailyMixCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = Color(widget.mix.accentColorHex);
    final coverUrl =
    widget.mix.songs.isNotEmpty ? widget.mix.songs.first.coverUrl : '';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      if (coverUrl.isNotEmpty)
                        Image.network(coverUrl,
                            width: 140,
                            height: 140,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                width: 140,
                                height: 140,
                                color: accent.withValues(alpha: 0.3)))
                      else
                        Container(
                            width: 140,
                            height: 140,
                            color: accent.withValues(alpha: 0.3)),
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.8),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: Text(
                          widget.mix.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.mix.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
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