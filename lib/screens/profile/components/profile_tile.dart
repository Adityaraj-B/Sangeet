import 'dart:ui';
import 'package:flutter/material.dart';

class ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const ProfileTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              splashColor: Colors.white.withValues(alpha :0.06),
              highlightColor: Colors.white.withValues(alpha :0.04),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha :0.10),
                      Colors.white.withValues(alpha :0.03),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha :0.18),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: Colors.white.withValues(alpha :0.92),
                      size: 22,
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.25,
                        ),
                      ),
                    ),

                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withValues(alpha :0.28),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
