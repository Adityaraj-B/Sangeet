import 'package:flutter/material.dart';

/// Show more button for expanding search results
class ShowMoreButton extends StatefulWidget {
  final String type;
  final int remaining;
  final VoidCallback onTap;

  const ShowMoreButton({
    super.key,
    required this.type,
    required this.remaining,
    required this.onTap,
  });

  @override
  State<ShowMoreButton> createState() => _ShowMoreButtonState();
}

class _ShowMoreButtonState extends State<ShowMoreButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2, left: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See all ${widget.type}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.35),
                size: 11,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
