import 'package:flutter/material.dart';
import 'components/sign_up.dart';

class SignUpBody extends StatelessWidget {
  static const String routeName = '/sign_up';

  const SignUpBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SignUpScreen(),
    );
  }
}