import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sangeet/models/artist.dart';

class ArtistCircle extends StatefulWidget {
  final Artist artist;
  final VoidCallback onTap;

  const ArtistCircle({super.key, required this.artist, required this.onTap});

  @override
  State<ArtistCircle> createState() => _ArtistCircleState();
}

class _ArtistCircleState extends State<ArtistCircle> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              // Circle with glow
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: widget.artist.imageUrl.isNotEmpty
                      ? Image.network(
                          widget.artist.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                widget.artist.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF1E1E22),
        child: Center(
          child: Icon(Icons.person_rounded,
              color: Colors.white.withValues(alpha: 0.12), size: 28),
        ),
      );
}
