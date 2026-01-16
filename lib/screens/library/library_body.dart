import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import '../../components/navbar.dart';
import '../../models/song.dart';
import '../profile/profile_body.dart';
import 'components/library_section.dart';
import 'components/top_bar.dart';
import 'components/left_column.dart';

class LibCard {
  final String title;
  final String subtitle;
  final String image;
  LibCard(this.title, this.subtitle, this.image);
}

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
    with TickerProviderStateMixin {
  final ScrollController _vertical = ScrollController();
  final ScrollController _playlistsCtrl = ScrollController();
  final ScrollController _recentCtrl = ScrollController();
  final ScrollController _madeForCtrl = ScrollController();

  late final AnimationController _topBarAnim;
  final List<_LibrarySection> _sections = [];

  @override
  void initState() {
    super.initState();

    _topBarAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    final sample = List.generate(
      8,
          (i) => LibCard(
        'Item ${i + 1}',
        i.isEven ? 'Curated by Studio' : 'By Artist ${i + 1}',
        'https://picsum.photos/seed/library$i/800/800',
      ),
    );

    _sections.addAll([
      _LibrarySection('My Playlists', sample),
      _LibrarySection('Recently Played', sample.reversed.toList()),
      _LibrarySection(
        'Made For You',
        List.generate(
          6,
              (i) => LibCard(
            'Mix ${i + 1}',
            'Tailored Mix',
            'https://picsum.photos/seed/mix$i/800/800',
          ),
        ),
      ),
    ]);
  }

  @override
  void dispose() {
    _topBarAnim.dispose();
    _vertical.dispose();
    _playlistsCtrl.dispose();
    _recentCtrl.dispose();
    _madeForCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 880;
    final bottomInset = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      extendBody: true,
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isWide) const LeftColumn(),
                    if (isWide) const SizedBox(width: 18),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          controller: _vertical,
                          physics: const BouncingScrollPhysics(),
                          keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.only(bottom: bottomInset),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TopBar(
                                animation: _topBarAnim,
                                onProfileTap: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      transitionDuration: const Duration(milliseconds: 350),
                                      pageBuilder: (_, animation, __) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: ProfileBody(onPlaySong: widget.onPlaySong),
                                        );
                                      },
                                    ),
                                  );
                                },
                                notificationsCount: 2,
                              ),

                              const SizedBox(height: 12),

                              SectionHeaderAndList(
                                title: _sections[0].title,
                                controller: _playlistsCtrl,
                                items: _sections[0].items,
                                trailing: Text(
                                  'See all',
                                  style: TextStyle(
                                    color:
                                    kPrimaryColor.withOpacity(0.66),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              SectionHeaderAndList(
                                title: _sections[1].title,
                                controller: _recentCtrl,
                                items: _sections[1].items,
                              ),
                              const SizedBox(height: 20),

                              SectionHeaderAndList(
                                title: _sections[2].title,
                                controller: _madeForCtrl,
                                items: _sections[2].items,
                              ),
                              const SizedBox(height: 28),

                              Padding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  'Utilities',
                                  style: TextStyle(
                                    color:
                                    kPrimaryColor.withOpacity(0.9),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              Padding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                                child: Column(
                                  children: const [
                                    _UtilityTileGlass(
                                        'Song History',
                                        Icons.history),
                                    SizedBox(height: 10),
                                    _UtilityTileGlass(
                                        'Recently Downloaded',
                                        Icons.file_download),
                                    SizedBox(height: 10),
                                    _UtilityTileGlass(
                                        'Recently Added',
                                        Icons.new_releases),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UtilityTileGlass extends StatelessWidget {
  final String title;
  final IconData icon;

  const _UtilityTileGlass(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: kSurfaceColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border:
              Border.all(color: kPrimaryColor.withOpacity(0.04)),
            ),
            child: Row(
              children: [
                Icon(icon,
                    color: kPrimaryColor.withOpacity(0.72), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                        color:
                        kPrimaryColor.withOpacity(0.9)),
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: kPrimaryColor.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibrarySection {
  final String title;
  final List<LibCard> items;
  _LibrarySection(this.title, this.items);
}
