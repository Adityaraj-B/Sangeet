import 'package:flutter/material.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const _StatItem(value: '1.2K', label: 'Followers'),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.08),
          ),
          const _StatItem(value: '340', label: 'Following'),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.08),
          ),
          const _StatItem(value: '28', label: 'Playlists'),
        ],
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
            letterSpacing: 0.3,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'PlayfairDisplay',
            color: Colors.white.withOpacity(0.4),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}