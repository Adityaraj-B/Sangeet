import 'dart:async';
import 'package:flutter/material.dart';
import '../../components/navbar.dart';
import '../../data/dummy_data.dart';
import '../../models/song.dart';
import '../../models/playlist.dart';
import '../library/library_body.dart';
import 'components/banner_widget.dart';
import '../../components/bottom_player.dart';
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


class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String _query = '';

  List<int> _visibleRecommended = [];
  List<int> _visibleRecent = [];
  List<int> _visiblePlaylists = [];

  Timer? _staggerTimer;
  double _headerOpacity = 0.0;

  @override
  void initState() {
    super.initState();

    _searchCtrl.addListener(_onSearchChanged);
    _scrollCtrl.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) => _runStagger());
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

  void _runStagger() {
    _staggerTimer?.cancel();
    _visibleRecommended = [];
    _visibleRecent = [];
    _visiblePlaylists = [];

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

    for (int i = 0; i < _filteredPlaylists.length; i++) {
      Timer(Duration(milliseconds: delay * offset++), () {
        if (mounted) setState(() => _visiblePlaylists.add(i));
      });
    }
  }

  List<Song> get _filteredRecommended {
    if (_query.isEmpty) return DummyData.recommendedSongs;
    return DummyData.recommendedSongs.where((s) =>
    s.title.toLowerCase().contains(_query) ||
        s.artist.toLowerCase().contains(_query)).toList();
  }

  List<Song> get _filteredRecent {
    if (_query.isEmpty) return DummyData.recentSongs;
    return DummyData.recentSongs.where((s) =>
    s.title.toLowerCase().contains(_query) ||
        s.artist.toLowerCase().contains(_query)).toList();
  }

  List<Playlist> get _filteredPlaylists {
    if (_query.isEmpty) return DummyData.playlists;
    return DummyData.playlists
        .where((p) => p.title.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 84;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: BannerWidget(
                      song: DummyData.trendingSongs.first,
                      searchController: _searchCtrl,
                      surfaceColor: kSurfaceColor,
                      softWhite: kPrimaryColor,
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
                      const SizedBox(height: 22),

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
                        visibleIndices: _visiblePlaylists,
                      ),
                    ]),
                  ),
                ),
              ],
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
          ],
        ),
      ),
    );
  }
}
