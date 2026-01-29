import 'package:flutter/material.dart';
import 'package:sangeet/screens/search/components/glass_chip.dart';

/// Recent searches widget
class RecentSearches extends StatelessWidget {
  final List<String> recent;
  final bool isSearching;
  final ValueChanged<String> onRecentTap;
  final VoidCallback onClear;

  const RecentSearches({
    super.key,
    required this.recent,
    required this.isSearching,
    required this.onRecentTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty || isSearching) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent searches',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onClear,
              child: Text(
                'CLEAR',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recent
              .map(
                (r) => GlassChip(
                  label: r,
                  onTap: () => onRecentTap(r),
                  isSuggestion: false,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
