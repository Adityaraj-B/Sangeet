import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../services/lyrics_service.dart';

class LyricsView extends StatefulWidget {
  final String? artist;
  final String? track;
  final Stream<Duration>? positionStream;

  const LyricsView({
    super.key,
    this.artist,
    this.track,
    this.positionStream,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final LyricsService _lyricsService = LyricsService();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};

  List<LyricLine> _lyrics = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _currentLineIndex = -1;
  StreamSubscription<Duration>? _positionSubscription;

  // Estimated item height for scroll calculations
  static const double _itemHeight = 52.0; // approximate height per lyric line
  static const double _verticalPadding = 120.0;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
    _subscribeToPositionStream();
  }

  @override
  void didUpdateWidget(LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artist != widget.artist || oldWidget.track != widget.track) {
      _fetchLyrics();
    }
    // Re-subscribe if stream changed
    if (oldWidget.positionStream != widget.positionStream) {
      _subscribeToPositionStream();
    }
  }

  void _subscribeToPositionStream() {
    _positionSubscription?.cancel();
    _positionSubscription = widget.positionStream?.listen((position) {
      if (!mounted || _lyrics.isEmpty) return;

      final newIndex = _getCurrentLineIndex(position);
      if (newIndex != _currentLineIndex) {
        _updateCurrentLine(newIndex);
      }
    });
  }

  Future<void> _fetchLyrics() async {
    if (widget.artist == null || widget.track == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _currentLineIndex = -1;
      _lineKeys.clear();
    });

    try {
      final lyrics = await _lyricsService.fetchLyrics(
        widget.artist!,
        widget.track!,
      );
      if (mounted) {
        setState(() {
          _lyrics = lyrics;
          _isLoading = false;
          _hasError = lyrics.isEmpty;
          for (int i = 0; i < lyrics.length; i++) {
            _lineKeys[i] = GlobalKey();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  int _getCurrentLineIndex(Duration position) {
    if (_lyrics.isEmpty) return -1;

    for (int i = _lyrics.length - 1; i >= 0; i--) {
      if (position >= _lyrics[i].timestamp) {
        return i;
      }
    }
    return -1;
  }

  void _updateCurrentLine(int newIndex) {
    if (newIndex == _currentLineIndex) return;

    final previousIndex = _currentLineIndex;
    setState(() {
      _currentLineIndex = newIndex;
    });

    // Schedule scroll after setState completes and widget rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToLine(newIndex, previousIndex);
    });
  }

  void _scrollToLine(int index, int previousIndex) {
    if (!_scrollController.hasClients) return;

    if (index < 0) {
      // Scroll to top when position is before first lyric line
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (index >= _lyrics.length) return;

    // Check if this is a large jump (more than 10 lines)
    final isLargeJump = (index - previousIndex).abs() > 10 || previousIndex < 0;

    if (isLargeJump) {
      // For large jumps, calculate position manually and jump without animation first
      // This ensures the target item gets built
      final targetOffset = (index * _itemHeight) + _verticalPadding - (_scrollController.position.viewportDimension / 2) + (_itemHeight / 2);
      final clampedOffset = targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

      // Jump to approximate position first
      _scrollController.jumpTo(clampedOffset);

      // Then fine-tune with ensureVisible after the item is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final key = _lineKeys[index];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } else {
      // For small jumps, use ensureVisible directly
      final key = _lineKeys[index];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        // Fallback: try again next frame if context not ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && key?.currentContext != null) {
            Scrollable.ensureVisible(
              key!.currentContext!,
              alignment: 0.5,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 280,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Colors.white.withValues(alpha: 0.7),
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading lyrics...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError || _lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lyrics_outlined,
                color: Colors.white.withValues(alpha: 0.5),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No lyrics available',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enjoy the music',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    // Directly render the list without StreamBuilder
    return Stack(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: const [0.0, 0.15, 0.85, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              vertical: _verticalPadding,
              horizontal: 20,
            ),
            itemCount: _lyrics.length,
            physics: const ClampingScrollPhysics(),
            itemBuilder: (context, index) {
              final line = _lyrics[index];
              final isCurrent = index == _currentLineIndex;
              final isPast = index < _currentLineIndex;

              return _LyricLineWidget(
                key: _lineKeys[index],
                text: line.text.isEmpty ? '♪' : line.text,
                isCurrent: isCurrent,
                isPast: isPast,
              );
            },
          ),
        ),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.25),
                ],
                stops: const [0.0, 0.15, 0.85, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Separate widget for smoother animations
class _LyricLineWidget extends StatelessWidget {
  final String text;
  final bool isCurrent;
  final bool isPast;

  const _LyricLineWidget({
    super.key,
    required this.text,
    required this.isCurrent,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: AnimatedScale(
        scale: isCurrent ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: isCurrent ? 1.0 : (isPast ? 0.35 : 0.55),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              fontStyle: FontStyle.italic,
              height: 1.4,
              letterSpacing: 0.3,
              shadows: isCurrent
                  ? [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 14,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
