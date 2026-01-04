import 'dart:ui';
import 'package:flutter/material.dart';

class FloatingSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Color softWhite;
  final VoidCallback? onMicPressed;

  const FloatingSearchBar({
    Key? key,
    required this.controller,
    required this.softWhite,
    this.onMicPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.white70),
              const SizedBox(width: 12),

              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: 1,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white70,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: 'Search songs, artists, albums',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              SizedBox(
                height: 36,
                width: 36,
                child: Material(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onMicPressed,
                    child: const Icon(Icons.mic, size: 18, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
