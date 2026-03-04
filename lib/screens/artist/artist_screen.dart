import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/models/artist.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/models/album.dart';
import 'package:sangeet/services/remote_music_service.dart';
import 'package:sangeet/components/bottom_player_container.dart';
import 'package:sangeet/services/audio_player_service.dart';
import 'package:sangeet/services/queue.dart';
import 'package:sangeet/screens/player/player_body.dart';
import 'package:sangeet/screens/artist/components/artist_song_tile.dart';
import 'package:sangeet/screens/artist/components/artist_album_card.dart';
import 'components/artist_load_more_button.dart';
import 'components/liquid_glass_button.dart';

class ArtistScreen extends StatefulWidget {
  final String artistId;
  final RemoteMusicService musicService;
  final void Function(Song) onPlaySong;

  const ArtistScreen({
    super.key,
    required this.artistId,
    required this.musicService,
    required this.onPlaySong,
  });

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  Artist? _artist;
  List<Song> _topSongs = [];
  List<Song> _latestSongs = [];
  List<Album> _albums = [];

  bool _isTitleVisible = false;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_scrollListener);
    _loadArtistData();
  }

  void _scrollListener() {
    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    bool isVisible = offset > (380 - kToolbarHeight);

    if (offset != _scrollOffset) {
      setState(() => _scrollOffset = offset);
    }
    if (isVisible != _isTitleVisible) {
      setState(() => _isTitleVisible = isVisible);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArtistData() async {
    try {
      final results = await Future.wait([
        widget.musicService.getArtistDetails(widget.artistId),
        widget.musicService.getArtistSongs(widget.artistId),
        widget.musicService.searchAlbums(widget.artistId),
      ]);

      if (!mounted) return;

      final artist = results[0] as Artist?;
      final songs = results[1] as List<Song>;
      final albums = results[2] as List<Album>;

      if (artist != null) {
        final validSongs = songs.where((s) => s.streamUrl?.isNotEmpty == true).toList();
        final popularitySorted = List<Song>.from(validSongs);
        final latestSorted = List<Song>.from(validSongs.reversed);

        final filteredAlbums = albums.where((a) =>
        a.artist.toLowerCase().contains(artist.name.toLowerCase()) ||
            a.name.toLowerCase().contains(artist.name.toLowerCase())
        ).toList();

        setState(() {
          _artist = artist;
          _topSongs = popularitySorted;
          _latestSongs = latestSorted;
          _albums = filteredAlbums;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading artist data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _playAll() {
    if (_topSongs.isEmpty) return;
    HapticFeedback.mediumImpact();

    final audio = AudioPlayerService();

    // IMPORTANT: Clear queue and add remaining songs BEFORE playing
    audio.queue.clearQueue();
    if (_topSongs.length > 1) {
      audio.queue.addAllToQueue(_topSongs.sublist(1));
    }

    // Now play the first song
    widget.onPlaySong(_topSongs.first);
  }

  void _shufflePlay() {
    if (_topSongs.isEmpty) return;
    HapticFeedback.mediumImpact();

    final audio = AudioPlayerService();
    final shuffled = List<Song>.from(_topSongs)..shuffle();

    // IMPORTANT: Clear queue and add remaining songs BEFORE playing
    audio.queue.clearQueue();
    if (shuffled.length > 1) {
      audio.queue.addAllToQueue(shuffled.sublist(1));
    }

    // Now play the first song
    widget.onPlaySong(shuffled.first);
  }

  void _openPlayerScreen() {
    final audio = AudioPlayerService();
    final currentSong = audio.currentSong;

    if (currentSong == null || !mounted) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
          onCollapse: () => Navigator.pop(context),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_artist == null) return _buildError();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Ambient background glow
          Positioned(
            top: -100,
            left: -50,
            right: -50,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    kAccentColor.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  radius: 1.2,
                ),
              ),
            ),
          ),
          NestedScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildSliverAppBar(),
                _buildPersistentHeader(),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _PopularSongsTab(songs: _topSongs, onPlay: widget.onPlaySong),
                _LatestSongsTab(songs: _latestSongs, onPlay: widget.onPlaySong),
                _AlbumsTab(albums: _albums),
              ],
            ),
          ),
          // Bottom player container
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: BottomPlayerContainer(
                backgroundColor: kBackgroundColor,
                onTap: _openPlayerScreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 420,
      pinned: true,
      stretch: true,
      backgroundColor: kBackgroundColor,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      title: AnimatedOpacity(
        opacity: _isTitleVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _artist!.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image with blur effect
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Image.network(
                _artist!.imageUrl,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.3),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (_,__,___) => Container(color: kBackgroundColor),
              ),
            ),
            // Gradient overlays
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.2),
                    kBackgroundColor.withValues(alpha: 0.7),
                    kBackgroundColor.withValues(alpha: 0.95),
                    kBackgroundColor,
                  ],
                  stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                ),
              ),
            ),
            // Artist content
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Artist avatar with glow
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kAccentColor.withValues(alpha: 0.25),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 3,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.network(
                            _artist!.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_,__,___) => Container(
                              color: Colors.grey[900],
                              child: Icon(Icons.person, size: 60, color: Colors.white.withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Artist name
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _artist!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Song count with badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "${_topSongs.length} songs • ${_albums.length} albums",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LiquidGlassButton(
                          onPressed: _shufflePlay,
                          icon: Icons.shuffle_rounded,
                          label: 'Shuffle',
                          isPrimary: false,
                        ),
                        const SizedBox(width: 16),
                        LiquidGlassButton(
                          onPressed: _playAll,
                          icon: Icons.play_arrow_rounded,
                          label: 'Play All',
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersistentHeader() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
          indicatorColor: kAccentColor,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 3,
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.3),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: const [
            Tab(text: "Popular"),
            Tab(text: "Latest"),
            Tab(text: "Albums"),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: kAccentColor,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading artist...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Could not load artist",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please check your connection and try again",
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
}

// Popular Songs Tab
class _PopularSongsTab extends StatefulWidget {
  final List<Song> songs;
  final Function(Song) onPlay;
  const _PopularSongsTab({required this.songs, required this.onPlay});

  @override
  State<_PopularSongsTab> createState() => _PopularSongsTabState();
}

class _PopularSongsTabState extends State<_PopularSongsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _displayCount = 15;
  bool get _hasMore => _displayCount < widget.songs.length;

  void _loadMore() {
    setState(() => _displayCount = widget.songs.length);
  }

  void _handleSongTap(Song song, int index) {
    final queueService = QueueService();

    // IMPORTANT: Add remaining songs to queue BEFORE playing
    if (index < widget.songs.length - 1) {
      final remainingSongs = widget.songs.sublist(index + 1);
      queueService.addAllToQueue(remainingSongs);
    }

    // Now play the tapped song
    widget.onPlay(song);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.songs.isEmpty) {
      return const Center(child: Text("No songs found", style: TextStyle(color: Colors.white54)));
    }

    final displaySongs = widget.songs.take(_displayCount).toList();

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 100),
        itemCount: displaySongs.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == displaySongs.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ArtistLoadMoreButton(
                onPressed: _loadMore,
                text: 'Show ${widget.songs.length - _displayCount} more',
              ),
            );
          }

          final song = displaySongs[index];
          final rank = index + 1;

          return ArtistSongTile(
            song: song,
            rank: rank,
            onTap: () => _handleSongTap(song, index),
            showRank: true,
          );
        },
      ),
    );
  }
}

