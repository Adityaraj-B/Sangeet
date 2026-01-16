import 'package:flutter/material.dart';

class UserProfile {
  final String name;
  final String username;
  final String imagePath;
  final String bio;
  final bool isPremium;

  const UserProfile({
    required this.name,
    required this.username,
    required this.imagePath,
    required this.bio,
    required this.isPremium,
  });

  UserProfile copyWith({
    String? name,
    String? username,
    String? imagePath,
    String? bio,
    bool? isPremium,
  }) {
    return UserProfile(
      name: name ?? this.name,
      username: username ?? this.username,
      imagePath: imagePath ?? this.imagePath,
      bio: bio ?? this.bio,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}

final ValueNotifier<UserProfile> userProfile =
ValueNotifier<UserProfile>(
  const UserProfile(
    name: 'Adityaraj',
    username: 'adityaraj',
    bio: 'Music is life 🎶',
    imagePath: 'assets/images/Gemini_Generated_Image_wt48s7wt48s7wt48(1).png',
    isPremium: true,
  ),
);
