import 'dart:ui';
import 'package:flutter/material.dart';
import '../../components/navbar.dart';
import '../../constants.dart';
import '../../models/podcasts.dart';
import '../../repositories/podcast_repo.dart';
import 'components/Glass_mini_player.dart';
import 'components/genre.dart';
import 'components/featured_hero .dart';
import 'components/section_title.dart';

class PodcastsScreen extends StatefulWidget {
  const PodcastsScreen({super.key});
  static const route = '/podcasts';

  @override
  State<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends State<PodcastsScreen> {
  final double _horizontalPadding = 16.0;

  late final List<String> genres;
  late final Map<String, List<Podcast>> genreMap;
  late final List<Podcast> featured;
  late final List<Podcast> continueListening;

  @override
  void initState() {
    super.initState();
    featured = PodcastRepository.getFeatured();
    genres = PodcastRepository.getGenres();
    genreMap = PodcastRepository.getByGenre();
    continueListening = PodcastRepository.getContinueListening();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      extendBody: true,
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            _horizontalPadding,
            18,
            _horizontalPadding,
            bottomInset,
          ),
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Row(
              children: [
                const Text(
                  'Podcasts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {},
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.filter_list,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (featured.isNotEmpty)
              FeaturedHero(podcast: featured.first),

            const SizedBox(height: 28),

            if (continueListening.isNotEmpty) ...[
              const SectionTitle('Continue listening'),
              const SizedBox(height: 12),
              GlassMiniPlayer(
                podcast: continueListening.first,
              ),
              const SizedBox(height: 26),
            ],

            for (final g in genres)
              if (genreMap[g]?.isNotEmpty ?? false) ...[
                SectionTitle(g),
                const SizedBox(height: 12),
                GenreCarousel(podcasts: genreMap[g]!),
                const SizedBox(height: 22),
              ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
