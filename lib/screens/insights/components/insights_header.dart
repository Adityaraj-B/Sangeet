import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../constants.dart';

/// Animated header widget for the insights screen
class InsightsHeader extends StatelessWidget {
  final int totalMinutes;
  final int totalSongs;
  final int likedSongs;
  final AnimationController pulseAnimation;

  const InsightsHeader({
    super.key,
    required this.totalMinutes,
    required this.totalSongs,
    required this.likedSongs,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Animated gradient background
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      const Color(0xFF6B8AFF),
                      const Color(0xFF8A6BFF),
                      pulseAnimation.value,
                    )!.withValues(alpha: 0.8),
                    Color.lerp(
                      const Color(0xFFFF6B8A),
                      const Color(0xFFFFB86B),
                      pulseAnimation.value,
                    )!.withValues(alpha: 0.6),
                    kBackgroundColor,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              )
            );
          },
        ),

        // Liquid glass orbs
        AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  top: -60 + (pulseAnimation.value * 20),
                  right: -40,
                  child: _GlassOrb(
                    size: 200,
                    color: const Color(0xFF6B8AFF).withValues(alpha: 0.3),
                  ),
                ),
                Positioned(
                  top: 100 - (pulseAnimation.value * 15),
                  left: -60,
                  child: _GlassOrb(
                    size: 150,
                    color: const Color(0xFFFF6B8A).withValues(alpha: 0.2),
                  ),
                ),
                Positioned(
                  bottom: 40 + (pulseAnimation.value * 10),
                  right: 40,
                  child: _GlassOrb(
                    size: 80,
                    color: kAccentColor.withValues(alpha: 0.25),
                  ),
                ),
              ],
            );
          },
        ),

        // Blur overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  kBackgroundColor.withValues(alpha: 0.5),
                  kBackgroundColor,
                ],
                stops: const [0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your Insights',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Discover your listening habits',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Glass Orb Widget for decorative animated backgrounds
class _GlassOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlassOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
