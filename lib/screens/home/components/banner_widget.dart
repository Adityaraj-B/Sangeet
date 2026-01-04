import 'package:flutter/material.dart';
import '../../../models/song.dart';
import 'search_bar.dart';

class BannerWidget extends StatelessWidget {
  final Song song;
  final TextEditingController searchController;
  final Color surfaceColor;
  final Color softWhite;

  const BannerWidget({
    Key? key,
    required this.song,
    required this.searchController,
    required this.surfaceColor,
    required this.softWhite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image + top/bottom gradients
        ClipRRect(
          borderRadius: BorderRadius.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(song.coverUrl, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: surfaceColor)),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent, Colors.black87],
                    stops: [0.0, 0.25, 1.0],
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [Colors.black.withOpacity(0.75), Colors.black.withOpacity(0.05)],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Floating search bar
        Positioned(left: 16, right: 16, top: 18, child: FloatingSearchBar(controller: searchController, softWhite: softWhite)),

        // Banner content bottom-left
        Positioned(left: 20, right: 20, bottom: 20, child: _buildBannerContent()),
      ],
    );
  }

  Widget _buildBannerContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.red.shade700, borderRadius: BorderRadius.circular(6)),
        child: const Text('New Release', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
      const SizedBox(height: 10),
      Text(song.title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
      const SizedBox(height: 4),
      Text(song.artist, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 15)),
    ]);
  }
}
