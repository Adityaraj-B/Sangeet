import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import 'components/profile_header.dart';
import 'components/profile_stats.dart';
import 'components/profile_section_title.dart';
import 'components/profile_tile.dart';
import 'components/logout_tile.dart';

class ProfileBody extends StatefulWidget {
  const ProfileBody({super.key});

  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final List<Animation<double>> _fade = [];
  final List<Animation<Offset>> _slide = [];

  Color _profileColor = Colors.black;

  static const String _profileImage =
      'assets/images/3397a35784ed8e49bfc2521d25a176fa.jpg';

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
    _extractProfileColor();
  }

  Future<void> _extractProfileColor() async {
    final data = await rootBundle.load(_profileImage);
    final image = await decodeImageFromList(data.buffer.asUint8List());

    final palette = await PaletteGenerator.fromImage(
      image,
      maximumColorCount: 8,
    );

    final color =
        palette.vibrantColor?.color ??
            palette.dominantColor?.color ??
            Colors.deepPurple;

    if (!mounted) return;

    final adjusted = HSLColor.fromColor(color)
        .withLightness(0.45)
        .withSaturation(0.6)
        .toColor();

    setState(() => _profileColor = adjusted);
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _profileColor.withOpacity(0.45),
            Colors.black,
          ],
          stops: const [0.0, 0.6],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.85),
            radius: 1.4,
            colors: [
              _profileColor.withOpacity(0.35),
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
                children: const [
                  ProfileSectionTitle(title: 'Your Library'),
                  SizedBox(height: 8),
                  ProfileTile(icon: Icons.favorite, title: 'Liked Songs'),
                  ProfileTile(icon: Icons.queue_music, title: 'Playlists'),
                  ProfileTile(icon: Icons.download, title: 'Downloads'),
                  ProfileTile(icon: Icons.history, title: 'Recently Played'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _section(
              3,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ProfileSectionTitle(title: 'Settings'),
                  SizedBox(height: 8),
                  ProfileTile(icon: Icons.music_note, title: 'Audio Quality'),
                  ProfileTile(icon: Icons.equalizer, title: 'Equalizer'),
                  ProfileTile(icon: Icons.dark_mode, title: 'Theme'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _section(
              4,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ProfileSectionTitle(title: 'Account'),
                  SizedBox(height: 8),
                  ProfileTile(icon: Icons.notifications, title: 'Notifications'),
                  ProfileTile(icon: Icons.lock, title: 'Privacy'),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _section(5, const LogoutTile()),
          ],
        ),
      ),
    );
  }
}
