import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/song.dart';
import '../profile/profile_body.dart';
import '../recent/recent_screen.dart';
import '../insights/insights_screen.dart';
import 'components/library_playlist.dart';
import 'components/top_bar.dart';
import 'components/library_section.dart';

class LibraryBody extends StatefulWidget {
  final ValueChanged<Song> onPlaySong;

  const LibraryBody({
    super.key,
    required this.onPlaySong,
  });

  @override
  State<LibraryBody> createState() => _LibraryBodyState();
}

class _LibraryBodyState extends State<LibraryBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleProfileTap() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileBody(onPlaySong: widget.onPlaySong),
      ),
    );
    // Reload the screen to refresh the TopBar with updated profile data
    if (mounted) {
      setState(() {});
    }
  }

  void _handleInsightsTap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const InsightsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: TopBar(
                animation: _animController,
                onProfileTap: _handleProfileTap,
                onInsightsTap: _handleInsightsTap,
                onNotificationsTap: () {},
                notificationsCount: 2,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // SliverToBoxAdapter(
            //   child: LibraryFilters(
            //     onPlaySong: widget.onPlaySong,
            //   ),
            // ),

            //const SliverToBoxAdapter(child: SizedBox(height: 24)),

            SliverToBoxAdapter(
              child: LibraryPlaylistsSection(
                onPlaySong: widget.onPlaySong,
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 5)),

            SliverToBoxAdapter(
              child:// Replace LibraryGenericSection with:
              RecentlyPlayedSection(
                onPlaySong: widget.onPlaySong,
                onSeeAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecentlyPlayedScreen(
                        onPlaySong: widget.onPlaySong,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // const SliverToBoxAdapter(
            //   child: LibraryGenericSection(title: "Made for You"),
            // ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}
