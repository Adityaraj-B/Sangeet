import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/services/playlist_service.dart';
import 'package:sangeet/services/recently_played.dart';
import 'package:sangeet/services/like_service.dart';

class ProfileStats extends StatefulWidget {
  const ProfileStats({super.key});

  @override
  State<ProfileStats> createState() => _ProfileStatsState();
}

class _ProfileStatsState extends State<ProfileStats> {
  int _playlistCount = 0;
  int _totalSongs = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Get playlist count
      final playlistService = PlaylistService.instance;
      final playlistSnapshot = await playlistService.playlistsStream().first;
      final playlistCount = playlistSnapshot.docs.length;

      // Get total unique songs from recently played and liked songs
      final recentService = RecentlyPlayedService();
      final likeService = LikeService();
      await likeService.load();

      final recentSongs = await recentService.getRecentlyPlayed(limit: 1000);
      final likedSongs = likeService.likedSongs;

      // Combine and get unique song IDs
      final Set<String> uniqueSongIds = {};
      for (var song in recentSongs) {
        uniqueSongIds.add(song.id);
      }
      for (var song in likedSongs) {
        uniqueSongIds.add(song.id);
      }

      if (mounted) {
        setState(() {
          _playlistCount = playlistCount;
          _totalSongs = uniqueSongIds.length;
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 0.8,
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 70,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    const _StatItem(value: '0', label: 'Followers'),
                    _GlassDivider(),
                    const _StatItem(value: '0', label: 'Following'),
                    _GlassDivider(),
                    _StatItem(value: '$_playlistCount', label: 'Playlists'),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha :0.02),
            Colors.white.withValues(alpha :0.18),
            Colors.white.withValues(alpha :0.02),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.4,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'PlayfairDisplay',
            color: Colors.white.withValues(alpha :0.45),
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
