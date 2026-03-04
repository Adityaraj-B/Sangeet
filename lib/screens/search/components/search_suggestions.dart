import 'package:flutter/material.dart';
import 'package:sangeet/screens/search/components/glass_chip.dart';

/// Inline autocomplete suggestions bar
class SearchSuggestions extends StatelessWidget {
  final List<String> suggestions;
  final bool isSearching;
  final ValueChanged<String> onSuggestionTap;
  final bool showWithResults;

  const SearchSuggestions({
    super.key,
    required this.suggestions,
    required this.isSearching,
    required this.onSuggestionTap,
    this.showWithResults = true,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty || !isSearching) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (int i = 0; i < suggestions.length; i++) ...[
              GlassChip(
                label: suggestions[i],
                onTap: () => onSuggestionTap(suggestions[i]),
                isSuggestion: true,
              ),
              if (i < suggestions.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}
