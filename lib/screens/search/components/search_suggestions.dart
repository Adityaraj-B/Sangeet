import 'package:flutter/material.dart';
import 'package:sangeet/screens/search/components/glass_chip.dart';

/// Suggestions widget displaying search suggestions (Spotify-like autocomplete)
class SearchSuggestions extends StatelessWidget {
  final List<String> suggestions;
  final bool isSearching;
  final ValueChanged<String> onSuggestionTap;
  final bool showWithResults; // Whether to show suggestions alongside results

  const SearchSuggestions({
    super.key,
    required this.suggestions,
    required this.isSearching,
    required this.onSuggestionTap,
    this.showWithResults = true, // Default to Spotify-like behavior
  });

  @override
  Widget build(BuildContext context) {
    // Show suggestions when searching AND there are suggestions
    if (suggestions.isEmpty || !isSearching) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (suggestions.isNotEmpty) ...[
          Text(
            'Suggestions',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: suggestions
                .map((s) => GlassChip(
                      label: s,
                      onTap: () => onSuggestionTap(s),
                      isSuggestion: true,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
