import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangeet/constants.dart';
import '../edit_profile/edit_profile_screen.dart';

class ProfileHeader extends StatefulWidget {
  const ProfileHeader({super.key});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  String _userName = 'User';
  String _userEmail = 'user@email.com';
  String _userBio = 'Music is life 🎵';
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'User';
      _userEmail = prefs.getString('user_email') ?? 'user@email.com';
      _userBio = prefs.getString('user_bio') ?? 'Music is life 🎵';
      _profileImagePath = prefs.getString('profile_image');
    });
  }

  Future<void> _navigateToEditProfile() async {
    HapticFeedback.lightImpact();

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

  String _getUsername() {
    // Extract username from email or use name
    if (_userEmail.contains('@')) {
      return _userEmail.split('@')[0];
    }
    return _userName.toLowerCase().replaceAll(' ', '');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [kPrimaryColor, kAccentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimaryColor.withValues(alpha :0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 52,
            backgroundColor: const Color(0xFF1a1a1a),
            backgroundImage: _profileImagePath != null
                ? (_profileImagePath!.startsWith('http')
                    ? NetworkImage(_profileImagePath!)
                    : FileImage(File(_profileImagePath!)))
                : null,
            child: _profileImagePath == null
                ? Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            )
                : null,
          ),
        ),

        const SizedBox(height: 20),

        // Name
        Text(
          _userName,
          style: const TextStyle(
            fontSize: 26,
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),

        const SizedBox(height: 6),

        // Username
        Text(
          '@${_getUsername()}',
          style: TextStyle(
            color: Colors.white.withValues(alpha :0.45),
            fontSize: 13,
            letterSpacing: 0.3,
            decoration: TextDecoration.none,
          ),
        ),

        const SizedBox(height: 8),

        // Bio
        Text(
          _userBio,
          style: TextStyle(
            color: Colors.white.withValues(alpha :0.5),
            fontFamily: 'PlayfairDisplay',
            fontSize: 14,
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 20),

        // Edit Button
        ElevatedButton(
          onPressed: _navigateToEditProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: BorderSide(
                color: Colors.white.withValues(alpha :0.15),
                width: 1.5,
              ),
            ),
          ),
          child: const Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}