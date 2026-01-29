import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSuggestion;
  final IconData? icon;

  const GlassChip({
    super.key,
    required this.label,
    required this.onTap,
    required this.isSuggestion,
    this.icon,
  });

  @override
  State<GlassChip> createState() => _GlassChipState();
}

class _GlassChipState extends State<GlassChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: widget.isSuggestion
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: _isPressed ? 0.15 : 0.1),
                    Colors.white.withValues(alpha: _isPressed ? 0.08 : 0.05),
                  ],
                )
              : null,
          color: widget.isSuggestion
              ? null
              : Colors.white.withValues(alpha: _isPressed ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: widget.isSuggestion
                  ? (_isPressed ? 0.2 : 0.12)
                  : (_isPressed ? 0.1 : 0.05),
            ),
            width: 1,
          ),
          boxShadow: widget.isSuggestion ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: 14,
                color: Colors.white.withValues(
                  alpha: widget.isSuggestion ? 0.7 : 0.5,
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (!widget.isSuggestion) ...[
              Icon(
                Icons.history_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: widget.isSuggestion ? 0.9 : 0.7,
                  ),
                  fontSize: 13,
                  fontWeight: widget.isSuggestion ? FontWeight.w500 : FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (widget.isSuggestion) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.north_west_rounded,
                size: 12,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}