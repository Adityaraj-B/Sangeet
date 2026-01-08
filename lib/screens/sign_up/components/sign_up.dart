import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import '../../../services/auth.dart';
import '../../../size_config.dart';
import '../../body.dart';
import '../../home/home_body.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = kMatchPassError);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    await AuthService.signUp(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).pushReplacementNamed(Body.routeName);

  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    final double screenW = SizeConfig.screenWidth;
    final titleSize = getProportionateScreenWidth(28);
    final verticalPad = getProportionateScreenHeight(20);
    final inputPad = getProportionateScreenWidth(15);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenW * 0.06, vertical: verticalPad),
          child: Center(
            child: SingleChildScrollView(
              child: Column(children: [
                Text('Create account', style: headingStyleBuild(context, size: titleSize)),
                SizedBox(height: getProportionateScreenHeight(12)),
                Text('Start your music journey', style: TextStyle(color: kMutedTextColor)),
                SizedBox(height: getProportionateScreenHeight(22)),
                Form(
                  key: _formKey,
                  child: Column(children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: kPrimaryColor, fontSize: getProportionateScreenWidth(14)),
                      decoration: inputDecorationBuild(context, 'Email', verticalPadding: inputPad),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return kEmailNullError;
                        if (!emailValidatorRegExp.hasMatch(v.trim())) return kInvalidEmailError;
                        return null;
                      },
                    ),
                    SizedBox(height: getProportionateScreenHeight(14)),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      style: TextStyle(color: kPrimaryColor, fontSize: getProportionateScreenWidth(14)),
                      decoration: inputDecorationBuild(context, 'Password', verticalPadding: inputPad),
                      validator: (v) {
                        if (v == null || v.isEmpty) return kPassNullError;
                        if (v.length < 8) return kShortPassError;
                        return null;
                      },
                    ),
                    SizedBox(height: getProportionateScreenHeight(14)),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      style: TextStyle(color: kPrimaryColor, fontSize: getProportionateScreenWidth(14)),
                      decoration: inputDecorationBuild(context, 'Confirm Password', verticalPadding: inputPad),
                      validator: (v) {
                        if (v == null || v.isEmpty) return kPassNullError;
                        return null;
                      },
                    ),
                    SizedBox(height: getProportionateScreenHeight(18)),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      SizedBox(height: getProportionateScreenHeight(12)),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: getProportionateScreenHeight(14)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(getProportionateScreenWidth(12))),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        child: _loading ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Create Account'),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}