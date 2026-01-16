import 'dart:ui';
import 'package:flutter/material.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const _StatItem(value: '1.2K', label: 'Followers'),
              _GlassDivider(),
              const _StatItem(value: '340', label: 'Following'),
              _GlassDivider(),
              const _StatItem(value: '28', label: 'Playlists'),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.02),
            Colors.white.withOpacity(0.18),
            Colors.white.withOpacity(0.02),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.4,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'PlayfairDisplay',
            color: Colors.white.withOpacity(0.45),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
