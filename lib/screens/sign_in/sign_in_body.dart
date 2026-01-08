import 'package:flutter/material.dart';
import 'components/sign_in.dart';

class sign_in_body extends StatelessWidget {
  static const String routeName = '/sign_in';

  const sign_in_body({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SignInScreen(),
    );
  }
}