import 'package:flutter/material.dart';
import 'components/sign_in.dart';

class SignInBody extends StatelessWidget {
  static const String routeName = '/sign_in';

  const SignInBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SignInScreen(),
    );
  }
}