import 'dart:ui';
import 'package:flutter/material.dart';

class GlassTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const GlassTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  State<GlassTile> createState() => _GlassTileState();
}

class _GlassTileState extends State<GlassTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha :_pressed ? 0.14 : 0.10),
                  Colors.white.withValues(alpha :_pressed ? 0.06 : 0.035),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha :_pressed ? 0.22 : 0.12),
                width: 0.7,
              ),
              boxShadow: _pressed
                  ? [
                BoxShadow(
                  color: Colors.white.withValues(alpha :0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                splashColor: Colors.white.withValues(alpha :0.05),
                highlightColor: Colors.white.withValues(alpha :0.03),
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTapUp: (_) => setState(() => _pressed = false),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.icon,
                        color: Colors.white.withValues(alpha :_pressed ? 0.9 : 0.75),
                        size: 20,
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.25,
                              ),
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                widget.subtitle!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha :0.45),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (widget.trailing != null) widget.trailing!,
                    ],
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
