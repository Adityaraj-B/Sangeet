import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key});

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
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1:12', style: TextStyle(color: Colors.white54)),
            Text('3:45', style: TextStyle(color: Colors.white54)),
          ],
        ),
      ],
    );
  }
}
