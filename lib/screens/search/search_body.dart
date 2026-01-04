import 'package:flutter/material.dart';
import 'package:sangeet/screens/search/components/search_screen.dart';
import '../../components/navbar.dart';
import '../../repositories/search_repo.dart';

class search_body extends StatelessWidget {
  static const String routeName = '/search';

  const search_body({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SearchScreen(repository: LocalSearchRepository(), onPlay: (song) {}),
      //bottomNavigationBar: SlidingBubbleNavBar(),
    );
  }
}
