import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sangeet/components/navbar.dart';
import 'package:sangeet/screens/home/home_body.dart';
import 'package:sangeet/screens/library/library_body.dart';
import 'package:sangeet/screens/player/player_body.dart';
import 'package:sangeet/screens/podcast/podcast_body.dart';
import 'package:sangeet/screens/search/search_screen.dart';
import '../components/album_color.dart';
import '../components/bottom_player_container.dart';
import '../components/playable.dart';
import '../models/podcasts.dart';
import '../models/song.dart';
import 'package:sangeet/repositories/search_repo.dart';
import '../services/audio_player_service.dart';
import '../services/playlist_provider.dart';

class Body extends StatefulWidget {
  static const routeName = '/body';
  const Body({super.key});

  @override
  State<Body> createState() => BodyState();
}

class BodyState extends State<Body> with TickerProviderStateMixin {
  static BodyState? _instance;
  static BodyState? get instance => _instance;

  int _currentIndex = 0;
  PlaybackItem? _currentItem;
  bool _showMiniPlayer = false;
  Color _playerColor = Colors.black;
  late final List<Widget> _pages;
  final AudioPlayerService _audioService = AudioPlayerService();
  bool _isQueueListenerAttached = false;
  bool _isPlayerRouteOpen = false;

  @override
  void initState() {
    super.initState();
    _instance = this;
    _pages = [
      HomeScreen(onPlaySong: _openPlayerForSong),
      SearchScreen(
        repository: SearchRepository(),
        onPlay: _openPlayerForSong,
      ),
      PodcastsScreen(onPlayPodcast: _openPlayerForPodcast),
      LibraryBody(onPlaySong: _openPlayerForSong),
    ];

    // Initialize PlaylistProvider after user is logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PlaylistProvider>().initialize();
      }
    });

    // Keep mini player state in sync with whatever is actually playing.
    _audioService.queue.addListener(_syncFromQueue);
    _isQueueListenerAttached = true;

    // Trigger initial sync
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromQueue());
  }

  void _syncFromQueue() {
    if (!mounted) return;
    final song = _audioService.currentSong;
    if (song == null) return;

    final currentSongId = _currentItem?.type == PlaybackType.song
        ? (_currentItem?.data as Song?)?.id
        : null;

    // Update current item if song changed
    if (currentSongId != song.id) {
      setState(() {
        _currentItem = PlaybackItem(type: PlaybackType.song, data: song);
      });

      // Update color async
      extractDominantColor(song.coverUrl).then((c) {
        if (!mounted) return;
        setState(() => _playerColor = c);
      });
    }

    // Show mini player only if player route is not open
    if (!_isPlayerRouteOpen && !_showMiniPlayer) {
      setState(() => _showMiniPlayer = true);
    }
  }

  @override
  void dispose() {
    _instance = null;
    if (_isQueueListenerAttached) {
      _audioService.queue.removeListener(_syncFromQueue);
    }
    super.dispose();
  }

  /// Opens the PlayerScreen for a song and starts playback.
  /// Called from song lists, search results, etc.
  Future<void> _openPlayerForSong(Song song) async {
    if (!mounted) return;

    // Hide mini player, show full player
    setState(() {
      _currentItem = PlaybackItem(type: PlaybackType.song, data: song);
      _showMiniPlayer = false;
    });

    // Update color async
    unawaited(extractDominantColor(song.coverUrl).then((c) {
      if (!mounted) return;
      setState(() => _playerColor = c);
    }));

    // Start playback immediately (don't wait)
    unawaited(_audioService.playSong(song));

    // Push player route
    await _pushPlayerRoute();
  }

  /// Opens the PlayerScreen for the currently playing song.
  /// Called when tapping the mini player.
  Future<void> openPlayerForCurrentSong() async {
    final song = _audioService.currentSong;
    if (song == null || !mounted) return;

    setState(() {
      _currentItem = PlaybackItem(type: PlaybackType.song, data: song);
      _showMiniPlayer = false;
    });

    await _pushPlayerRoute();
  }

  Future<void> _pushPlayerRoute() async {
    if (_isPlayerRouteOpen || !mounted) return;
    _isPlayerRouteOpen = true;

    await Navigator.of(context).push<bool>(
      _ExpandingPlayerRoute(
        page: PlayerScreen(
          onCollapse: () => Navigator.pop(context, true),
        ),
      ),
    );

    _isPlayerRouteOpen = false;
    if (mounted) {
      setState(() => _showMiniPlayer = _audioService.currentSong != null);
    }
  }

  Future<void> _openPlayerForPodcast(Podcast podcast) async {
    await _openPlayer(
      PlaybackItem(type: PlaybackType.podcast, data: podcast),
      podcast.imageUrl,
    );
  }

  Future<void> _openPlayer(PlaybackItem item, String imageUrl) async {
    final color = await extractDominantColor(imageUrl);

    if (!mounted) return;

    setState(() {
      _currentItem = item;
      _playerColor = color;
      _showMiniPlayer = false;
    });

    if (_isPlayerRouteOpen) return;
    _isPlayerRouteOpen = true;

    await Navigator.of(context).push<bool>(
      _ExpandingPlayerRoute(
        page: PlayerScreen(
          onCollapse: () => Navigator.pop(context, true),
        ),
      ),
    );

    _isPlayerRouteOpen = false;
    if (mounted) {
      setState(() => _showMiniPlayer = true);
    }
  }

  void _onNavBarTap(int index) {
    if (_currentIndex == index) return;

    // Show podcast coming soon dialog when tapping podcast tab (index 2)
    if (index == 2) {
      _showPodcastComingSoonDialog();
      return; // Don't switch to podcast tab - stays on current index
    }

    setState(() => _currentIndex = index);
  }

  void _showPodcastComingSoonDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _PodcastComingSoonDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // iOS-style cross-fade between pages
          ..._pages.asMap().entries.map((entry) {
            final index = entry.key;
            final page = entry.value;

            // Don't render podcast screen at all
            if (index == 2) return const SizedBox.shrink();

            return AnimatedOpacity(
              opacity: _currentIndex == index ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: IgnorePointer(
                ignoring: _currentIndex != index,
                child: page,
              ),
            );
          }),

          // Mini player
          if (_showMiniPlayer && _currentItem != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 1,
              child: SafeArea(
                top: false,
                child: GestureDetector(
                  onTap: openPlayerForCurrentSong,
                  child: BottomPlayerContainer(
                    backgroundColor: _playerColor,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SlidingBubbleNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavBarTap,
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

class _PodcastComingSoonDialog extends StatelessWidget {
  const _PodcastComingSoonDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.14),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.6,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFD700).withValues(alpha: 0.3),
                        const Color(0xFFFFD700).withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.podcasts_rounded,
                    size: 40,
                    color: Color(0xFFFFD700),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Podcast feature is currently under development. Stay tuned for exciting updates!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
