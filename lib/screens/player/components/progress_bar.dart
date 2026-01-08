import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class ProgressBar extends StatelessWidget {
  final Color accentColor;

  const ProgressBar({
    super.key,
    required this.accentColor,
  });


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: 0.3,
          onChanged: (_) {},
          activeColor: kPrimaryColor,
          inactiveColor: Colors.white24,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1:12', style: TextStyle(color: accentColor,)),
            Text('3:45', style: TextStyle(color: accentColor,)),
          ],
        ),
      ],
    );
  }
}
