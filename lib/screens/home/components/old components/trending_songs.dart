import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../../../../components/bottom_player_container.dart';
import '../../../../constants.dart';
import '../../../../models/song.dart';
import '../../../../components/Song_options.dart';

class TrendingSongsPage extends StatefulWidget {
  final List<Song> trendingSongs;
  final void Function(Song) onPlay;
  final Color surfaceColor;
  final Color softWhite;

  const TrendingSongsPage({
    super.key,
    required this.trendingSongs,
    required this.onPlay,
    required this.surfaceColor,
    required this.softWhite,
  });

  @override
  State<TrendingSongsPage> createState() => _TrendingSongsPageState();
}

class _TrendingSongsPageState extends State<TrendingSongsPage>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _headerAnimationController;
  final List<int> _visibleIndices = [];
  bool _showBackButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animateItems();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    // Show back button earlier for better UX, but animate smoothly
    final shouldShow = offset > 80;
    if (shouldShow != _showBackButton) {
      setState(() => _showBackButton = shouldShow);
      if (shouldShow) {
        _headerAnimationController.forward();
      } else {
        _headerAnimationController.reverse();
      }
    }
  }

  void _animateItems() {
    for (int i = 0; i < widget.trendingSongs.length; i++) {
      // Staggered animation for a cascading effect
      Future.delayed(Duration(milliseconds: 40 * i), () {
        if (mounted) {
          setState(() => _visibleIndices.add(i));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildAmbientBackground(),
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: _buildSongsList(),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
          _buildFloatingBackButton(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 5,
            child: SafeArea(
              top: false,
              child: BottomPlayerContainer(
                backgroundColor: kBackgroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBackground() {
    return Stack(
      children: [
        Container(color: const Color(0xFF050505)),
        // Subtle ambient glow top-left
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBackgroundColor.withValues(alpha: 0.4),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 320, // Taller header for cinematic feel
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _buildHeroImage(),
            _buildHeroGradient(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    if (widget.trendingSongs.isEmpty) return const SizedBox();

    return Image.network(
      widget.trendingSongs.first.coverUrl,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSync) {
        if (wasSync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          child: child,
        );
      },
      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF111111)),
    );
  }

  Widget _buildHeroGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.3, 0.7, 1.0],
          colors: [
            Colors.black.withValues(alpha: 0.3),
            Colors.transparent,
            const Color(0xFF050505).withValues(alpha: 0.8),
            const Color(0xFF050505),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.show_chart_rounded,
                    color: Color(0xFFFF4D4D), size: 16),
                const SizedBox(width: 8),
                Text(
                  'TRENDING NOW',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Large Editorial Title
          const Text(
            'Top Songs',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          // Subtle Subtitle
          Text(
            'Updated daily · The most played tracks right now',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          final song = widget.trendingSongs[index];
          final visible = _visibleIndices.contains(index);
          final rank = index + 1;

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            opacity: visible ? 1 : 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              offset: visible ? Offset.zero : const Offset(0.05, 0),
              child: _TrendingSongCard(
                song: song,
                rank: rank,
                onPlay: () => widget.onPlay(song),
              ),
            ),
          );
        },
        childCount: widget.trendingSongs.length,
      ),
    );
  }

  Widget _buildFloatingBackButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      child: AnimatedOpacity(
        opacity: _showBackButton ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingSongCard extends StatefulWidget {
  final Song song;
  final int rank;
  final VoidCallback onPlay;

  const _TrendingSongCard({
    required this.song,
    required this.rank,
    required this.onPlay,
  });

  @override
  State<_TrendingSongCard> createState() => _TrendingSongCardState();
}

class _TrendingSongCardState extends State<_TrendingSongCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Scale animation for press effect
    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          // Very subtle surface color
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withValues(alpha: 0.05),
            highlightColor: Colors.transparent,
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.onPlay,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildRank(),
                  const SizedBox(width: 16),
                  _buildArt(),
                  const SizedBox(width: 16),
                  Expanded(child: _buildInfo()),
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRank() {
    final rank = widget.rank;
    // Dynamic color based on rank
    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
    } else if (rank == 2) {
      rankColor = const Color(0xFFE0E0E0);
    }
    else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
    }
    else {
      rankColor = Colors.white.withValues(alpha: 0.5);
    }

    return SizedBox(
      width: 24,
      child: Text(
        '$rank',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: rankColor,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildArt() {
    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          widget.song.coverUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[900],
            child: const Icon(Icons.music_note, color: Colors.white24),
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
          widget.song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play Button (Icon only, minimalist)
        // IconButton(
        //   onPressed: widget.onPlay,
        //   icon: Icon(
        //     Icons.play_circle_fill_rounded,
        //     color: Colors.white.withValues(alpha: 0.9),
        //     size: 32,
        //   ),
        // ),
        IconButton(
          icon: Icon(
            Icons.more_horiz_rounded,
            color: Colors.white.withValues(alpha: 0.5),
            size: 20,
          ),
          onPressed: () {
            SongOptionsSheet.show(
              context,
              widget.song,
              onPlay: widget.onPlay,
            );
          },
        ),
      ],
    );
  }
}