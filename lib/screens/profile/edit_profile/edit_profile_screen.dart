import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sangeet/constants.dart';
import '../../../services/user_profile_service.dart';
import '../../podcast/components/section_title.dart';
import 'components/glass_field.dart';
import 'components/glass_tile.dart';
import 'components/edit_profile_stats.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String? initialImagePath;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialEmail,
    this.initialImagePath,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _bioCtrl;
  late final ScrollController _scrollController;

  String? _profileImagePath;
  bool _isPublicProfile = true;
  bool _showActivity = true;
  bool _allowCollaboration = false;

  late AnimationController _saveAnimController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // Initialize with passed values
    _nameCtrl = TextEditingController(text: widget.initialName);
    _emailCtrl = TextEditingController(text: widget.initialEmail);
    _bioCtrl = TextEditingController(text: 'Music is life 🎵');
    _profileImagePath = widget.initialImagePath;

    _saveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final profileData = await UserProfileService.loadUserProfile();
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _bioCtrl.text = profileData.bio;
        _isPublicProfile = prefs.getBool('is_public_profile') ?? true;
        _showActivity = prefs.getBool('show_activity') ?? true;
        _allowCollaboration = prefs.getBool('allow_collaboration') ?? false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    _saveAnimController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImagePickerSheet(),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() => _profileImagePath = pickedFile.path);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    _saveAnimController.forward();

    await Future.delayed(const Duration(milliseconds: 800));

    // Save using UserProfileService (handles both SecureStorage and SharedPreferences)
    await UserProfileService.updateUserProfile(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      photoUrl: _profileImagePath,
      bio: _bioCtrl.text.trim(),
    );

    // Save privacy preferences to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_public_profile', _isPublicProfile);
    await prefs.setBool('show_activity', _showActivity);
    await prefs.setBool('allow_collaboration', _allowCollaboration);


    if (mounted) {
      _saveAnimController.reverse();
      Navigator.pop(context, true); // Return true to indicate profile was updated
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
            icon: const Icon(
                Icons.arrow_back_ios_new, size: 16, color: kPrimaryColor),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
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
                      color: _saveAnimController.value > 0.5
                          ? kTextColorDark
                          : kAccentColor,
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
                  kAccentColor.withValues(alpha :0.12),
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
                _buildEditProfileAvatar(),
                const SizedBox(height: 15),
                _buildStats(),
                const SizedBox(height: 24),

                SectionTitle('Personal Information'),
                const SizedBox(height: 8),
                GlassField(
                  label: 'Display Name',
                  controller: _nameCtrl,
                  icon: Icons.person_outline,
                ),
                GlassField(
                  label: 'Email',
                  controller: _emailCtrl,
                  icon: Icons.email_outlined,
                ),
                GlassField(
                  label: 'Bio',
                  controller: _bioCtrl,
                  icon: Icons.edit_note_outlined,
                  maxLines: 2,
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
                    activeThumbColor: kAccentColor,
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
                    activeThumbColor: kAccentColor,
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
                    activeThumbColor: kAccentColor,
                    inactiveThumbColor: const Color(0xFFBDBDBD),
                    inactiveTrackColor: const Color(0x33BDBDBD),
                    onChanged: (v) => setState(() => _allowCollaboration = v),
                  ),
                ),

                const SizedBox(height: 20),
                SectionTitle('Account'),
                const SizedBox(height: 8),

                GlassTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  trailing: const Icon(
                      Icons.chevron_right, color: Color(0x66FFFFFF), size: 20),
                  onTap: () {},
                ),

                GlassTile(
                  icon: Icons.devices_outlined,
                  title: 'Connected Devices',
                  subtitle: '3 active devices',
                  trailing: const Icon(
                      Icons.chevron_right, color: Color(0x66FFFFFF), size: 20),
                  onTap: () {},
                ),

                const SizedBox(height: 20),
                SectionTitle('Preferences'),
                const SizedBox(height: 8),

                GlassTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  trailing: const Icon(
                      Icons.chevron_right, color: Color(0x66FFFFFF), size: 20),
                  onTap: () {},
                ),

                GlassTile(
                  icon: Icons.high_quality_outlined,
                  title: 'Audio Quality',
                  subtitle: 'High (320 kbps)',
                  trailing: const Icon(
                      Icons.chevron_right, color: Color(0x66FFFFFF), size: 20),
                  onTap: () {},
                ),

                GlassTile(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: 'English',
                  trailing: const Icon(
                      Icons.chevron_right, color: Color(0x66FFFFFF), size: 20),
                  onTap: () {},
                ),

                const SizedBox(height: 24),
                GlassTile(
                  icon: Icons.delete_outline,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account and data',
                  trailing: const Icon(
                      Icons.chevron_right, color: Color(0x66FF5252), size: 20),
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

  Widget _buildEditProfileAvatar() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _profileImagePath == null
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
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                image: _profileImagePath != null
                    ? DecorationImage(
                  image: _profileImagePath!.startsWith('http')
                      ? NetworkImage(_profileImagePath!)
                      : FileImage(File(_profileImagePath!)),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: _profileImagePath == null
                  ? Center(
                child: Text(
                  _nameCtrl.text.isNotEmpty
                      ? _nameCtrl.text[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kAccentColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: kBackgroundColor,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha :0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    // Use the dynamic EditProfileStats widget which fetches real playlist counts
    return const Center(
      child: EditProfileStats(),
    );
  }
}

// Image Picker Bottom Sheet
class _ImagePickerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          decoration: BoxDecoration(
            color: kBackgroundColor.withValues(alpha :0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha :0.1),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha :0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha :0.9),
                ),
              ),
              const SizedBox(height: 24),
              _PickerOption(
                icon: Icons.camera_alt_rounded,
                label: 'Take Photo',
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 12),
              _PickerOption(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Picker Option Widget
class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha :0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha :0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kAccentColor.withValues(alpha :0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: kAccentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha :0.3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
