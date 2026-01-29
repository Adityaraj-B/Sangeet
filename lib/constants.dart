import 'package:flutter/material.dart';
import 'package:sangeet/size_config.dart';

// color constants (keep your existing values)
const kPrimaryColor = Color(0xFFF6F6F6);
const kAccentColor = Color(0xFFFFCB74);
const kBackgroundColor = Color(0xFF0B0B0D);
const kSurfaceColor = Color(0xFF282327);
const kMutedTextColor = Color(0xFFBDBDBD);
const kTextColorDark = Color(0xFF111111);
const kAnimationDuration = Duration(milliseconds: 200);


// Validators and strings (keep)
final RegExp emailValidatorRegExp = RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+",);
const String kEmailNullError = "Please Enter your email";
const String kInvalidEmailError = "Please Enter Valid Email";
const String kPassNullError = "Please Enter your password";
const String kShortPassError = "Password is too short, at least 8 chars";
const String kMatchPassError = "Passwords don't match";
const String kFirstNamelNullError = "Please Enter your first name";
const String kLastNamelNullError = "Please Enter your last name";
const String kPhoneNumberNullError = "Please Enter your phone number";
const String kAddressNullError = "Please Enter your address";


// ... rest of your strings ...

// RUNTIME heading style (call inside build AFTER SizeConfig.init(context))
TextStyle headingStyleBuild(BuildContext context, {double? size}) {
  SizeConfig.init(context); // ensure size config ready
  final double fontSize = size ?? getProportionateScreenWidth(28);
  return TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: fontSize,
    fontWeight: FontWeight.bold,
    color: kPrimaryColor,
    height: 1.5,
  );
}

// RUNTIME input decoration builder (safe)
InputDecoration inputDecorationBuild(BuildContext context, String hint,
    {double? verticalPadding}) {
  SizeConfig.init(context);
  final pad = verticalPadding ?? getProportionateScreenWidth(15);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: kMutedTextColor, fontSize: getProportionateScreenWidth(14)),
    contentPadding: EdgeInsets.symmetric(vertical: pad, horizontal: getProportionateScreenWidth(14)),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.02),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(getProportionateScreenWidth(12)),
      borderSide: BorderSide(color: kMutedTextColor.withValues(alpha: 0.24)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(getProportionateScreenWidth(12)),
      borderSide: BorderSide(color: kAccentColor.withValues(alpha: 0.9), width: 1.4),
    ),
  );
}
