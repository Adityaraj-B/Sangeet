import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/song.dart';

class BannerWidget extends StatefulWidget {
  final List<Song> trendingSongs;
  final TextEditingController searchController;
  final Color surfaceColor;
  final Color softWhite;
  final void Function(Song)? onPlaySong;

  const BannerWidget({
    Key? key,
    required this.trendingSongs,
    required this.searchController,
    required this.surfaceColor,
    required this.softWhite,
    this.onPlaySong,
  }) : super(key: key);

  @override
  State<BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<BannerWidget> {
  final PageController _pageController = PageController(viewportFraction: 1);
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();

    _autoScrollTimer = Timer.periodic(
      const Duration(seconds: 4),
          (_) {
        if (!_pageController.hasClients) return;

        final total = widget.trendingSongs.take(4).length;
        if (total <= 1) return;

        if (_currentPage < total - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic,
          );
        } else {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displaySongs = widget.trendingSongs.take(4).toList();

    if (displaySongs.isEmpty) {
      return _buildEmptyBanner();
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            _currentPage = index;
            setState(() {});
          },
          itemCount: displaySongs.length,
          itemBuilder: (context, index) {
            return AnimatedBuilder(
              animation: _pageController,
              child: _buildBannerItem(displaySongs[index]),
              builder: (context, child) {
                double page = 0;
                if (_pageController.hasClients &&
                    _pageController.position.haveDimensions) {
                  page = _pageController.page ?? _currentPage.toDouble();
                }

                final delta = (page - index).clamp(-1.0, 1.0);

                return Transform.translate(
                  offset: Offset(delta * -40, 0),
                  child: Transform.scale(
                    scale: 1 - (delta.abs() * 0.04),
                    child: child,
                  ),
                );
              },
            );

          },
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
        ),
      ],

    );
  }

  Widget _buildBannerItem(Song song) {
    return GestureDetector(
      onTap: () => widget.onPlaySong?.call(song),
      child: Stack(
        fit: StackFit.expand,
        children: [
          song.coverUrl.isNotEmpty
              ? Image.network(
            song.coverUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackBg(),
          )
              : _fallbackBg(),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.45),
                  Colors.transparent,
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
          ),

          Positioned(
            left: 22,
            right: 96,
            bottom: 32,
            child: _buildBannerContent(song),
          ),

          Positioned(
            right: 22,
            bottom: 30,
            child: _PlayButton(
              onTap: () => widget.onPlaySong?.call(song),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerContent(Song song) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Colors.redAccent,
                Colors.deepOrangeAccent,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text(
            'Trending',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),

        const SizedBox(height: 14),

        Text(
          song.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.12,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.75),
            letterSpacing: 0.2,
          ),
        ),

        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildPageIndicators(int count) {
    return Row(
      children: List.generate(count, (index) {
        final active = _currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 6),
          height: 5,
          width: active ? 22 : 6,
          decoration: BoxDecoration(
            color: active
                ? Colors.white
                : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }


  Widget _fallbackBg() {
    return Container(
      color: widget.surfaceColor,
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 80,
          color: widget.softWhite.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildEmptyBanner() {
    return Container(
      color: widget.surfaceColor,
      child: Center(
        child: Icon(
          Icons.music_note,
          size: 80,
          color: widget.softWhite.withOpacity(0.3),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Material(
        color: Colors.white.withOpacity(0.15),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 34,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
