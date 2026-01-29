import 'dart:math';
import 'package:flutter/material.dart';
import '../../../constants.dart';

class HourlyChart extends StatelessWidget {
  final Map<int, int> data;
  const HourlyChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final maxValue = max(1, data.values.fold(0, max));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: CustomPaint(
          painter: _HourlyGraphPainter(
            data: data,
            maxValue: maxValue,
            accent: kAccentColor,
          ),
        ),
      ),
    );
  }
}

class _HourlyGraphPainter extends CustomPainter {
  final Map<int, int> data;
  final int maxValue;
  final Color accent;

  _HourlyGraphPainter({
    required this.data,
    required this.maxValue,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height * 0.75;
    final baselineY = size.height - 20;
    final stepX = size.width / 23;

    // Subtle grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha :0.04)
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = baselineY - (chartHeight * i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = List.generate(24, (i) {
      final value = data[i] ?? 0;
      final normalized = value / maxValue;
      final x = stepX * i;
      final y = baselineY - (normalized * chartHeight);
      return Offset(x, y);
    });

    // Smooth cubic bezier path
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cx1 = prev.dx + (curr.dx - prev.dx) * 0.5;
      final cx2 = prev.dx + (curr.dx - prev.dx) * 0.5;
      path.cubicTo(cx1, prev.dy, cx2, curr.dy, curr.dx, curr.dy);
    }

    // Gradient fill
    final fillPath = Path.from(path)
      ..lineTo(size.width, baselineY)
      ..lineTo(0, baselineY)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accent.withValues(alpha :0.3),
          accent.withValues(alpha :0.05),
          accent.withValues(alpha :0.0),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Line glow
    final glowPaint = Paint()
      ..color = accent.withValues(alpha :0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    // Main line with gradient
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [accent, accent.withValues(alpha :0.8)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Premium dots with glow
    for (int i = 0; i < points.length; i += 6) {
      canvas.drawCircle(
        points[i], 8,
        Paint()
          ..color = accent.withValues(alpha :0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(points[i], 4, Paint()..color = accent.withValues(alpha :0.3));
      canvas.drawCircle(points[i], 2.5, Paint()..color = accent);
    }

    // Time labels
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.4),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );
    for (int i = 0; i < 24; i += 6) {
      final tp = TextPainter(
        text: TextSpan(text: '${i}h', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(stepX * i - tp.width / 2, size.height - 12));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
