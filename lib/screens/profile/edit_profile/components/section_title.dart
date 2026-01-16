import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class EditSectionTitle extends StatelessWidget {
  final String text;

  const EditSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'PlayfairDisplay',
          color: kMutedTextColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
