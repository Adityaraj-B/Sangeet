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
    if (recent.isEmpty || isSearching) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent searches',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClear,
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
      ),
    );
  }
}
