import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/album.dart';
import '../../models/song.dart';
import '../../services/remote_music_service.dart';
import '../../services/playlist_provider.dart';
import '../../services/recently_played.dart';
import '../albums/albums_screen.dart';
import '../playlist/playlist_body.dart';
import '../recent/recent_screen.dart';
import 'components/banner_widget.dart';
import 'components/section_header.dart';
import 'components/song_list.dart';
import 'components/trending_songs.dart';
import 'components/vertical_song_list.dart';
import 'package:sangeet/constants.dart';

class HomeScreen extends StatefulWidget {
  final void Function(Song) onPlaySong;

  const HomeScreen({super.key, required this.onPlaySong});

  static const routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late final RemoteMusicService _musicService;

  String _query = '';
  List<int> _visibleRecent = [];
  List<int> _visibleTrending = [];
  Timer? _staggerTimer;
  final List<Timer> _staggerTimers = []; // Track all stagger timers
  bool _loading = true;

  List<Song> _recent = [];
  List<Song> _trending = [];
  List<Album> _trendingAlbums = [];

  @override
  void initState() {
    super.initState();
    _musicService = RemoteMusicService('https://vercelapi-gamma.vercel.app/api');
    _searchCtrl.addListener(_onSearchChanged);
    _loadHomeData();
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    // Cancel all stagger timers to prevent memory leaks
    for (final timer in _staggerTimers) {
      timer.cancel();
    }
    _staggerTimers.clear();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final value = _searchCtrl.text.trim().toLowerCase();
    if (value != _query) {
      setState(() => _query = value);
      _runStagger();
    }
  }

  Future<void> _onRefresh() async {
    await _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() => _loading = true);
    try {
      final trendingSongs = await _musicService.getTrending();
      final trendingAlbums = await _musicService.getTrendingAlbums();

      setState(() {
        _trending = trendingSongs;
        _trendingAlbums = trendingAlbums;
        _recent = trendingSongs; // In real app, this would be from RecentlyPlayedService
        _loading = false;
      });
      _runStagger();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _runStagger() {
    _staggerTimer?.cancel();
    // Cancel all previous stagger timers
    for (final timer in _staggerTimers) {
      timer.cancel();
    }
    _staggerTimers.clear();
    _visibleRecent = [];
    _visibleTrending = [];
    const delay = 60;
    int offset = 0;

    // Stagger trending songs (limited to 15)
    for (int i = 0; i < _filteredTrending.length; i++) {
      final timer = Timer(Duration(milliseconds: delay * offset++), () {
        if (mounted) setState(() => _visibleTrending.add(i));
      });
      _staggerTimers.add(timer);
    }

    // Stagger recently played songs
    for (int i = 0; i < _filteredRecent.length; i++) {
      final timer = Timer(Duration(milliseconds: delay * offset++), () {
        if (mounted) setState(() => _visibleRecent.add(i));
      });
      _staggerTimers.add(timer);
    }
  }

  // Search Filters
  List<Album> get _filteredAlbums {
    if (_query.isEmpty) return _trendingAlbums;
    return _trendingAlbums.where((a) {
      return a.name.toLowerCase().contains(_query) ||
          a.artist.toLowerCase().contains(_query);
    }).toList();
  }

  // Limit trending songs to 15
  List<Song> get _filteredTrending {
    final trending = _query.isEmpty
        ? _trending.take(15).toList()
        : _trending.where((s) =>
            s.title.toLowerCase().contains(_query) ||
            s.artist.toLowerCase().contains(_query)).take(15).toList();
    return trending;
  }

  List<Song> get _filteredRecent {
    if (_query.isEmpty) return _recent;
    return _recent.where((s) =>
    s.title.toLowerCase().contains(_query) ||
        s.artist.toLowerCase().contains(_query)).toList();
  }

  // Playlist Creation Helper
  Future<void> _showCreateDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => _CreatePlaylistDialog(controller: controller),
    );

    if (name != null && name.isNotEmpty && context.mounted) {
      context.read<PlaylistProvider>().createPlaylist(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomInset = MediaQuery.of(context).padding.bottom + 84;
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          // 1. Trending Banner
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            height: 320,
            child: _trending.isNotEmpty
                ? BannerWidget(
              trendingSongs: _trending,
              searchController: _searchCtrl,
              surfaceColor: kSurfaceColor,
              softWhite: kPrimaryColor,
              onPlaySong: widget.onPlaySong,
            )
                : Container(color: kSurfaceColor),
          ),

          // 2. Main Content
          RefreshIndicator(
            color: kPrimaryColor,
            backgroundColor: kSurfaceColor,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: topPadding + 305)),

                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: kBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, bottomInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- SECTION 1: TRENDING ALBUMS ---
                          SectionHeader(title: 'Trending Albums', onSeeAll: () {}),
                          const SizedBox(height: 12),
                          HorizontalAlbumList(
                            albums: _filteredAlbums,
                            onAlbumTap: (album) {
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
                            },
                          ),
                          const SizedBox(height: 8),

