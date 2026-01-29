import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Search result categories for Spotify-like organization
enum SearchCategory { all, songs, artists }

/// Category filter chips for search results
class CategoryChips extends StatelessWidget {
  final SearchCategory selectedCategory;
  final int songCount;
  final int artistCount;
  final ValueChanged<SearchCategory> onCategoryChanged;

  const CategoryChips({
    super.key,
    required this.selectedCategory,
    required this.songCount,
    required this.artistCount,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('All', SearchCategory.all, null),
          const SizedBox(width: 8),
          _buildFilterChip('Songs', SearchCategory.songs, songCount),
          const SizedBox(width: 8),
          _buildFilterChip('Artists', SearchCategory.artists, artistCount),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, SearchCategory category, int? count) {
    final isSelected = selectedCategory == category;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onCategoryChanged(category);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
