import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';
import '../../models/song.dart';
import '../../services/auth.dart';
import '../../services/playlist_service.dart';
import '../sign_in/sign_in_body.dart';
import '../playlist/components/playlist_screen.dart';
import '../recent/recent_screen.dart';
import 'components/audio_quality.dart';
import 'components/equalizer.dart';
import 'components/liked_songs.dart';
import 'components/notifications.dart';
import 'components/privacy.dart';
import 'edit_profile/edit_profile_screen.dart';

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
  late final Animation<double> _fadeIn;

  String _userName = 'User';
  String _userEmail = 'user@email.com';
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'User';
      _userEmail = prefs.getString('user_email') ?? 'user@email.com';
      _profileImagePath = prefs.getString('profile_image');
    });
  }


  void _navigateToEditProfile() async {
    HapticFeedback.lightImpact();

    // Navigate to edit profile and wait for result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          initialName: _userName,
          initialEmail: _userEmail,
          initialImagePath: _profileImagePath,
        ),
      ),
    );

    // Reload data if profile was updated
    if (result == true && mounted) {
      await _loadUserData();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigate(Widget page) {
    HapticFeedback.lightImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildHeader(),
            SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      stretch: true,
      backgroundColor: kBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: _ProfileHeader(
          key: ValueKey(_profileImagePath ?? 'no-image'),
          userName: _userName,
          userEmail: _userEmail,
          profileImagePath: _profileImagePath,
          onAvatarTap: _navigateToEditProfile,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            color: kBackgroundColor.withValues(alpha :0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha :0.08),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildHandle(),
              const SizedBox(height: 28),
              _buildQuickActions(),
              const SizedBox(height: 36),
              _buildSectionLabel('Your Library'),
              const SizedBox(height: 12),
              _buildLibrarySection(),
              const SizedBox(height: 32),
              _buildSectionLabel('Preferences'),
              const SizedBox(height: 12),
              _buildSettingsSection(),
              const SizedBox(height: 36),
              _buildLogoutButton(),
              const SizedBox(height: 32),
              _buildVersionInfo(),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha :0.15),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha :0.5),
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionButton(
              icon: Icons.edit_rounded,
              label: 'Edit Profile',
              onTap: _navigateToEditProfile, // Navigate to edit profile
            ),
          ),
          // const SizedBox(width: 14),
          // Expanded(
          //   child: _QuickActionButton(
          //     icon: Icons.play_arrow_rounded,
          //     label: 'Play All',
          //     isPrimary: true,
          //     onTap: () => HapticFeedback.lightImpact(),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildLibrarySection() {
    return _GlassCard(
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.favorite_rounded,
            label: 'Liked Songs',
            iconColor: const Color(0xFFFF6B8A),
            onTap: () => _navigate(
              LikedSongsScreen(onPlaySong: widget.onPlaySong),
            ),
          ),
          _buildItemDivider(),
          _MenuItem(
            icon: Icons.album_rounded,
            label: 'Playlists',
            iconColor: kAccentColor,
            onTap: () => _navigate(
              PlaylistsScreen(onPlaySong: widget.onPlaySong),
            ),
          ),
          _buildItemDivider(),
          _MenuItem(
            icon: Icons.history_rounded,
            label: 'Recently Played',
            iconColor: const Color(0xFFFFB86B),
            onTap: () => _navigate(
              RecentlyPlayedScreen(onPlaySong: widget.onPlaySong),
            ),
          ),
          // _buildItemDivider(),
          // _MenuItem(
          //   icon: Icons.download_rounded,
          //   label: 'Downloads',
          //   iconColor: const Color(0xFF6BFFB8),
          //   onTap: () {},
          // ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return _GlassCard(
      child: Column(
        children: [
          _MenuItem(
            icon: Icons.graphic_eq_rounded,
            label: 'Audio Quality',
            iconColor: const Color(0xFF8B6BFF),
            onTap: () => _navigate(const AudioQualityScreen()),
          ),
          _buildItemDivider(),
          _MenuItem(
            icon: Icons.tune_rounded,
            label: 'Equalizer',
            iconColor: const Color(0xFF6BB8FF),
            onTap: () => _navigate(const EqualizerGraphScreen()),
          ),
          _buildItemDivider(),
          _MenuItem(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            iconColor: const Color(0xFFFFD66B),
            onTap: () => _navigate(const NotificationScreen()),
          ),
          _buildItemDivider(),
          _MenuItem(
            icon: Icons.shield_outlined,
            label: 'Privacy',
            iconColor: const Color(0xFF6BFFD6),
            onTap: () => _navigate(const PrivacyScreen()),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 64),
      child: Container(
        height: 0.5,
        color: Colors.white.withValues(alpha :0.06),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.white.withValues(alpha :0.05),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () async {
                HapticFeedback.mediumImpact();
                // Show confirmation dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => const _LogoutConfirmationDialog(),
                );

                if (confirm == true && mounted) {
                  // Perform logout
                  await AuthService.signOut();
                  if (!mounted) return;
                  // Navigate to sign in screen and clear navigation stack
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    SignInBody.routeName,
                    (route) => false,
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha :0.08),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Log out',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha :0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionInfo() {
    return Column(
      children: [
        Text(
          'Sangeet',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kAccentColor.withValues(alpha :0.6),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version 1.0.0',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha :0.25),
          ),
        ),
      ],
    );
  }
}

