import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class LiquidGlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;

  const LiquidGlassButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Frosted glass blur
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isPrimary
                        ? [
                      const Color(0xFF3D3021),
                      const Color(0xFF2D2419),
                      const Color(0xFF1F1A14),
                    ]
                        : [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
              ),
            ),
            // Subtle top highlight
            Positioned(
              top: 0,
              left: 20,
              right: 20,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: isPrimary ? 0.15 : 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Content - properly centered
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(28),
                splashColor: isPrimary
                    ? kAccentColor.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.1),
                highlightColor: isPrimary
                    ? kAccentColor.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.05),
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          color: isPrimary
                              ? kAccentColor
                              : Colors.white.withValues(alpha: 0.9),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            color: isPrimary
                                ? kAccentColor
                                : Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 0.2,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}