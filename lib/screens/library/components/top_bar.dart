import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class TopBar extends StatelessWidget {
  final AnimationController animation;
  final VoidCallback? onProfileTap;
  final VoidCallback? onInsightsTap;
  final VoidCallback? onNotificationsTap;
  final int notificationsCount;

  const TopBar({
    required this.animation,
    this.onProfileTap,
    this.onInsightsTap,
    this.onNotificationsTap,
    this.notificationsCount = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Keep the SizeTransition you had for the entrance animation.
    // IMPORTANT: To make this TopBar *scrollable / not fixed*, ensure you place it
    // inside a scrollable parent (for example: a Column inside a SingleChildScrollView
    // or as a SliverToBoxAdapter inside a CustomScrollView). This widget itself is not
    // sticky — it will move with the parent scroll.
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      axisAlignment: -1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
        child: Row(
          children: [
            // PROFILE (tappable)
            InkWell(
              onTap: onProfileTap,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 44,
                      height: 44,
                      color: kSurfaceColor,
                      alignment: Alignment.center,
                      child: const Icon(Icons.person, color: kPrimaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adityaraj',
                        style: TextStyle(color: kPrimaryColor, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Premium',
                        style: TextStyle(color: kPrimaryColor.withOpacity(0.6), fontSize: 12),
                      ),
                    ],
                  )
                ],
              ),
            ),

            const Spacer(),

            // RIGHT SIDE: two action buttons (insights, notifications)
            Row(
              children: [
                _ActionSquare(
                  icon: Icons.insights_rounded,
                  tooltip: 'Insights',
                  onTap: onInsightsTap,
                ),
                const SizedBox(width: 10),
                _ActionSquare(
                  icon: Icons.notifications_none,
                  tooltip: 'Notifications',
                  onTap: onNotificationsTap,
                  badgeCount: notificationsCount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small square action button that matches the app theme (matte, subtle border).
class _ActionSquare extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final int badgeCount;

  const _ActionSquare({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: kSurfaceColor.withOpacity(0.58),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPrimaryColor.withOpacity(0.06)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: kPrimaryColor.withOpacity(0.92), size: 20),
          if (badgeCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kAccentColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimaryColor.withOpacity(0.06), width: 0.6),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Tooltip(message: tooltip ?? '', child: child),
      ),
    );
  }
}