// Latest Songs Tab
class _LatestSongsTab extends StatefulWidget {
  final List<Song> songs;
  final Function(Song) onPlay;
  const _LatestSongsTab({required this.songs, required this.onPlay});

  @override
  State<_LatestSongsTab> createState() => _LatestSongsTabState();
}

class _LatestSongsTabState extends State<_LatestSongsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _displayCount = 20;
  bool get _hasMore => _displayCount < widget.songs.length;

  void _loadMore() {
    setState(() => _displayCount = widget.songs.length);
  }

  void _handleSongTap(Song song, int index) {
    final queueService = QueueService();

    // IMPORTANT: Add remaining songs to queue BEFORE playing
    if (index < widget.songs.length - 1) {
      final remainingSongs = widget.songs.sublist(index + 1);
      queueService.addAllToQueue(remainingSongs);
    }

    // Now play the tapped song
    widget.onPlay(song);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.songs.isEmpty) {
      return const Center(child: Text("No recent releases", style: TextStyle(color: Colors.white54)));
    }

    final displaySongs = widget.songs.take(_displayCount).toList();

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 12, bottom: 100),
        itemCount: displaySongs.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == displaySongs.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ArtistLoadMoreButton(
                onPressed: _loadMore,
                text: 'Show ${widget.songs.length - _displayCount} more',
              ),
            );
          }

          final song = displaySongs[index];
          return ArtistSongTile(
            song: song,
            onTap: () => _handleSongTap(song, index),
            showRank: false,
          );
        },
      ),
    );
  }
}

// Albums Tab
class _AlbumsTab extends StatefulWidget {
  final List<Album> albums;
  const _AlbumsTab({required this.albums});

  @override
  State<_AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<_AlbumsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _displayCount = 10;
  bool get _hasMore => _displayCount < widget.albums.length;

  void _loadMore() {
    setState(() => _displayCount = widget.albums.length);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.albums.isEmpty) {
      return const Center(child: Text("No albums found", style: TextStyle(color: Colors.white54)));
    }

    final displayAlbums = widget.albums.take(_displayCount).toList();

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) => ArtistAlbumCard(album: displayAlbums[index]),
                childCount: displayAlbums.length,
              ),
            ),
          ),
          if (_hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
                child: ArtistLoadMoreButton(
                  onPressed: _loadMore,
                  text: 'Show ${widget.albums.length - _displayCount} more',
                ),
              ),
            ),
          if (!_hasMore)
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}


class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: kBackgroundColor.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
          ),
          child: _tabBar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}