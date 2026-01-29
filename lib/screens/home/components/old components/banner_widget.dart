import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../models/song.dart';

class BannerWidget extends StatefulWidget {
  final List<Song> trendingSongs;
  final TextEditingController searchController;
  final Color surfaceColor;
  final Color softWhite;
  final void Function(Song)? onPlaySong;

  const BannerWidget({
    super.key,
    required this.trendingSongs,
    required this.searchController,
    required this.surfaceColor,
    required this.softWhite,
    this.onPlaySong,
  });

  @override
  State<BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<BannerWidget> {
  static const _maxItems = 4;
  static const _autoScrollInterval = Duration(seconds: 5);
  static const _scrollDuration = Duration(milliseconds: 800);
  static const _resetDuration = Duration(milliseconds: 600);

  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  List<Song> get _displaySongs => widget.trendingSongs.take(_maxItems).toList();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!_pageController.hasClients || _displaySongs.length <= 1) return;

      if (_currentPage < _displaySongs.length - 1) {
        _pageController.nextPage(
          duration: _scrollDuration,
          curve: Curves.fastOutSlowIn,
        );
        _currentPage++;
      } else {
        _pageController.animateToPage(
          0,
          duration: _resetDuration,
          curve: Curves.easeOutQuart,
        );
        _currentPage = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_displaySongs.isEmpty) {
      return _FallbackBanner(
        surfaceColor: widget.surfaceColor,
        softWhite: widget.softWhite,
      );
    }

    return SizedBox(
      height: 240,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => _currentPage = index,
        itemCount: _displaySongs.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 40,
                  spreadRadius: 4,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _BannerItem(
                song: _displaySongs[index],
                surfaceColor: widget.surfaceColor,
                softWhite: widget.softWhite,
                onPlay: () {
                  widget.onPlaySong?.call(_displaySongs[index]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BannerItem extends StatefulWidget {
  final Song song;
  final Color surfaceColor;
  final Color softWhite;
  final VoidCallback? onPlay;

  const _BannerItem({
    required this.song,
    required this.surfaceColor,
    required this.softWhite,
    required this.onPlay,
  });

  @override
  State<_BannerItem> createState() => _BannerItemState();
}

class _BannerItemState extends State<_BannerItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (widget.onPlay != null) {
          widget.onPlay!();
        }
      },
      onTapDown: (_) {
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(),
            _buildGradient(),
            _buildContent(),
            _buildPlayButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (widget.song.coverUrl.isEmpty) {
      return _FallbackBanner(
        surfaceColor: widget.surfaceColor,
        softWhite: widget.softWhite,
      );
    }

    return Image.network(
      widget.song.coverUrl,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSync) {
        if (wasSync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (_, __, ___) => _FallbackBanner(
        surfaceColor: widget.surfaceColor,
        softWhite: widget.softWhite,
      ),
    );
  }

  Widget _buildGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 0.8, 1.0],
          colors: [
            Colors.black.withValues(alpha: 0.1),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.6),
            Colors.black.withValues(alpha: 0.9),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Positioned(
      left: 20,
      right: 90,
      bottom: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _GlassBadge(text: 'Trending'),
          const SizedBox(height: 12),
          Text(
            widget.song.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: Colors.black,
                  blurRadius: 16,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 0.2,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  blurRadius: 8,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return Positioned(
      right: 20,
      bottom: 24,
      child: _GlassPlayButton(onTap: () => widget.onPlay?.call()),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  final String text;
  const _GlassBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30), // Pill shape for liquid feel
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            // Liquid Gradient
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
                  border: Border.all(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFF453A), // Slightly brighter for contrast
                  size: 12,
                ),
              ),
              const SizedBox(width: 8),
              // Text
              Text(
                text.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPlayButton extends StatefulWidget {
  final VoidCallback onTap;

  const _GlassPlayButton({required this.onTap});

  @override
  State<_GlassPlayButton> createState() => _GlassPlayButtonState();
}

class _GlassPlayButtonState extends State<_GlassPlayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic, // Smoother curve
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Heavier blur
            child: Container(
              width: 50, // Slightly larger touch target
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Liquid Gradient
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Subtle inner glow
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.play_arrow_rounded,
                    size: 34,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  final Color surfaceColor;
  final Color softWhite;

  const _FallbackBanner({
    required this.surfaceColor,
    required this.softWhite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: surfaceColor,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 64,
          color: softWhite.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}