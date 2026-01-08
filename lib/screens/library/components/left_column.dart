import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class LeftColumn extends StatelessWidget {
  const LeftColumn({super.key});

  Widget _insightRow(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: kPrimaryColor.withOpacity(0.66), fontSize: 12)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: kPrimaryColor, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _utilityLink(String title, IconData icon) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: kSurfaceColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kPrimaryColor.withOpacity(0.03)),
        ),
        child: Row(
          children: [
            Icon(icon, color: kPrimaryColor.withOpacity(0.72), size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(color: kPrimaryColor.withOpacity(0.9)))),
            Icon(Icons.chevron_right, color: kPrimaryColor.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSurfaceColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kPrimaryColor.withOpacity(0.04)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _insightRow('Playlists', '124')),
                      Expanded(child: _insightRow('Followers', '9.2K')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _insightRow('Hours', '1,230')),
                      Expanded(child: _insightRow('Liked', '3,412')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Add / Share Playlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 10,
              shadowColor: kAccentColor.withOpacity(0.18),
            ),
          ),
          const SizedBox(height: 18),
          Text('Utilities', style: TextStyle(color: kPrimaryColor.withOpacity(0.9), fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _utilityLink('Song History', Icons.history),
          _utilityLink('Recently Downloaded', Icons.file_download),
          _utilityLink('Recently Added', Icons.new_releases),
        ],
      ),
    );
  }
}
