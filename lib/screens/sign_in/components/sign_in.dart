import 'package:flutter/material.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/screens/sign_in/sign_in_body.dart';
import '../../../services/auth.dart';
import '../../../size_config.dart';
import '../../body.dart';
import '../../home/home_body.dart';
import '../../sign_up/components/sign_up.dart';
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await AuthService.signIn(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      Navigator.of(context).pushReplacementNamed(Body.routeName);

    } else {
      setState(() => _error = 'Invalid credentials. Try signing up first.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // initialize sizing
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
              child: Column(
                children: [
                  Text('Welcome back', style: headingStyleBuild(context, size: titleSize)),
                  SizedBox(height: getProportionateScreenHeight(12)),
                  Text('Sign in to continue to Sangeet', style: TextStyle(color: kMutedTextColor)),
                  SizedBox(height: getProportionateScreenHeight(22)),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
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
                            child: _loading
                                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Text('Sign In'),
                          ),
                        ),
                        SizedBox(height: getProportionateScreenHeight(12)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account? ", style: TextStyle(color: kMutedTextColor)),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignUpScreen())),
                              child: Text('Sign Up', style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}