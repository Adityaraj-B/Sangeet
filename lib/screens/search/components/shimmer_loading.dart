import 'package:flutter/material.dart';

/// Shimmer loading placeholder for search results
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        // How many artist circles fit
        const circleW = 74.0;
        const circleGap = 16.0;
        final artistCount =
            ((w + circleGap) / (circleW + circleGap)).floor().clamp(2, 5);

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Filter chips ──
                Row(
                  children: [
                    _box(52, 34, BorderRadius.circular(100)),
                    const SizedBox(width: 8),
                    _box(66, 34, BorderRadius.circular(100)),
                    const SizedBox(width: 8),
                    _box(72, 34, BorderRadius.circular(100)),
                    const SizedBox(width: 8),
                    _box(68, 34, BorderRadius.circular(100)),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Songs section label ──
                _box(48, 12, BorderRadius.circular(6)),
                const SizedBox(height: 14),

                // ── Song rows ──
                ...List.generate(6, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          _box(50, 50, BorderRadius.circular(8)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _box(
                                  (w * (0.45 + (i % 3) * 0.12))
                                      .clamp(100, w - 100),
                                  12,
                                  BorderRadius.circular(6),
                                ),
                                const SizedBox(height: 7),
                                _box(
                                  (w * 0.28 + (i % 2) * 20).clamp(70, 160),
                                  10,
                                  BorderRadius.circular(6),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _box(20, 20, BorderRadius.circular(10)),
                        ],
                      ),
                    )),

                const SizedBox(height: 10),

                // ── Artists section label ──
                _box(48, 12, BorderRadius.circular(6)),
                const SizedBox(height: 14),

                // ── Artist circles ──
                Row(
                  children: List.generate(
                    artistCount,
                    (i) => Padding(
                      padding: EdgeInsets.only(
                          right: i < artistCount - 1 ? circleGap : 0),
                      child: Column(
                        children: [
                          _box(circleW, circleW,
                              BorderRadius.circular(circleW / 2)),
                          const SizedBox(height: 9),
                          _box(48, 9, BorderRadius.circular(6)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Albums section label ──
                _box(52, 12, BorderRadius.circular(6)),
                const SizedBox(height: 14),

                // ── Album rows ──
                ...List.generate(3, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          _box(50, 50, BorderRadius.circular(8)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _box(
                                  (w * (0.5 + i * 0.08)).clamp(100, w - 100),
                                  12,
                                  BorderRadius.circular(6),
                                ),
                                const SizedBox(height: 7),
                                _box(
                                  (w * 0.3 + i * 15).clamp(70, 150),
                                  10,
                                  BorderRadius.circular(6),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            );
          },
        );
      },
    );
  }

  Widget _box(double width, double height, BorderRadius radius) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment(_animation.value - 0.8, 0),
          end: Alignment(_animation.value + 0.8, 0),
          colors: [
            Colors.white.withValues(alpha: 0.03),
            Colors.white.withValues(alpha: 0.075),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
      ),
    );
  }
}
