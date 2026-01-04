import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../models/podcasts.dart';

class GenreCarousel extends StatelessWidget {
  final List<Podcast> podcasts;
  const GenreCarousel({required this.podcasts});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: podcasts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final p = podcasts[index];
          return Column(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                    p.imageUrl,
                    height: 130, width: 130, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        height: 130, width: 130, color: Colors.grey[900],
                        child: Icon(
                            Icons.podcasts, color: kPrimaryColor.withOpacity(0.24)
                        )
                    )
                )
            ),
            const SizedBox(height: 6),
            SizedBox(
                width: 130,
                child: Text(
                    p.title, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: kPrimaryColor, fontSize: 14, fontWeight: FontWeight.w600)
                )
            ),
            SizedBox(
                width: 130,
                child: Text(
                    p.author, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: kPrimaryColor.withOpacity(0.54), fontSize: 12)
                )
            ),
          ]);
        },
      ),
    );
  }
}
