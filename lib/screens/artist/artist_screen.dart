import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/models/artist.dart';
import 'package:sangeet/models/song.dart';
import 'package:sangeet/models/album.dart';
import 'package:sangeet/services/remote_music_service.dart';
import 'package:sangeet/components/bottom_player_container.dart';
import 'package:sangeet/services/audio_player_service.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_scrollListener);
    _loadArtistData();
  }

  void _scrollListener() {
    bool isVisible = _scrollController.hasClients &&
        _scrollController.offset > (340 - kToolbarHeight);
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

    final audio = AudioPlayerService();

    // Match AlbumScreen behavior: clear queue, play first, queue the rest.
    audio.queue.clearQueue();
    widget.onPlaySong(_topSongs.first);

    if (_topSongs.length > 1) {
      audio.queue.addAllToQueue(_topSongs.sublist(1));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_artist == null) return _buildError();

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          NestedScrollView(
            controller: _scrollController,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      stretch: true,
      backgroundColor: kBackgroundColor,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
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
        child: Text(
          _artist!.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _artist!.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_,__,___) => Container(color: Colors.grey[900]),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.3),
                    kBackgroundColor.withValues(alpha: 0.95),
                    kBackgroundColor,
                  ],
                  stops: const [0.0, 0.3, 0.85, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _artist!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${_topSongs.length} songs",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _GlassButton(
                          onPressed: _playAll,
                          isPrimary: true,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 22),
                              SizedBox(width: 8),
                              Text(
                                "Play",
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _GlassButton(
                        onPressed: () {},
                        isPrimary: false,
                        child: const Icon(Icons.shuffle_rounded, size: 20),
                      ),
                    ],
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
          unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
          indicatorColor: kAccentColor,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          dividerColor: Colors.transparent,
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
    return const Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(child: CircularProgressIndicator(color: kAccentColor)),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: const Center(child: Text("Could not load artist data", style: TextStyle(color: Colors.white))),
    );
  }
}

// Glass Button Widget
class _GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final bool isPrimary;

  const _GlassButton({
    required this.onPressed,
    required this.child,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPrimary
                  ? [kAccentColor, kAccentColor.withValues(alpha: 0.8)]
                  : [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.05)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPrimary ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: isPrimary ? 24 : 20,
                ),
                child: child,
              ),
            ),
          ),
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
              child: _LoadMoreButton(
                onPressed: _loadMore,
                text: 'Show ${widget.songs.length - _displayCount} more',
              ),
            );
          }

          final song = displaySongs[index];
          final rank = index + 1;

          return _SongTile(
            song: song,
            rank: rank,
            onTap: () => widget.onPlay(song),
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
              child: _LoadMoreButton(
                onPressed: _loadMore,
                text: 'Show ${widget.songs.length - _displayCount} more',
              ),
            );
          }

          final song = displaySongs[index];
          return _SongTile(
            song: song,
            onTap: () => widget.onPlay(song),
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
                    (context, index) => _AlbumCard(album: displayAlbums[index]),
                childCount: displayAlbums.length,
              ),
            ),
          ),
          if (_hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
                child: _LoadMoreButton(
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

// Song Tile Widget
class _SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final bool showRank;
  final int? rank;

  const _SongTile({
    required this.song,
    required this.onTap,
    this.showRank = false,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      if (showRank && rank != null) ...[
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$rank',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          song.coverUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_,__,___) => Container(
                            width: 52,
                            height: 52,
                            color: Colors.white.withValues(alpha: 0.05),
                            child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 20,
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Album Card Widget
class _AlbumCard extends StatelessWidget {
  final Album album;
  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    album.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: Icon(Icons.album, size: 60, color: Colors.white.withValues(alpha: 0.3)),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.4),
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
          Text(
            album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            album.year.isNotEmpty ? album.year : 'Album',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Load More Button Widget
class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const _LoadMoreButton({
    required this.onPressed,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
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