import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import '../library_body.dart';
// for LibCard type

class SectionHeaderAndList extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final ScrollController controller;
  final List<LibCard> items;

  const SectionHeaderAndList({
    required this.title,
    required this.controller,
    required this.items,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 6),
          child: Row(
            children: [
              Text(title, style: TextStyle(color: kPrimaryColor, fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 190,
          child: ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 320 + (index * 50)),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) {
                  return Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, (1 - v) * 18),
                      child: Container(
                        width: 150,
                        margin: const EdgeInsets.only(right: 14, left: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(item.image, fit: BoxFit.cover),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.02),
                                              kSurfaceColor.withOpacity(0.4),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(item.title, style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.w800)),
                            Text(item.subtitle, style: TextStyle(color: kPrimaryColor.withOpacity(0.62), fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
