import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../models/podcasts.dart';

class _TitleWithAuthor extends StatelessWidget {
  final Podcast podcast;
  const _TitleWithAuthor(this.podcast);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          podcast.title,
          style: const TextStyle(
            color: kPrimaryColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(blurRadius: 8, color: Colors.black45, offset: Offset(0, 2))],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          podcast.author,
          style: TextStyle(color: kPrimaryColor.withOpacity(0.85), fontSize: 13),
        ),
      ],
    );
  }
}

class _GenreBadge extends StatelessWidget {
  final String genre;
  const _GenreBadge(this.genre);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kPrimaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: kAccentColor.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 10))
        ],
      ),
      child: Text(
        genre.toUpperCase(),
        style: TextStyle(color: kAccentColor, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String url;
  final double height;
  const _HeroImage({required this.url, this.height = 220});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (ctx, child, prog) {
          if (prog == null) return child;
          return Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator()));
        },
        errorBuilder: (ctx, err, st) => Container(
          color: Colors.grey[900],
          child: const Center(child: Icon(Icons.podcasts, size: 48, color: Colors.white24)),
        ),
      ),
    );
  }
}

class _FeaturedHeroWrapper extends StatelessWidget {
  final Widget child;
  final double radius;
  const _FeaturedHeroWrapper({required this.child, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class _FeaturedHeroInternal extends StatelessWidget {
  final Podcast podcast;
  const _FeaturedHeroInternal({required this.podcast});

  @override
  Widget build(BuildContext context) {
    return _FeaturedHeroWrapper(
      child: Stack(
        children: [
          _HeroImage(url: podcast.imageUrl),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kBackgroundColor.withOpacity(0.04), kSurfaceColor.withOpacity(0.72)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(left: 18, bottom: 18, child: _GenreBadge(podcast.genre)),
          Positioned(left: 18, bottom: 18 + 36, right: 18, child: _TitleWithAuthor(podcast)),
        ],
      ),
    );
  }
}

class FeaturedHero extends StatelessWidget {
  final Podcast podcast;
  const FeaturedHero({required this.podcast});

  @override
  Widget build(BuildContext context) => _FeaturedHeroInternal(podcast: podcast);
}
