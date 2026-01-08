import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class SlidingBubbleNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double horizontalPadding;
  final double barHeight;

  const SlidingBubbleNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.horizontalPadding = 12.0,
    this.barHeight = 73.0,
  });

  @override
  State<SlidingBubbleNavBar> createState() => _SlidingBubbleNavBarState();
}

class _SlidingBubbleNavBarState extends State<SlidingBubbleNavBar> {
  late int selected;

  static const _items = [
    _NavItem(label: 'Home', icon: Icons.home_filled),
    _NavItem(label: 'Discover', icon: Icons.search),
    _NavItem(label: 'Podcasts', icon: Icons.podcasts),
    _NavItem(label: 'Library', icon: Icons.library_music_rounded),
  ];

  @override
  void initState() {
    super.initState();
    selected = widget.currentIndex;
  }

  @override
  void didUpdateWidget(covariant SlidingBubbleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != selected) {
      selected = widget.currentIndex;
    }
  }

  void _handleTap(int index) {
    if (index == selected) return;
    setState(() => selected = index);
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    const bubbleSize = 67.0;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final totalHeight = widget.barHeight + bottomInset;

    return SizedBox(
      height: totalHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: Colors.black.withOpacity(0.14),
            padding: EdgeInsets.only(
              left: widget.horizontalPadding,
              right: widget.horizontalPadding,
              bottom: bottomInset,
              top: 8,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / _items.length;
                final bubbleLeft =
                    (itemWidth * selected) + (itemWidth - bubbleSize) / 2;

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedPositioned(
                      left: bubbleLeft,
                      duration: kAnimationDuration,
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: bubbleSize,
                        height: bubbleSize,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Row(
                      children: _items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isSelected = index == selected;

                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _handleTap(index),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: kAnimationDuration,
                                  transform: Matrix4.identity()
                                    ..translate(0.0, isSelected ? -2.5 : 0.0)
                                    ..scale(isSelected ? 1.06 : 1.0),
                                  child: Icon(
                                    item.icon,
                                    size: isSelected ? 26 : 22,
                                    color: isSelected
                                        ? kAccentColor
                                        : kMutedTextColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AnimatedDefaultTextStyle(
                                  duration: kAnimationDuration,
                                  style: TextStyle(
                                    color: isSelected
                                        ? kAccentColor
                                        : kMutedTextColor,
                                    fontSize: isSelected ? 12 : 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  child: Text(item.label),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}
