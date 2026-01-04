import 'package:flutter/material.dart';
import 'components/sign_up.dart';

class sign_up_body extends StatelessWidget {
  static const String routeName = '/sign_up';

  const sign_up_body({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SignUpScreen(),
    );
  }
}