import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../models/song.dart';

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
    // viewportFraction < 1 allows the next card to peek through slightly
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
      height: 240, // Slightly more compact and sleek
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => _currentPage = index,
        itemCount: _displaySongs.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          // No complex transforms, just clean spacing
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha :0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _BannerItem(
                song: _displaySongs[index],
                surfaceColor: widget.surfaceColor,
                softWhite: widget.softWhite,
                onPlay: () => widget.onPlaySong?.call(_displaySongs[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final Song song;
  final Color surfaceColor;
  final Color softWhite;
  final VoidCallback onPlay;

  const _BannerItem({
    required this.song,
    required this.surfaceColor,
    required this.softWhite,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          _buildGradient(),
          _buildContent(),
          _buildPlayButton(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (song.coverUrl.isEmpty) {
      return _FallbackBanner(
        surfaceColor: surfaceColor,
        softWhite: softWhite,
      );
    }

    return Image.network(
      song.coverUrl,
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
        surfaceColor: surfaceColor,
        softWhite: softWhite,
      ),
    );
  }

  Widget _buildGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.5, 1.0],
          colors: [
            Colors.black.withValues(alpha :0.1),
            Colors.transparent,
            Colors.black.withValues(alpha :0.9),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Positioned(
      left: 18,
      right: 80,
      bottom: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _GlassBadge(text: 'Trending'),
          const SizedBox(height: 10),
          Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha :0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return Positioned(
      right: 18,
      bottom: 20,
      child: _GlassPlayButton(onTap: onPlay),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  final String text;
  const _GlassBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha :0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha :0.2),
                width: 0.5
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 14),
              const SizedBox(width: 4),
              Text(
                text.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPlayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GlassPlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha :0.2),
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha :0.3),
                      width: 1
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha :0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 28,
                color: Colors.white,
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
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 60,
          color: softWhite.withValues(alpha :0.1),
        ),
      ),
    );
  }
}