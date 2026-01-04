import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SectionHeader({Key? key, required this.title, this.onSeeAll}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      const Spacer(),
      TextButton(
        onPressed: onSeeAll ?? () {},
        style: TextButton.styleFrom(foregroundColor: Colors.white70, padding: EdgeInsets.zero, minimumSize: const Size(40, 24), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: const Text('See All', style: TextStyle(fontSize: 13)),
      )
    ]);
  }
}
