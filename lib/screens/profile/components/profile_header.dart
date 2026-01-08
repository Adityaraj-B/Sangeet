import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Avatar with gradient border
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
                color: kPrimaryColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: const Color(0xFF1a1a1a),
              backgroundImage: AssetImage(
                'assets/images/Gemini_Generated_Image_wt48s7wt48s7wt48(1).png',
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Username - NO decoration
        const Text(
          'Adityaraj',
          style: TextStyle(
            fontSize: 26,
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),

        // Bio - NO decoration
        Text(
          'Music is life 🎶',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 20),

        // Edit Profile Button
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: BorderSide(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
            ),
          ),
          child: const Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}