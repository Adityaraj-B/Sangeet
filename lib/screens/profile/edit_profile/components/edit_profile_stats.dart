import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/services/playlist_service.dart';

class EditProfileStats extends StatefulWidget {
  const EditProfileStats({super.key});

  @override
  State<EditProfileStats> createState() => _EditProfileStatsState();
}

class _EditProfileStatsState extends State<EditProfileStats> {
  int _playlistCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
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
    if (_isLoading) {
      return const SizedBox(
        height: 50,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: kPrimaryColor,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _Stat('0', 'Followers'),
        const _Divider(),
        const _Stat('0', 'Following'),
        const _Divider(),
        _Stat('$_playlistCount', 'Playlists'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: kPrimaryColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: kMutedTextColor,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0x1AFFFFFF),
    );
  }
}
