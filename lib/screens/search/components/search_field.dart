import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;
  final ValueChanged<String>? onSubmitted;

  const SearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onClear,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasFocus = focusNode.hasFocus;
    final bool hasText = controller.text.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: 50,
            decoration: BoxDecoration(
              color: hasFocus ? const Color(0xFF1C1C1F) : const Color(0xFF161618),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasFocus
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
              boxShadow: hasFocus
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.03),
                        blurRadius: 20,
                        spreadRadius: 0,
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                const SizedBox(width: 15),
                AnimatedScale(
                  scale: hasFocus ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: hasFocus
                        ? Colors.white.withValues(alpha: 0.75)
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
                    ),
                    cursorColor: Colors.white,
                    cursorWidth: 1.5,
                    cursorRadius: const Radius.circular(2),
                    decoration: InputDecoration(
                      hintText: 'Songs, artists, albums…',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.2,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onSubmitted: onSubmitted,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: hasText
                      ? GestureDetector(
                          key: const ValueKey('clear'),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onClear();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white.withValues(alpha: 0.6),
                              size: 14,
                            ),
                          ),
                        )
                      : const SizedBox(key: ValueKey('empty'), width: 14),
                ),
              ],
            ),
          ),
        ),
        // Animated Cancel button
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: hasFocus ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: hasFocus
                ? GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      focusNode.unfocus();
                      onClear();
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 14),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