                          // --- SECTION 2: TRENDING SONGS (LIMITED TO 15) ---
                          SectionHeader(
                            title: 'Trending Songs',
                            accentColor: const Color(0xFFFF3B30),
                            onSeeAll: () {
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
                            },
                          ),
                          const SizedBox(height: 12),
                          VerticalSongList(
                            songs: _filteredTrending,
                            visibleIndices: _visibleTrending,
                            onPlay: widget.onPlaySong,
                          ),
                          const SizedBox(height: 32),

                          // --- SECTION 3: RECENTLY PLAYED ---
                          SectionHeader(
                            title: 'Recently Played',
                            accentColor: const Color(0xFF00A8E1),
                            onSeeAll: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RecentlyPlayedScreen(
                                    onPlaySong: widget.onPlaySong,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          ValueListenableBuilder<List<Song>>(
                            valueListenable: RecentlyPlayedService.recentSongsNotifier,
                            builder: (context, recentSongs, child) {
                              // Filter recently played songs based on search query
                              final filteredRecentSongs = _query.isEmpty
                                  ? recentSongs
                                  : recentSongs.where((s) =>
                                      s.title.toLowerCase().contains(_query) ||
                                      s.artist.toLowerCase().contains(_query)).toList();

                              if (filteredRecentSongs.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 48,
                                          color: Colors.white.withValues(alpha: 0.3),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No recently played songs',
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

                              return VerticalSongList(
                                songs: filteredRecentSongs,
                                visibleIndices: _visibleRecent,
                                onPlay: widget.onPlaySong,
                              );
                            },
                          ),
                          const SizedBox(height: 32),

                          Consumer<PlaylistProvider>(
                            builder: (context, provider, _) {
                              // Filter playlists based on search query
                              final playlists = _query.isEmpty
                                  ? provider.playlists
                                  : provider.playlists.where((p) =>
                                  p.title.toLowerCase().contains(_query)).toList();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Playlist Header with Create Button
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Your Playlists',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: () => _showCreateDialog(context),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(20),
                                            child: BackdropFilter(
                                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: Colors.white12),
                                                ),
                                                child: Row(
                                                  children: const [
                                                    Icon(Icons.add, size: 16, color: Colors.white),
                                                    SizedBox(width: 4),
                                                    Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // Playlist List (Horizontal)
                                  if (playlists.isEmpty)
                                    _EmptyPlaylistState(onTap: () => _showCreateDialog(context))
                                  else
                                    SizedBox(
                                      height: 230, // Height for the card
                                      child: ListView.separated(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: playlists.length,
                                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                                        itemBuilder: (context, index) {
                                          final playlist = playlists[index];
                                          // Using the premium card style from your reference
                                          return _HomePlaylistCard(
                                            playlist: playlist,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PlaylistBody(
                                                    playlist: playlist,
                                                    onPlaySong: widget.onPlaySong,
                                                  ),
                                                ),
                                              );
                                            },
                                            onLongPress: () {
                                              showModalBottomSheet(
                                                context: context,
                                                backgroundColor: Colors.transparent,
                                                builder: (_) => _PlaylistOptionsSheet(playlist: playlist),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          // --- END PLAYLIST SECTION ---
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_loading)
            Positioned.fill(
              child: Container(
                color: kBackgroundColor,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _HomePlaylistCard extends StatelessWidget {
  final dynamic playlist;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HomePlaylistCard({
    required this.playlist,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Get cached songs from provider for cover image
    final playlistSongs = context.select<PlaylistProvider, List<Song>>(
      (provider) => provider.getPlaylistSongs(playlist.id),
    );

    final coverUrl = playlistSongs.isNotEmpty ? playlistSongs.first.coverUrl : null;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 140, // Fixed width matching the Album lists
        color: Colors.transparent, // Ensures touch target covers the whole area
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. The Square Art Container
            Container(
              height: 140,
              width: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                )
                    : _buildPlaceholder(),
              ),
            ),

            const SizedBox(height: 12),

            // 2. Title
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                playlist.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            const SizedBox(height: 4),

            // 3. Song Count (Subtitle)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '${playlist.songIds.length} songs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
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

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.queue_music_rounded,
          color: Colors.white.withValues(alpha: 0.2),
          size: 48,
        ),
      ),
    );
  }
}

class _EmptyPlaylistState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyPlaylistState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_add_rounded, size: 32, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(
              'No playlists yet. Tap to create.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePlaylistDialog extends StatelessWidget {
  final TextEditingController controller;
  const _CreatePlaylistDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create Playlist', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Playlist name',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, controller.text.trim()),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistOptionsSheet extends StatelessWidget {
  final dynamic playlist;
  const _PlaylistOptionsSheet({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: playlist.title);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Rename', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  final name = await showDialog<String>(
                    context: context,
                    builder: (_) => _CreatePlaylistDialog(controller: controller),
                  );
                  if (name != null && name.isNotEmpty && context.mounted) {
                    context.read<PlaylistProvider>().renamePlaylist(playlist.id, name);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  context.read<PlaylistProvider>().deletePlaylist(playlist.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
