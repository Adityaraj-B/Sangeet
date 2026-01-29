import 'package:flutter/material.dart';
import '../../../constants.dart';

/// A vertical bar representing listening activity for a weekday
class WeekdayBar extends StatelessWidget {
  final String day;
  final double intensity;
  final int count;

  const WeekdayBar({
    super.key,
    required this.day,
    required this.intensity,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count > 0 ? '$count' : '-',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 32,
              height: 60 * intensity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    kAccentColor.withValues(alpha: 0.4),
                    kAccentColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: intensity > 0
                    ? [
                        BoxShadow(
                          color: kAccentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: intensity > 0.5
                ? kAccentColor
                : Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
