import 'package:flutter/material.dart';
import 'package:sangeet/components/navbar.dart';
import 'package:sangeet/screens/home/home_body.dart';
import 'package:sangeet/screens/library/library_body.dart';
import 'package:sangeet/screens/player/player_body.dart';
import 'package:sangeet/screens/podcast/podcast_body.dart';
import 'package:sangeet/screens/search/components/search_screen.dart';
import '../components/album_color.dart';
import '../components/playable.dart';
import '../models/podcasts.dart';
import '../models/song.dart';
import '../components/bottom_player.dart';
import '../repositories/search_repo.dart';
import '../services/audio_player_service.dart';

class Body extends StatefulWidget {
  static const routeName = '/body';
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  PlaybackItem? _currentItem;
  bool _showMiniPlayer = false;
  Color _playerColor = Colors.black;
  late final List<Widget> _pages;
  final AudioPlayerService _audioService = AudioPlayerService();

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(onPlaySong: _openPlayerForSong),
      SearchScreen(
        repository: SearchRepository(),
        onPlay: _openPlayerForSong,
      ),
      PodcastsScreen(onPlayPodcast: _openPlayerForPodcast),
      LibraryBody(onPlaySong: _openPlayerForSong),
    ];
  }

  Future<void> _openPlayerForSong(Song song) async {
    // Don't play here - let PlayerScreen handle it
    await _openPlayer(
      PlaybackItem(type: PlaybackType.song, data: song),
      song.coverUrl,
    );
  }

  Future<void> _openPlayerForPodcast(Podcast podcast) async {
    await _openPlayer(
      PlaybackItem(type: PlaybackType.podcast, data: podcast),
      podcast.imageUrl,
    );
  }

  Future<void> _openPlayer(PlaybackItem item, String imageUrl) async {
    // Extract color first
    final color = await extractDominantColor(imageUrl);

    if (!mounted) return;

    // Update state
    setState(() {
      _currentItem = item;
      _playerColor = color;
      _showMiniPlayer = false;
    });

    // Navigate to player
    final collapsed = await Navigator.of(context).push<bool>(
      _ExpandingPlayerRoute(
        page: PlayerScreen(
          item: item,
          onCollapse: () => Navigator.pop(context, true),
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _showMiniPlayer = collapsed == true;
      });
    }
  }

  void _reopenPlayer() {
    if (_currentItem == null) return;

    if (_currentItem!.type == PlaybackType.song) {
      _reopenPlayerForSong(_currentItem!.data as Song);
    } else if (_currentItem!.type == PlaybackType.podcast) {
      _reopenPlayerForPodcast(_currentItem!.data as Podcast);
    }
  }

  Future<void> _reopenPlayerForSong(Song song) async {
    setState(() => _showMiniPlayer = false);

    final collapsed = await Navigator.of(context).push<bool>(
      _ExpandingPlayerRoute(
        page: PlayerScreen(
          item: PlaybackItem(type: PlaybackType.song, data: song),
          onCollapse: () => Navigator.pop(context, true),
        ),
      ),
    );

    if (mounted) {
      setState(() => _showMiniPlayer = collapsed == true);
    }
  }

  Future<void> _reopenPlayerForPodcast(Podcast podcast) async {
    setState(() => _showMiniPlayer = false);

    final collapsed = await Navigator.of(context).push<bool>(
      _ExpandingPlayerRoute(
        page: PlayerScreen(
          item: PlaybackItem(type: PlaybackType.podcast, data: podcast),
          onCollapse: () => Navigator.pop(context, true),
        ),
      ),
    );

    if (mounted) {
      setState(() => _showMiniPlayer = collapsed == true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          if (_showMiniPlayer && _currentItem != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 1,
              child: SafeArea(
                top: false,
                child: GestureDetector(
                  onTap: _reopenPlayer,
                  child: BottomPlayer(
                    currentItem: _currentItem,
                    backgroundColor: _playerColor,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SlidingBubbleNavBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() {
            _previousIndex = _currentIndex;
            _currentIndex = i;
          });
        },
      ),
    );
  }
}

class _ExpandingPlayerRoute<T> extends PageRoute<T> {
  final Widget page;

  _ExpandingPlayerRoute({required this.page});

  @override
  Color? get barrierColor => const Color(0x8A000000);

  @override
  String? get barrierLabel => null;

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 450);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 400);

  @override
  Widget buildPage(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      ) {
    return page;
  }

  @override
  Widget buildTransitions(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curve);

    final scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(curve);

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    return SlideTransition(
      position: slideAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: FadeTransition(
          opacity: fadeAnimation,
          child: child,
        ),
      ),
    );
  }
}
