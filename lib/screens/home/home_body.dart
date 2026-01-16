import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/dummy_data.dart';
import '../../models/song.dart';
import '../../models/playlist.dart';
import '../../services/remote_music_service.dart';
import 'components/banner_widget.dart';
import 'components/playlist_grid.dart';
import 'components/section_header.dart';
import 'components/song_list.dart';
import 'components/vertical_song_list.dart';
import 'package:sangeet/constants.dart';

class HomeScreen extends StatefulWidget {
  final void Function(Song) onPlaySong;

  const HomeScreen({super.key, required this.onPlaySong});

  static const routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>  with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late final RemoteMusicService _musicService;

  String _query = '';

  List<int> _visibleRecommended = [];
  List<int> _visibleRecent = [];

  Timer? _staggerTimer;
  double _headerOpacity = 0.0;

  bool _loading = true;

  List<Song> _recommended = [];
  List<Song> _recent = [];
  List<Song> _trending = [];
  late List<Playlist> _playlists = DummyData.playlists;

  @override
  void initState() {
    super.initState();
    // Clean base URL without query parameters
    _musicService = RemoteMusicService('https://jiosaavn-api.acefaroff.workers.dev/api');
    _searchCtrl.addListener(_onSearchChanged);
    _scrollCtrl.addListener(_onScroll);
    _loadHomeData();
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final op = (_scrollCtrl.offset / 130).clamp(0.0, 1.0);
    if (op != _headerOpacity) {
      setState(() => _headerOpacity = op);
    }
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

      List<Song> recommendedSongs = [];
      if (trendingSongs.isNotEmpty) {
        recommendedSongs =
        await _musicService.getSongSuggestions(trendingSongs.first.id);
      }

      setState(() {
        _trending = trendingSongs;
        _recommended =
        recommendedSongs.isNotEmpty ? recommendedSongs : trendingSongs;
        _recent = trendingSongs;
        _playlists = DummyData.playlists;
        _loading = false;
      });

      _runStagger();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _runStagger() {
    _staggerTimer?.cancel();
    _visibleRecommended = [];
    _visibleRecent = [];

    const delay = 60;
    int offset = 0;

    for (int i = 0; i < _filteredRecommended.length; i++) {
      Timer(Duration(milliseconds: delay * offset++), () {
        if (mounted) setState(() => _visibleRecommended.add(i));
      });
    }

    for (int i = 0; i < _filteredRecent.length; i++) {
      Timer(Duration(milliseconds: delay * offset++), () {
        if (mounted) setState(() => _visibleRecent.add(i));
      });
    }
  }

  List<Song> get _filteredRecommended {
    if (_query.isEmpty) return _recommended;
    return _recommended.where((s) =>
    s.title.toLowerCase().contains(_query) ||
        s.artist.toLowerCase().contains(_query)
    ).toList();
  }

  List<Song> get _filteredRecent {
    if (_query.isEmpty) return _recent;
    return _recent.where((s) =>
    s.title.toLowerCase().contains(_query) ||
        s.artist.toLowerCase().contains(_query)
    ).toList();
  }

  List<Playlist> get _filteredPlaylists {
    if (_query.isEmpty) return _playlists;
    return _playlists
        .where((p) => p.title.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomInset = MediaQuery.of(context).padding.bottom + 84;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            color: kPrimaryColor,
            backgroundColor: kSurfaceColor,
            onRefresh: _onRefresh,
            child: CustomScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                    ),
                    child: SizedBox(
                      height: 320,
                      child: _trending.isNotEmpty
                          ? BannerWidget(
                        trendingSongs: _trending,
                        searchController: _searchCtrl,
                        surfaceColor: kSurfaceColor,
                        softWhite: kPrimaryColor,
                        onPlaySong: widget.onPlaySong,
                      )
                          : const SizedBox(height: 320),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      SectionHeader(title: 'Made for You'),
                      const SizedBox(height: 12),
                      HorizontalSongList(
                        songs: _filteredRecommended,
                        visibleIndices: _visibleRecommended,
                        onPlay: widget.onPlaySong,
                      ),
                      SectionHeader(title: 'Recently Played'),
                      const SizedBox(height: 12),
                      VerticalSongList(
                        songs: _filteredRecent,
                        visibleIndices: _visibleRecent,
                        onPlay: widget.onPlaySong,
                      ),
                      const SizedBox(height: 22),

                      SectionHeader(title: 'Your Playlists', onSeeAll: () {}),
                      const SizedBox(height: 12),
                      PlaylistGrid(
                        playlists: _filteredPlaylists,
                        visibleIndices: List.generate(
                          _filteredPlaylists.length,
                              (i) => i,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _headerOpacity,
              duration: const Duration(milliseconds: 180),
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kBackgroundColor.withOpacity(0.95),
                      kBackgroundColor.withOpacity(0.65),
                      kBackgroundColor.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          if (_loading)
            Positioned.fill(
              child: Container(
                color: kBackgroundColor,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
  @override
  bool get wantKeepAlive => true;
}