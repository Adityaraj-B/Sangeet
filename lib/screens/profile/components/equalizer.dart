import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'dart:math' as math;

class EqualizerGraphScreen extends StatefulWidget {
  const EqualizerGraphScreen({super.key});

  @override
  State<EqualizerGraphScreen> createState() => _EqualizerGraphScreenState();
}

class _EqualizerGraphScreenState extends State<EqualizerGraphScreen>
    with SingleTickerProviderStateMixin {
  final List<String> bands = ['60', '230', '910', '3.6k', '14k'];
  late List<double> values;
  AnimationController? _pulseController;

  int? _activeIndex;
  String _activePreset = 'Flat';

  @override
  void initState() {
    super.initState();
    values = List.filled(bands.length, 0.0);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0x26FFFFFF),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: kPrimaryColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Equalizer',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
            color: kPrimaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Animated gradient background
          if (_pulseController != null)
            AnimatedBuilder(
              animation: _pulseController!,
              builder: (context, child) {
                final pulseValue = _pulseController!.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [
                        Color.lerp(const Color(0x1AFFCB74), const Color(0x33FFCB74), pulseValue)!,
                        const Color(0x0DFFCB74),
                        kBackgroundColor,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                );
              },
            ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Title section
                  _buildHeader(),

                  const SizedBox(height: 32),

                  // Main equalizer graph
                  _glassContainer(
                    height: 320,
                    child: GestureDetector(
                      onPanUpdate: _onDrag,
                      onPanEnd: (_) => setState(() => _activeIndex = null),
                      child: CustomPaint(
                        painter: _EqualizerPainter(
                          values,
                          _activeIndex,
                          _pulseController?.value ?? 0.0,
                        ),
                        child: Container(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Frequency labels
                  _labels(),

                  const Spacer(),

                  // Preset buttons
                  _presetButtons(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── UI PARTS ─────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kSurfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: kAccentColor,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                color: kAccentColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _activePreset,
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  color: kPrimaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Drag to adjust frequency bands',
          style: TextStyle(
            color: kMutedTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _glassContainer({required double height, required Widget child}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kSurfaceColor,
            const Color(0xFF1A1719),
          ],
        ),
        border: Border.all(
          color: const Color(0x33FFFFFF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: kAccentColor.withAlpha(51),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _labels() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: bands.asMap().entries.map((entry) {
          final isActive = _activeIndex == entry.key;
          return AnimatedContainer(
            duration: kAnimationDuration,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? kSurfaceColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? kAccentColor : Colors.transparent,
                width: 1,
              ),
            ),
            child: Text(
              entry.value,
              style: TextStyle(
                color: isActive ? kPrimaryColor : kMutedTextColor,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _presetButtons() {
    final presets = {
      'Flat': List.filled(5, 0.0),
      'Bass Boost': [6.0, 4.0, 1.0, -2.0, -4.0],
      'Rock': [4.0, 2.0, 0.0, 2.0, 4.0],
      'Vocal': [-2.0, 1.0, 4.0, 3.0, -1.0],
      'Electronic': [3.0, 2.0, -1.0, 2.0, 4.0],
      'Classical': [-1.0, -1.0, 0.0, 2.0, 3.0],
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: presets.entries.map((entry) {
        final isActive = _activePreset == entry.key;
        return _preset(entry.key, entry.value, isActive);
      }).toList(),
    );
  }

  Widget _preset(String name, List<double> preset, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              values = List.from(preset);
              _activePreset = name;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: isActive
                  ? LinearGradient(
                colors: [
                  kAccentColor,
                  kAccentColor.withAlpha(179),
                ],
              )
                  : null,
              color: isActive ? null : kSurfaceColor,
              border: Border.all(
                color: isActive ? kAccentColor : const Color(0x26FFFFFF),
                width: isActive ? 1.5 : 1,
              ),
              boxShadow: isActive
                  ? [
                BoxShadow(
                  color: kAccentColor.withAlpha(102),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isActive) ...[
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: kTextColorDark,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    color: isActive ? kTextColorDark : kPrimaryColor,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── INTERACTION ─────────────────────────

  void _onDrag(DragUpdateDetails d) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(d.globalPosition);
    final width = box.size.width - 48; // Account for padding
    final height = box.size.height - 48;

    final step = width / (values.length - 1);
    final index = ((local.dx - 24) / step).round().clamp(0, values.length - 1);

    final centerY = height / 2 + 24;
    final value = ((centerY - local.dy) / (height / 2)) * 10;
    values[index] = value.clamp(-10, 10);

    setState(() {
      _activeIndex = index;
      _activePreset = 'Custom';
    });
  }
}

/* ───────────────────────── PAINTER ───────────────────────── */

class _EqualizerPainter extends CustomPainter {
  final List<double> values;
  final int? active;
  final double pulse;

  _EqualizerPainter(this.values, this.active, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;

    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Gradient fill under curve
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          kAccentColor.withAlpha(102),
          kAccentColor.withAlpha(51),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path();
    final step = size.width / (values.length - 1);

    fillPath.moveTo(0, size.height);
    for (int i = 0; i < values.length; i++) {
      final x = step * i;
      final y = size.height / 2 - (values[i] / 10) * (size.height / 2);

      if (i == 0) {
        fillPath.lineTo(x, y);
      } else {
        final prevX = step * (i - 1);
        final prevY = size.height / 2 - (values[i - 1] / 10) * (size.height / 2);
        final cpX = (prevX + x) / 2;
        fillPath.quadraticBezierTo(cpX, prevY, x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, gradientPaint);

    // Smooth curve line
    final paintLine = Paint()
      ..color = kAccentColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = step * i;
      final y = size.height / 2 - (values[i] / 10) * (size.height / 2);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = step * (i - 1);
        final prevY = size.height / 2 - (values[i - 1] / 10) * (size.height / 2);
        final cpX = (prevX + x) / 2;
        path.quadraticBezierTo(cpX, prevY, x, y);
      }
    }

    canvas.drawPath(path, paintLine);

    // Control points with glow
    for (int i = 0; i < values.length; i++) {
      final x = step * i;
      final y = size.height / 2 - (values[i] / 10) * (size.height / 2);
      final isActive = active == i;

      // Glow effect for active point
      if (isActive) {
        final glowPaint = Paint()
          ..color = Color.lerp(kAccentColor.withAlpha(77), kAccentColor.withAlpha(128), pulse)!
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
        canvas.drawCircle(Offset(x, y), 12, glowPaint);
      }

      // Outer ring
      final ringPaint = Paint()
        ..color = isActive ? kAccentColor : kPrimaryColor.withAlpha(77)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(x, y), isActive ? 10 : 8, ringPaint);

      // Inner dot
      final dotPaint = Paint()
        ..color = isActive ? kPrimaryColor : kPrimaryColor.withAlpha(230);
      canvas.drawCircle(Offset(x, y), isActive ? 6 : 4, dotPaint);
    }

    // Center line
    final centerPaint = Paint()
      ..color = const Color(0x26FFFFFF)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}