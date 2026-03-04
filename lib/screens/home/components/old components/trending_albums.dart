import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../../models/album.dart';
import '../../../../models/song.dart';
import '../../../../constants.dart';
import '../../../albums/albums_screen.dart';
import '../../../../services/remote_music_service.dart';

class TrendingAlbumsPage extends StatefulWidget {
  final List<Album> trendingAlbums;
  final RemoteMusicService musicService;
  final void Function(Song) onPlaySong;

  const TrendingAlbumsPage({
    super.key,
    required this.trendingAlbums,
    required this.musicService,
    required this.onPlaySong,
  });

  @override
  State<TrendingAlbumsPage> createState() => _TrendingAlbumsPageState();
}

class _TrendingAlbumsPageState extends State<TrendingAlbumsPage>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _headerAnimationController;
  final List<int> _visibleIndices = [];
  bool _showBackButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateAlbumsIn();
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final shouldShow = offset > 80;
    if (shouldShow != _showBackButton) {
      setState(() => _showBackButton = shouldShow);
    }

    final opacity = (offset / 180).clamp(0.0, 1.0);
    _headerAnimationController.value = opacity;
  }

  Future<void> _animateAlbumsIn() async {
    for (int i = 0; i < widget.trendingAlbums.length; i++) {
      await Future.delayed(const Duration(milliseconds: 40));
      if (mounted) {
        setState(() => _visibleIndices.add(i));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  void _navigateToAlbum(Album album) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumScreen(
          album: album,
          musicService: widget.musicService,
          onPlaySong: widget.onPlaySong,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildMeshBackground(),
          _buildContent(),
          _buildHeader(),
        ],
      ),
    );
  }

  Widget _buildMeshBackground() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kAccentColor.withValues(alpha: 0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildHero(),
        _buildAlbumsList(),
      ],
    );
  }

  Widget _buildHero() {
    return SliverToBoxAdapter(
      child: Container(
        height: 350,
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kAccentColor.withValues(alpha: 0.2),
                    kAccentColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: kAccentColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome,
                      color: kAccentColor, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'CURATED SELECTION',
                    style: TextStyle(
                      color: kAccentColor.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Trending\nAlbums',
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -2.0,
                height: 0.9,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    color: kAccentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${widget.trendingAlbums.length} Collections today',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumsList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final album = widget.trendingAlbums[index];
            final isVisible = _visibleIndices.contains(index);

            return AnimatedOpacity(
              opacity: isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: AnimatedSlide(
                offset: isVisible ? Offset.zero : const Offset(0, 0.05),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutQuart,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AlbumTile(
                    album: album,
                    rank: index + 1,
                    onTap: () => _navigateToAlbum(album),
                  ),
                ),
              ),
            );
          },
          childCount: widget.trendingAlbums.length,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 30 * _headerAnimationController.value,
            sigmaY: 30 * _headerAnimationController.value,
          ),
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFF090909).withValues(
                alpha: 0.85 * _headerAnimationController.value,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildBackButton(),
                    const SizedBox(width: 20),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: _headerAnimationController.value,
                        duration: const Duration(milliseconds: 300),
                        child: const Text(
                          'Trending',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 44,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final Album album;
  final int rank;
  final VoidCallback onTap;

  const _AlbumTile({
    required this.album,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTop3 = rank <= 3;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          highlightColor: kAccentColor.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _buildRankBadge(isTop3),
                const SizedBox(width: 18),
                _buildCover(),
                const SizedBox(width: 16),
                Expanded(child: _buildInfo()),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white24,
                  size: 14,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRankBadge(bool isTop3) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: isTop3
          ? BoxDecoration(
        color: kAccentColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      )
          : null,
      child: Text(
        rank.toString(),
        style: TextStyle(
          color: isTop3 ? kAccentColor : Colors.white24,
          fontSize: 14,
          fontWeight: isTop3 ? FontWeight.w900 : FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildCover() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          album.coverUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF1A1A1A),
            child: const Icon(Icons.album_rounded, color: Colors.white10),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          album.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          album.artist.toUpperCase(),
          maxLines: 1,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}