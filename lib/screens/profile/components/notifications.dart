import 'dart:ui';
import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const BouncingScrollPhysics(),
        children: const [
          _NotificationTile(
            icon: Icons.favorite,
            title: 'Song Liked',
            message: 'You liked “Blinding Lights”',
            time: '2 min ago',
            highlight: true,
          ),
          _NotificationTile(
            icon: Icons.album,
            title: 'New Album',
            message: 'The Weeknd released a new album',
            time: '1 hr ago',
          ),
          _NotificationTile(
            icon: Icons.podcasts,
            title: 'New Podcast Episode',
            message: 'TechTalks – Episode 42 is live',
            time: '3 hrs ago',
          ),
          _NotificationTile(
            icon: Icons.download_done,
            title: 'Download Complete',
            message: 'Playlist “Chill Vibes” downloaded',
            time: 'Yesterday',
          ),
          _NotificationTile(
            icon: Icons.star,
            title: 'Weekly Mix Ready',
            message: 'Your personalized mix is ready',
            time: '2 days ago',
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── TILE ───────────────────────── */

class _NotificationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String time;
  final bool highlight;

  const _NotificationTile({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: highlight
                    ? [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.06),
                ]
                    : [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _icon(),
                const SizedBox(width: 14),
                Expanded(child: _content()),
                const SizedBox(width: 8),
                _time(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _icon() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _time() {
    return Text(
      time,
      style: TextStyle(
        color: Colors.white.withOpacity(0.4),
        fontSize: 11,
      ),
    );
  }
}
