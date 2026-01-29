import 'package:flutter/material.dart';

/// Shimmer loading placeholder for search results
class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Shimmer chips
        Row(
          children: List.generate(3, (index) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _shimmerBox(60, 32, BorderRadius.circular(20)),
          )),
        ),
        const SizedBox(height: 24),
        // Shimmer top result
        _shimmerBox(double.infinity, 140, BorderRadius.circular(16)),
        const SizedBox(height: 24),
        // Shimmer song items
        ...List.generate(3, (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _shimmerBox(double.infinity, 72, BorderRadius.circular(12)),
        )),
      ],
    );
  }

  Widget _shimmerBox(double width, double height, BorderRadius radius) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.6),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: value * 0.1),
                Colors.white.withValues(alpha: value * 0.05),
                Colors.white.withValues(alpha: value * 0.1),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}
