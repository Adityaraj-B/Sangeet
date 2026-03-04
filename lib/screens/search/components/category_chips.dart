import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Search result categories for Spotify-like organization
enum SearchCategory { all, songs, artists, albums }

/// Category filter pills for search results
class CategoryChips extends StatelessWidget {
  final SearchCategory selectedCategory;
  final int songCount;
  final int artistCount;
  final int albumCount;
  final ValueChanged<SearchCategory> onCategoryChanged;

  const CategoryChips({
    super.key,
    required this.selectedCategory,
    required this.songCount,
    required this.artistCount,
    required this.albumCount,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _chip('All', SearchCategory.all, null),
          const SizedBox(width: 8),
          _chip('Songs', SearchCategory.songs, songCount),
          const SizedBox(width: 8),
          _chip('Artists', SearchCategory.artists, artistCount),
          const SizedBox(width: 8),
          _chip('Albums', SearchCategory.albums, albumCount),
        ],
      ),
    );
  }

  Widget _chip(String label, SearchCategory category, int? count) {
    final isSelected = selectedCategory == category;
    return _AnimatedChip(
      label: label,
      count: count,
      isSelected: isSelected,
      onTap: () {
        HapticFeedback.selectionClick();
        onCategoryChanged(category);
      },
    );
  }
}

class _AnimatedChip extends StatefulWidget {
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AnimatedChip> createState() => _AnimatedChipState();
}

class _AnimatedChipState extends State<_AnimatedChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? Colors.white
                : const Color(0xFF1A1A1D),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isSelected
                      ? Colors.black
                      : Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
              if (widget.count != null && widget.count! > 0) ...[
                const SizedBox(width: 5),
                Text(
                  '${widget.count}',
                  style: TextStyle(
                    color: widget.isSelected
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.28),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
