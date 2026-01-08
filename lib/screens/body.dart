import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/components/navbar.dart';
import 'package:sangeet/screens/home/home_body.dart';
import 'package:sangeet/screens/library/library_body.dart';
import 'package:sangeet/screens/podcast/podcast_body.dart';
import 'package:sangeet/screens/search/search_body.dart';
import '../components/album_color.dart';
import '../models/song.dart';
import '../components/bottom_player.dart';

class Body extends StatefulWidget {
  static const routeName = '/body';
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  int _currentIndex = 0;
  Color _playerColor = Colors.black;
  Song? _currentSong;
  bool _isPlaying = false;
  int _previousIndex = 0;


  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(onPlaySong: _playSong),
      const search_body(),
      const PodcastsScreen(),
      const LibraryBody(),
    ];
  }

  void _onHorizontalSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity < -250 && _currentIndex < _pages.length - 1) {
      _onNavTap(_currentIndex + 1);
    } else if (velocity > 250 && _currentIndex > 0) {
      _onNavTap(_currentIndex - 1);
    }
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
  }

  void _playSong(Song song) async {
    setState(() {
      _currentSong = song;
      _isPlaying = true;
    });

    final color = await extractDominantColor(song.coverUrl);
    if (!mounted) return;

    setState(() => _playerColor = color);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: _onHorizontalSwipe,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 560),
              reverseDuration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                final isForward = _currentIndex > _previousIndex;

                final fade = Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
                  ),
                );

                final slide = Tween<Offset>(
                  begin: Offset(isForward ? 0.06 : -0.06, 0.02),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

                final scale = Tween<double>(
                  begin: 0.985,
                  end: 1.0,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  ),
                );

                final blur = Tween<double>(
                  begin: 8.0,
                  end: 0.0,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  ),
                );

                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    return FadeTransition(
                      opacity: fade,
                      child: SlideTransition(
                        position: slide,
                        child: ScaleTransition(
                          scale: scale,
                          child: ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: blur.value,
                                sigmaY: blur.value,
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_currentIndex),
                child: _pages[_currentIndex],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 1,
            child: SafeArea(
              top: false,
              child: BottomPlayer(
                currentSong: _currentSong,
                isPlaying: _isPlaying,
                onToggle: _togglePlay,
                onNext: () {  },
                onPrevious: () {  },
                backgroundColor: _playerColor,

              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SlidingBubbleNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
