import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sangeet/constants.dart';

class ProgressBar extends StatelessWidget {
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;
  // removed playingStream
  final Color accentColor;
  final void Function(Duration) onSeek;

  const ProgressBar({
    super.key,
    required this.positionStream,
    required this.durationStream,
    required this.accentColor,
    required this.onSeek,
  });

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: durationStream,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: positionStream,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final maxMs = duration.inMilliseconds.toDouble();
            final currentMs = position.inMilliseconds.toDouble();

            final rawProgress = maxMs == 0 ? 0.0 : (currentMs / maxMs);
            final progress = rawProgress.clamp(0.0, 1.0);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WavySlider(
                  progress: progress,
                  accentColor: kPrimaryColor,
                  onSeek: (newProgress) {
                    final ms = newProgress * maxMs;
                    onSeek(Duration(milliseconds: ms.toInt()));
                  },
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _format(position),
                        style: TextStyle(
                          color: accentColor.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        _format(duration),
                        style: TextStyle(
                          color: accentColor.withValues(alpha: 0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _WavySlider extends StatefulWidget {
  final double progress;
  final Color accentColor;
  final ValueChanged<double> onSeek;

  const _WavySlider({
    required this.progress,
    required this.accentColor,
    required this.onSeek,
  });

  @override
  State<_WavySlider> createState() => _WavySliderState();
}

class _WavySliderState extends State<_WavySlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  Timer? _pauseDetector;

  bool _isDragging = false;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    // Initially assume stopped until first update
  }

  @override
  void didUpdateWidget(_WavySlider oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-detect Play/Pause state based on progress updates
    if (widget.progress != oldWidget.progress && !_isDragging) {
      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }
      _resetPauseTimer();
    }
  }

  void _resetPauseTimer() {
    _pauseDetector?.cancel();
    // If no progress update for 300ms, assume paused and stop wave
    _pauseDetector = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _waveController.stop();
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _pauseDetector?.cancel();
    super.dispose();
  }

  void _handleDragUpdate(double dx, double width) {
    final newProgress = (dx / width).clamp(0.0, 1.0);
    setState(() => _dragValue = newProgress);
  }

  @override
  Widget build(BuildContext context) {
    final targetProgress = _isDragging ? (_dragValue ?? 0) : widget.progress;

    return GestureDetector(
      onHorizontalDragStart: (details) {
        setState(() => _isDragging = true);
        _waveController.stop(); // Stop wave while dragging
        HapticFeedback.selectionClick();
      },
      onHorizontalDragEnd: (details) {
        setState(() => _isDragging = false);
        if (_dragValue != null) {
          widget.onSeek(_dragValue!);
          _dragValue = null;
          HapticFeedback.lightImpact();
          // Wave will resume in didUpdateWidget when new position arrives
        }
      },
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPos = box.globalToLocal(details.globalPosition);
        _handleDragUpdate(localPos.dx, box.size.width);
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox;
        final localPos = box.globalToLocal(details.globalPosition);
        final newProgress = (localPos.dx / box.size.width).clamp(0.0, 1.0);
        widget.onSeek(newProgress);
        HapticFeedback.lightImpact();
      },
      child: Container(
        height: 30,
        color: Colors.transparent,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: targetProgress),
          duration: _isDragging ? Duration.zero : const Duration(milliseconds: 250),
          curve: Curves.easeOutQuad,
          builder: (context, smoothProgress, child) {
            return AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _WavyTrackPainter(
                    progress: smoothProgress,
                    phase: _waveController.value,
                    accentColor: widget.accentColor,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WavyTrackPainter extends CustomPainter {
  final double progress;
  final double phase;
  final Color accentColor;

  _WavyTrackPainter({
    required this.progress,
    required this.phase,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final activeWidth = size.width * progress;

    // 1. Draw Inactive Track (Straight Line)
    final inactivePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      inactivePaint,
    );

    // 2. Draw Active Track (Wavy Line)
    if (activeWidth > 0) {
      final activePaint = Paint()
        ..color = accentColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      const waveHeight = 3.0;
      const waveLength = 35.0;

      path.moveTo(0, centerY);

      for (double x = 0; x <= activeWidth; x++) {
        final sine = math.sin((x / waveLength * 2 * math.pi) - (phase * 2 * math.pi));

        // Dampen start
        final startDamping = (x < 15) ? (x / 15) : 1.0;

        // Dampen end: Flatten the wave as it approaches the thumb
        // This ensures the line meets the center of the fixed thumb
        final endDamping = (x > activeWidth - 15) ? (activeWidth - x) / 15 : 1.0;

        final y = centerY + (sine * waveHeight * startDamping * endDamping);
        path.lineTo(x, y);
      }

      canvas.drawPath(path, activePaint);

      // 3. Draw Thumb (FIXED at Center Y)
      final thumbX = activeWidth;
      final thumbY = centerY;

      final thumbPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(thumbX, thumbY), 5, thumbPaint);
    }
  }

  @override
  bool shouldRepaint(_WavyTrackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.phase != phase ||
        oldDelegate.accentColor != accentColor;
  }
}