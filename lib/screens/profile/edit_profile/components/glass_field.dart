import 'dart:ui';
import 'package:flutter/material.dart';

class GlassField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final int maxLines;

  const GlassField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  State<GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<GlassField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),

              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha :_focused ? 0.14 : 0.10),
                  Colors.white.withValues(alpha :_focused ? 0.06 : 0.035),
                ],
              ),

              border: Border.all(
                color: Colors.white.withValues(alpha :_focused ? 0.22 : 0.12),
                width: 0.7,
              ),

              boxShadow: _focused
                  ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha :0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
                  : [],
            ),
            child: Focus(
              onFocusChange: (v) => setState(() => _focused = v),
              child: TextField(
                controller: widget.controller,
                maxLines: widget.maxLines,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  letterSpacing: 0.2,
                ),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: TextStyle(
                    color: Colors.white.withValues(alpha :0.55),
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                  floatingLabelStyle: TextStyle(
                    color: Colors.white.withValues(alpha :0.75),
                  ),
                  prefixIcon: Icon(
                    widget.icon,
                    color: Colors.white.withValues(alpha :_focused ? 0.85 : 0.6),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
