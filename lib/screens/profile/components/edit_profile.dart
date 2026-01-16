import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import '../../../models/user_profile.dart';
import '../../podcast/components/section_title.dart';
import '../edit_profile/components/edit_profile_avatar.dart';
import '../edit_profile/components/edit_profile_stats.dart';
import '../edit_profile/components/glass_field.dart';
import '../edit_profile/components/glass_tile.dart';
import '../edit_profile/components/premium_card.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _bioCtrl;
  bool _isPremium = false;
  bool _isPublicProfile = true;
  bool _showActivity = true;
  bool _allowCollaboration = false;
  late final ScrollController _scrollController;

  late AnimationController _saveAnimController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final profile = userProfile.value;
    _nameCtrl = TextEditingController(text: profile.name);
    _usernameCtrl = TextEditingController(text: profile.username);
    _bioCtrl = TextEditingController(text: 'Music is life 🎵');
    _isPublicProfile = true;
    _showActivity = true;
    _allowCollaboration = false;

    _saveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _saveAnimController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    _saveAnimController.forward();

    await Future.delayed(const Duration(milliseconds: 800));

    userProfile.value = userProfile.value.copyWith(
      name: _nameCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      isPremium: _isPremium,
    );

    if (mounted) {
      _saveAnimController.reverse();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: kPrimaryColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: kPrimaryColor,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedBuilder(
              animation: _saveAnimController,
              builder: (context, child) {
                return TextButton(
                  onPressed: _isSaving ? null : _save,
                  style: TextButton.styleFrom(
                    backgroundColor: Color.lerp(
                      Colors.transparent,
                      kAccentColor,
                      _saveAnimController.value,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kTextColorDark,
                    ),
                  )
                      : Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      color: _saveAnimController.value > 0.5 ? kTextColorDark : kAccentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Subtle gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kAccentColor.withOpacity(0.12),
                  kBackgroundColor,
                ],
                stops: const [0.0, 0.55],
              ),
            ),
          ),

          SafeArea(
            child: ListView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const SizedBox(height: 16),
                EditProfileAvatar(imagePath: 'assets/images/Gemini_Generated_Image_wt48s7wt48s7wt48(1).png',),
                const SizedBox(height: 15),
                EditProfileStats(),
                const SizedBox(height: 24),

                SectionTitle('Personal Information'),
                const SizedBox(height: 8),
                GlassField(
                  label: 'Display Name',
                  controller: _nameCtrl,
                  icon: Icons.person_outline,
                ),
                GlassField(
                  label: 'Username',
                  controller: _usernameCtrl,
                  icon: Icons.alternate_email,
                ),
                GlassField(
                  label: 'Bio',
                  controller: _bioCtrl,
                  icon: Icons.edit_note_outlined,
                  maxLines: 2,
                ),

                const SizedBox(height: 20),
                SectionTitle('Subscription'),
                const SizedBox(height: 8),
                PremiumCard(
                  isPremium: _isPremium,
                  onChanged: (v) => setState(() => _isPremium = v),
                ),
                const SizedBox(height: 20),
                SectionTitle('Privacy'),
                const SizedBox(height: 8),

                GlassTile(
                  icon: Icons.public_outlined,
                  title: 'Public Profile',
                  subtitle: 'Anyone can see your profile',
                  trailing: Switch(
                    value: _isPublicProfile,
                    activeColor: kAccentColor,
                    inactiveThumbColor: const Color(0xFFBDBDBD),
                    inactiveTrackColor: const Color(0x33BDBDBD),
                    onChanged: (v) => setState(() => _isPublicProfile = v),
                  ),
                ),

                GlassTile(
                  icon: Icons.music_note_outlined,
                  title: 'Show Listening Activity',
                  subtitle: 'Let friends see what you\'re listening to',
                  trailing: Switch(
                    value: _showActivity,
                    activeColor: kAccentColor,
                    inactiveThumbColor: const Color(0xFFBDBDBD),
                    inactiveTrackColor: const Color(0x33BDBDBD),
                    onChanged: (v) => setState(() => _showActivity = v),
                  ),
                ),

                GlassTile(
                  icon: Icons.people_outline,
                  title: 'Collaborative Playlists',
                  subtitle: 'Allow friends to add songs',
                  trailing: Switch(
                    value: _allowCollaboration,
                    activeColor: kAccentColor,
                    inactiveThumbColor: const Color(0xFFBDBDBD),
                    inactiveTrackColor: const Color(0x33BDBDBD),
                    onChanged: (v) => setState(() => _allowCollaboration = v),
                  ),
                ),

                const SizedBox(height: 20),
                SectionTitle('Account'),
                const SizedBox(height: 8),

                GlassTile(
                  icon: Icons.email_outlined,
                  title: 'Email Address',
                  subtitle: 'user@example.com',
                  trailing: const Icon(Icons.chevron_right, color: Color(0x66FFFFFF), size: 20),
                  onTap: () {},
                ),

                GlassTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  trailing: const Icon(Icons.chevron_right, color: Color(0x66FFFFFF), size: 20),
                  onTap: () {},
                ),

                GlassTile(
                  icon: Icons.devices_outlined,
                  title: 'Connected Devices',
                  subtitle: '3 active devices',
                  trailing: const Icon(Icons.chevron_right, color: Color(0x66FFFFFF), size: 20),
                  onTap: () {},
                ),

                const SizedBox(height: 20),
                SectionTitle('Preferences'),
                const SizedBox(height: 8),

                GlassTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  trailing: const Icon(Icons.chevron_right, color: Color(0x66FFFFFF), size: 20),
                  onTap: () {},
                ),

                GlassTile(
                  icon: Icons.high_quality_outlined,
                  title: 'Audio Quality',
                  subtitle: 'High (320 kbps)',
                  trailing: const Icon(Icons.chevron_right, color: Color(0x66FFFFFF), size: 20),
                  onTap: () {},
                ),

                GlassTile(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: 'English',
                  trailing: const Icon(Icons.chevron_right, color: Color(0x66FFFFFF), size: 20),
                  onTap: () {},
                ),

                const SizedBox(height: 24),
                GlassTile(
                  icon: Icons.delete_outline,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account and data',
                  trailing: const Icon(Icons.chevron_right, color: Color(0x66FF5252), size: 20),
                  onTap: () {},
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}