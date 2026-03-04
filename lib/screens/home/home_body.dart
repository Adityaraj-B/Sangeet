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
import '../albums/albums_screen.dart';
import '../playlist/playlist_body.dart';
import '../playlist/components/playlist_screen.dart';
import '../profile/profile_body.dart';
import '../profile/components/liked_songs.dart';
import 'components/home_banner.dart';
import 'components/home_header.dart';
import 'components/song_cards.dart';
import 'components/playlist_widgets.dart';
import 'components/quick_play_grid.dart';
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

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
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

  @override
  void initState() {
    super.initState();
    _musicService = RemoteMusicService('https://vercelapi-gamma.vercel.app/api');
    _feedService = HomeFeedService(_musicService);
    _loadHomeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Wire up LikeService so personalization can use liked songs
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
        _personalizedSongs = feedData.personalizedSongs;
        _newReleases = feedData.newReleases;
        _moodSongs = feedData.moodSongs;
        _moodLabel = feedData.moodLabel;
        _newReleaseAlbums = feedData.newReleaseAlbums;
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
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 100;

    if (_loading) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
            // Top Padding
            SliverToBoxAdapter(
              child: SizedBox(height: topPadding + 20),
            ),

            // Header with Profile
            SliverToBoxAdapter(
              child: HomeHeader(
                greeting: _greeting,
                onProfileTap: _navigateToProfile,
              ),
            ),

            // Quick Play Grid (Recent/Trending Songs)
            SliverToBoxAdapter(
              child: ValueListenableBuilder<List<Song>>(
                valueListenable: RecentlyPlayedService.recentSongsNotifier,
                builder: (context, recentSongs, _) {
                  if (recentSongs.isEmpty) {
                    return QuickPlayGrid(
                      songs: _trending.take(4).toList(),
                      onPlaySong: widget.onPlaySong,
                    );
                  }
                  return QuickPlayGrid(
                    songs: recentSongs.take(4).toList(),
                    onPlaySong: widget.onPlaySong,
                  );
                },
              ),
            ),

            // Featured Banner
            SliverToBoxAdapter(
              child: HomeBanner(
                songs: _trending,
                onPlaySong: widget.onPlaySong,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // Personalized "Based on Your Recent Plays" Section
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
                child: _buildPersonalizedSongsRow(),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],

            // Trending Albums Section
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'Trending Albums',
                icon: Icons.album_rounded,
                accentColor: const Color(0xFF1DB954),
                onSeeAll: () => _navigateToTrendingAlbums(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: _buildAlbumsRow(),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // Trending Songs Section
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'Trending Songs',
                icon: Icons.trending_up_rounded,
                accentColor: const Color(0xFFFF6B6B),
                onSeeAll: () => _navigateToTrendingSongs(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: _buildTrendingSongsRow(),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // New Releases Section
            if (_newReleases.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: HomeSectionHeader(
                  title: 'New Releases',
                  icon: Icons.new_releases_rounded,
                  accentColor: const Color(0xFF00BCD4),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: _buildNewReleasesRow(),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],

            // Mood-Based Section (time-of-day aware)
            if (_moodSongs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: HomeSectionHeader(
                  title: _moodLabel,
                  icon: _moodIcon,
                  accentColor: _moodColor,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: _buildMoodSongsRow(),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],

            // Liked Songs Section
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'Liked Songs',
                icon: Icons.favorite_rounded,
                accentColor: const Color(0xFFFF6B8A),
                onSeeAll: () => _navigateToLikedSongs(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: _buildLikedSongsRow(),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // Playlists Section
            SliverToBoxAdapter(
              child: HomeSectionHeader(
                title: 'Your Playlists',
                icon: Icons.queue_music_rounded,
                accentColor: const Color(0xFFBB86FC),
                onSeeAll: () => _navigateToAllPlaylists(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: _buildPlaylistsRow(),
            ),

            // Bottom Padding
            SliverToBoxAdapter(
              child: SizedBox(height: bottomPadding),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsRow() {
    if (_trendingAlbums.isEmpty) {
      return _buildEmptyState('No albums available');
    }

    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _trendingAlbums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final album = _trendingAlbums[index];
          return _AlbumCard(
            album: album,
            onTap: () => _navigateToAlbum(album),
          );
        },
      ),
    );
  }

  Widget _buildTrendingSongsRow() {
    final songs = _trending.take(10).toList();
    if (songs.isEmpty) {
      return _buildEmptyState('No trending songs');
    }

    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = songs[index];
          return HorizontalSongCard(
            song: song,
            onTap: () => widget.onPlaySong(song),
          );
        },
      ),
    );
  }

  Widget _buildPersonalizedSongsRow() {
    if (_personalizedSongs.isEmpty) {
      return _buildEmptyState('No personalized songs yet', icon: Icons.auto_awesome);
    }

    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _personalizedSongs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = _personalizedSongs[index];
          return HorizontalSongCard(
            song: song,
            onTap: () => widget.onPlaySong(song),
          );
        },
      ),
    );
  }

  Widget _buildNewReleasesRow() {
    if (_newReleases.isEmpty) {
      return _buildEmptyState('No new releases');
    }

    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _newReleases.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = _newReleases[index];
          return HorizontalSongCard(
            song: song,
            onTap: () => widget.onPlaySong(song),
          );
        },
      ),
    );
  }

  Widget _buildMoodSongsRow() {
    if (_moodSongs.isEmpty) {
      return _buildEmptyState('No mood songs');
    }

    return SizedBox(
      height: 190,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _moodSongs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = _moodSongs[index];
          return HorizontalSongCard(
            song: song,
            onTap: () => widget.onPlaySong(song),
          );
        },
      ),
    );
  }

  Widget _buildLikedSongsRow() {
    return Consumer<LikeService>(
      builder: (context, likeService, _) {
        final likedSongs = likeService.likedSongs.take(10).toList();

        if (likedSongs.isEmpty) {
          return _buildEmptyState('No liked songs yet', icon: Icons.favorite_border);
        }

        return SizedBox(
          height: 190,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: likedSongs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final song = likedSongs[index];
              return HorizontalSongCard(
                song: song,
                onTap: () => widget.onPlaySong(song),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaylistsRow() {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, _) {
        final playlists = provider.playlists;

        return SizedBox(
          height: 190,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: playlists.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                return EmptyPlaylistCard(onTap: _showCreatePlaylistDialog);
              }

              final playlist = playlists[index - 1];
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

  Widget _buildEmptyState(String message, {IconData icon = Icons.music_note}) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.25),
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              message,
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

  // Navigation Methods
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
        builder: (context) => LikedSongsScreen(onPlaySong: widget.onPlaySong),
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

// Album Card Widget
class _AlbumCard extends StatefulWidget {
  final Album album;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.album,
    required this.onTap,
  });

  @override
  State<_AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<_AlbumCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Album Art with glass effect
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.album.coverUrl.isNotEmpty
                          ? Image.network(
                              widget.album.coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                      // Glass shine overlay
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Album Name
              Text(
                widget.album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),

              // Artist
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
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2A2A),
            Color(0xFF1A1A1A),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.album_rounded,
          color: Colors.white.withValues(alpha: 0.15),
          size: 40,
        ),
      ),
    );
  }
}
