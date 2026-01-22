import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool privateSession = false;
  bool showListeningActivity = true;
  bool personalizedAds = true;
  bool dataCollection = true;
  bool explicitContent = true;

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
          'Privacy',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        physics: const BouncingScrollPhysics(),
        children: [
          _sectionTitle('Listening Privacy'),
          _toggleTile(
            title: 'Private Session',
            subtitle:
            'Your listening activity will not affect recommendations',
            value: privateSession,
            onChanged: (v) => setState(() => privateSession = v),
          ),
          _toggleTile(
            title: 'Show Listening Activity',
            subtitle: 'Share what you’re listening to with followers',
            value: showListeningActivity,
            onChanged: (v) => setState(() => showListeningActivity = v),
          ),

          const SizedBox(height: 24),
          _sectionTitle('Data & Personalization'),
          _toggleTile(
            title: 'Personalized Recommendations',
            subtitle: 'Use listening data to improve music suggestions',
            value: dataCollection,
            onChanged: (v) => setState(() => dataCollection = v),
          ),
          _toggleTile(
            title: 'Personalized Ads',
            subtitle: 'Show ads based on your listening habits',
            value: personalizedAds,
            onChanged: (v) => setState(() => personalizedAds = v),
          ),

          const SizedBox(height: 24),
          _sectionTitle('Content Control'),
          _toggleTile(
            title: 'Allow Explicit Content',
            subtitle: 'Play songs marked as explicit',
            value: explicitContent,
            onChanged: (v) => setState(() => explicitContent = v),
          ),

          const SizedBox(height: 24),
          _sectionTitle('Account & Data'),
          _actionTile(
            title: 'Download Your Data',
            subtitle: 'Get a copy of your listening history',
            icon: Icons.download,
          ),
          _actionTile(
            title: 'Clear Listening History',
            subtitle: 'Remove all past listening activity',
            icon: Icons.delete_outline,
            destructive: true,
          ),
          _actionTile(
            title: 'Privacy Policy',
            subtitle: 'Read how we handle your data',
            icon: Icons.open_in_new,
          ),
        ],
      ),
    );
  }

  /* ───────────────────────── UI COMPONENTS ───────────────────────── */

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha :0.85),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _glassTile(
      child: Row(
        children: [
          Expanded(
            child: _tileText(title, subtitle),
          ),
          Switch(
            value: value,
            activeThumbColor: kAccentColor,
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white12,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    bool destructive = false,
  }) {
    return _glassTile(
      child: InkWell(
        onTap: () {},
        child: Row(
          children: [
            Icon(
              icon,
              color: destructive
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha :0.9),
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _tileText(
                title,
                subtitle,
                destructive: destructive,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha :0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileText(
      String title,
      String subtitle, {
        bool destructive = false,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: destructive ? Colors.redAccent : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha :0.6),
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _glassTile({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha :0.10),
                  Colors.white.withValues(alpha :0.03),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha :0.18),
                width: 0.8,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
