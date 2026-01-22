import 'package:flutter/material.dart';
import 'package:sangeet/screens/body.dart';
import 'package:sangeet/screens/sign_in/sign_in_body.dart';
import 'package:sangeet/screens/sign_up/sign_up_body.dart';

Map<String, WidgetBuilder> routes = {
  Body.routeName: (ctx) => const Body(),

  SignInBody.routeName: (ctx) => const SignInBody(),
  SignUpBody.routeName: (ctx) => const SignUpBody(),

  // FULL-SCREEN pages ONLY below this line
  // '/player': (ctx) => PlayerScreen(),
  // '/playlist': (ctx) => PlaylistScreen(),
};
