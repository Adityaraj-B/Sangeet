import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import '../../../services/user_profile_service.dart';
import '../../profile/components/notifications.dart';

class TopBar extends StatefulWidget {
  final AnimationController animation;
  final VoidCallback? onProfileTap;
  final VoidCallback? onInsightsTap;
  final VoidCallback? onNotificationsTap;
  final int notificationsCount;

  const TopBar({
    required this.animation,
    this.onProfileTap,
    this.onInsightsTap,
    this.onNotificationsTap,
    this.notificationsCount = 0,
    super.key,
  });

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  String _userName = 'User';
  String _userEmail = 'user@email.com';
  String? _profileImagePath;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final profileData = await UserProfileService.loadUserProfile();
    if (mounted) {
      setState(() {
        _userName = profileData.name;
        _userEmail = profileData.email;
        _profileImagePath = profileData.photoUrl;
        _isPremium = profileData.isPremium;
      });
    }
  }

  String _getUsername() {
    return UserProfileService.getUsernameFromEmail(_userEmail);
  }

  @override
  void didUpdateWidget(TopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when widget updates (e.g., when returning from edit profile)
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 800;
    final horizontalPad = isWide ? 28.0 : 20.0;

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: widget.animation, curve: Curves.easeOut),
      axisAlignment: -1,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 18),
        child: Row(
          children: [
            // 1. Profile Picture (Left)
            GestureDetector(
              onTap: widget.onProfileTap,
              child: Container(
                key: ValueKey(_profileImagePath ?? 'no-library-profile-image'),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImagePath == null
                      ? LinearGradient(
                    colors: [
                      kAccentColor.withValues(alpha :0.8),
                      kAccentColor.withValues(alpha :0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  border: Border.all(
                    color: Colors.white.withValues(alpha :0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentColor.withValues(alpha :0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: _profileImagePath != null
                      ? DecorationImage(
                    image: _profileImagePath!.startsWith('http')
                        ? NetworkImage(_profileImagePath!) as ImageProvider
                        : FileImage(File(_profileImagePath!)),
                    fit: BoxFit.cover,
                  )
                      : null,
                ),
                child: _profileImagePath == null
                    ? Center(
                  child: Text(
                    _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
                    : null,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: InkWell(
                onTap: widget.onProfileTap,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isPremium)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 2.0),
                        child: Text(
                          "PREMIUM",
                          style: TextStyle(
                            color: kAccentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            fontFamily: 'Roboto',
                          ),
                        ),
                      ),

                    // Name
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Username Handle
                    Text(
                      '@${_getUsername()}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha :0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            Row(
              children: [
                IconButton(
                  onPressed: widget.onInsightsTap,
                  icon: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 28),
                  tooltip: 'Insights',
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: widget.onNotificationsTap ??
                              () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationScreen(),
                              ),
                            );
                          },
                      icon: const Icon(Icons.notifications, color: Colors.white, size: 28),
                    ),
                    if (widget.notificationsCount > 0)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0F0F1E), width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}