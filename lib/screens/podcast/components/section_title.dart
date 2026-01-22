import 'package:flutter/material.dart';

import '../../../constants.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: kPrimaryColor.withValues(alpha: 0.92),
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
