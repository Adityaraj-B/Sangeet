import 'package:flutter/material.dart';
import 'package:sangeet/components/navbar.dart';
import 'package:sangeet/screens/home/home_body.dart';
import 'package:sangeet/screens/library/library_body.dart';
import 'package:sangeet/screens/podcast/podcast_body.dart';
import 'package:sangeet/screens/search/search_body.dart';

class Body extends StatefulWidget {
  static const routeName = '/body';
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    search_body(),
    PodcastsScreen(),
    LibraryBody(),
  ];

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SlidingBubbleNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
