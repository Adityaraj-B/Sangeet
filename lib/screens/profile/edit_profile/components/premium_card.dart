import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../constants.dart';

class PremiumCard extends StatelessWidget {
  final bool isPremium;
  final ValueChanged<bool> onChanged;

  const PremiumCard({
    super.key,
    required this.isPremium,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),

        // 🌊 Liquid premium gradient
        gradient: isPremium
            ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kAccentColor.withValues(alpha :0.85),
            kAccentColor.withValues(alpha :0.55),
          ],
        )
            : LinearGradient(
          colors: [
            Colors.white.withValues(alpha :0.10),
            Colors.white.withValues(alpha :0.04),
          ],
        ),

        // ✨ Glass border
        border: Border.all(
          color: isPremium
              ? Colors.white.withValues(alpha :0.35)
              : Colors.white.withValues(alpha :0.14),
          width: 0.7,
        ),

        // 🌟 Depth
        boxShadow: isPremium
            ? [
          BoxShadow(
            color: kAccentColor.withValues(alpha :0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ]
            : [
          BoxShadow(
            color: Colors.black.withValues(alpha :0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color:
                      isPremium ? kTextColorDark : kAccentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Premium',
                            style: TextStyle(
                              fontFamily: 'PlayfairDisplay',
                              color: isPremium
                                  ? kTextColorDark
                                  : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPremium
                                ? 'Active subscription'
                                : 'Unlock premium features',
                            style: TextStyle(
                              color: isPremium
                                  ? kTextColorDark.withValues(alpha :0.8)
                                  : Colors.white.withValues(alpha :0.55),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Switch(
                      value: isPremium,
                      activeThumbColor: kBackgroundColor,
                      activeTrackColor:
                      kTextColorDark.withValues(alpha :0.5),
                      inactiveThumbColor: kAccentColor,
                      inactiveTrackColor:
                      kAccentColor.withValues(alpha :0.35),
                      onChanged: onChanged,
                    ),
                  ],
                ),

                if (isPremium) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: kTextColorDark.withValues(alpha :0.15),
                      border: Border.all(
                        color: kTextColorDark.withValues(alpha :0.25),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: kTextColorDark,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ad-free • High quality • Offline listening',
                            style: TextStyle(
                              color:
                              kTextColorDark.withValues(alpha :0.9),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