// Profile Header Widget
class _ProfileHeader extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String? profileImagePath;
  final VoidCallback onAvatarTap;

  const _ProfileHeader({
    super.key,
    required this.userName,
    required this.userEmail,
    this.profileImagePath,
    required this.onAvatarTap,
  });

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  int _playlistCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileStats();
  }

  Future<void> _fetchProfileStats() async {
    try {
      // Fetch real playlist count
      final playlistService = PlaylistService.instance;
      final playlistSnapshot = await playlistService.playlistsStream().first;

      if (mounted) {
        setState(() {
          _playlistCount = playlistSnapshot.docs.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Base gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kAccentColor.withValues(alpha :0.8),
                kAccentColor.withValues(alpha :0.4),
                kBackgroundColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Liquid glass orbs
        Positioned(
          top: -60,
          right: -40,
          child: _GlassOrb(
            size: 200,
            color: kAccentColor.withValues(alpha :0.3),
          ),
        ),
        Positioned(
          top: 80,
          left: -60,
          child: _GlassOrb(
            size: 150,
            color: Colors.white.withValues(alpha :0.1),
          ),
        ),

        // Blur overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  kBackgroundColor.withValues(alpha :0.5),
                  kBackgroundColor,
                ],
                stops: const [0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                _buildAvatar(),
                const SizedBox(height: 20),
                _buildName(),
                const SizedBox(height: 6),
                _buildEmail(),
                const SizedBox(height: 20),
                _buildStats(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: widget.onAvatarTap,
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.profileImagePath == null
                  ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kAccentColor.withValues(alpha :0.8),
                  kAccentColor.withValues(alpha :0.4),
                ],
              )
                  : null,
              border: Border.all(
                color: Colors.white.withValues(alpha :0.2),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: kAccentColor.withValues(alpha :0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
              image: widget.profileImagePath != null
                  ? DecorationImage(
                image: widget.profileImagePath!.startsWith('http')
                    ? NetworkImage(widget.profileImagePath!) as ImageProvider
                    : FileImage(File(widget.profileImagePath!)),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: widget.profileImagePath == null
                ? Center(
              child: Text(
                widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            )
                : null,
          ),
          // Camera icon overlay
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: kAccentColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: kBackgroundColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha :0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildName() {
    return Text(
      widget.userName,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildEmail() {
    return Text(
      widget.userEmail,
      style: TextStyle(
        fontSize: 14,
        color: Colors.white.withValues(alpha :0.6),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildStats() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha :0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha :0.1),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 50,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _StatItem(count: '0', label: 'Followers'),
                    _buildStatDivider(),
                    const _StatItem(count: '0', label: 'Following'),
                    _buildStatDivider(),
                    _StatItem(count: '$_playlistCount', label: 'Playlists'),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white.withValues(alpha :0.15),
    );
  }
}


// Glass Orb Widget
class _GlassOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlassOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha :0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// Stat Item Widget
class _StatItem extends StatelessWidget {
  final String count;
  final String label;

  const _StatItem({
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha :0.5),
          ),
        ),
      ],
    );
  }
}

// Quick Action Button Widget
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: isPrimary ? kAccentColor : Colors.white.withValues(alpha :0.08),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPrimary
                      ? Colors.transparent
                      : Colors.white.withValues(alpha :0.08),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isPrimary
                        ? kBackgroundColor
                        : Colors.white.withValues(alpha :0.9),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPrimary
                          ? kBackgroundColor
                          : Colors.white.withValues(alpha :0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Glass Card Widget
class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha :0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha :0.08),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Menu Item Widget
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color iconColor;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha :0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha :0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.white.withValues(alpha :0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Logout Confirmation Dialog
class _LogoutConfirmationDialog extends StatelessWidget {
  const _LogoutConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: kBackgroundColor.withValues(alpha :0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha :0.1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirm Logout',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha :0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to log out?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha :0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _DialogButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context, false),
                    ),
                    _DialogButton(
                      label: 'Logout',
                      isDestructive: true,
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Dialog Button Widget
class _DialogButton extends StatelessWidget {
  final String label;
  final bool isDestructive;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: isDestructive ? const Color(0xFFA62D2D) : null,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDestructive ? Colors.transparent : Colors.white.withValues(alpha :0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDestructive ? Colors.white : Colors.white.withValues(alpha :0.9),
          ),
        ),
      ),
    );
  }
}
