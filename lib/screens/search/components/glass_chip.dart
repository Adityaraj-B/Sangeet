import 'package:flutter/material.dart';

class GlassChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSuggestion;

  const GlassChip({
    super.key,
    required this.label,
    required this.onTap,
    required this.isSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSuggestion
                ? Colors.white.withValues(alpha :0.08)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha :isSuggestion ? 0.12 : 0.05),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: isSuggestion ? 0.9 : 0.7),
              fontSize: 13,
              fontWeight: isSuggestion ? FontWeight.w500 : FontWeight.w400,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}