import 'package:flutter/material.dart';
import '../../data/dummy_data.dart';
import '../../models/song.dart';
import 'components/audio_quality.dart';
import 'components/equalizer.dart';
import 'components/liked_songs.dart';
import 'components/notifications.dart';
import 'components/privacy.dart';
import 'components/profile_header.dart';
import 'components/profile_stats.dart';
import 'components/profile_section_title.dart';
import 'components/profile_tile.dart';
import 'components/logout_tile.dart';

class ProfileBody extends StatefulWidget {
  final ValueChanged<Song> onPlaySong;

  const ProfileBody({
    super.key,
    required this.onPlaySong,
  });

  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final List<Animation<double>> _fade = [];
  final List<Animation<Offset>> _slide = [];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    for (int i = 0; i < 6; i++) {
      _fade.add(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(i * 0.1, 0.6 + i * 0.1, curve: Curves.easeOut),
        ),
      );

      _slide.add(
        Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(i * 0.1, 0.6 + i * 0.1, curve: Curves.easeOutCubic),
          ),
        ),
      );
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _section(int i, Widget child) {
    if (i >= _fade.length || i >= _slide.length) return child;

    return FadeTransition(
      opacity: _fade[i],
      child: SlideTransition(position: _slide[i], child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFC48E1B),
              Color(0xFF0b0b0b),
            ],
            stops: [0.0, 0.6],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -1.1),
              radius: 2.0,
              colors: [
                Colors.white.withOpacity(0.04),
                Colors.transparent,
              ],
            ),
        ),
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 70, 20, 40),
        physics: const BouncingScrollPhysics(),
        children: [
          _section(0, const ProfileHeader()),
          const SizedBox(height: 28),

          _section(1, const ProfileStats()),
          const SizedBox(height: 36),

          _section(
            2,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProfileSectionTitle(title: 'Your Library'),
                const SizedBox(height: 8),
                ProfileTile(
                  icon: Icons.favorite,
                  title: 'Liked Songs',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LikedSongsScreen(
                          likedSongs: DummyData.likedSongs,
                          onPlaySong: widget.onPlaySong,
                        ),
                      ),
                    );
                  },
                ),

                const ProfileTile(icon: Icons.queue_music, title: 'Playlists'),
                const ProfileTile(icon: Icons.download, title: 'Downloads'),
                const ProfileTile(icon: Icons.history, title: 'Recently Played'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _section(
            3,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProfileSectionTitle(title: 'Settings'),
                const SizedBox(height: 8),
                ProfileTile(
                  icon: Icons.music_note,
                  title: 'Audio Quality',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AudioQualityScreen(),
                      ),
                    );
                  },
                ),
                ProfileTile(
                  icon: Icons.equalizer,
                  title: 'Equalizer',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EqualizerGraphScreen(),
                      ),
                    );
                  },
                ),
                const ProfileTile(icon: Icons.dark_mode, title: 'Theme'),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _section(
            4,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ProfileSectionTitle(title: 'Account'),
                const SizedBox(height: 8),
                ProfileTile(icon: Icons.notifications, title: 'Notifications',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                          builder: (_) => const NotificationScreen(),
                    ),
                  );
                },),
                ProfileTile(
                  icon: Icons.lock,
                  title: 'Privacy',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PrivacyScreen(),
                      ),
                    );
                  },
                ),

              ],
            ),
          ),
          const SizedBox(height: 28),

          _section(5, const LogoutTile()),
        ],
      ),
    )
    );
  }
}
