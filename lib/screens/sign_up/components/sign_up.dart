import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sangeet/constants.dart';
import '../../../services/auth.dart';
import '../../../services/playlist_provider.dart';
import '../../../size_config.dart';
import '../../../utils/validators.dart';
import '../../body.dart';

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
  bool _googleLoading = false;
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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.signUp(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      setState(() => _loading = false);

      // Initialize playlist provider for the newly created user
      context.read<PlaylistProvider>().initialize();
      Navigator.of(context).pushReplacementNamed(Body.routeName);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    try {
      final credential = await AuthService.signInWithGoogle();
      if (!mounted) return;

      if (credential != null) {
        context.read<PlaylistProvider>().initialize();
        Navigator.of(context).pushReplacementNamed(Body.routeName);
      } else {
        setState(() => _googleLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _googleLoading = false;
        _error = e.toString();
      });
    }
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
          padding: EdgeInsets.symmetric(
              horizontal: screenW * 0.06, vertical: verticalPad),
          child: Center(
            child: SingleChildScrollView(
              child: Column(children: [
                Text('Create account',
                    style: headingStyleBuild(context, size: titleSize)),
                SizedBox(height: getProportionateScreenHeight(12)),
                Text('Start your music journey',
                    style: TextStyle(color: kMutedTextColor)),
                SizedBox(height: getProportionateScreenHeight(22)),
                Form(
                  key: _formKey,
                  child: Column(children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.validateEmail,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                      ),
                    ),
                    SizedBox(height: getProportionateScreenHeight(16)),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      validator: Validators.validatePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText:
                            'Minimum 8 characters, include uppercase, lowercase, number & special character',
                      ),
                    ),
                    SizedBox(height: getProportionateScreenHeight(16)),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      validator: (v) =>
                          Validators.validateConfirmPassword(v, _passCtrl.text),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter your password',
                      ),
                    ),
                    SizedBox(height: getProportionateScreenHeight(18)),
                    if (_error != null) ...[
                      Text(_error!,
                          style: const TextStyle(color: Colors.redAccent)),
                      SizedBox(height: getProportionateScreenHeight(12)),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(
                              vertical: getProportionateScreenHeight(14)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(getProportionateScreenWidth(12))),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        child: _loading
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black))
                            : const Text('Create Account'),
                      ),
                    ),
                    SizedBox(height: getProportionateScreenHeight(16)),
                    // Divider with "or"
                    Row(
                      children: [
                        Expanded(child: Divider(color: kMutedTextColor.withOpacity(0.3))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: getProportionateScreenWidth(12)),
                          child: Text('or', style: TextStyle(color: kMutedTextColor, fontSize: 14)),
                        ),
                        Expanded(child: Divider(color: kMutedTextColor.withOpacity(0.3))),
                      ],
                    ),
                    SizedBox(height: getProportionateScreenHeight(16)),
                    // Google Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _googleLoading ? null : _signUpWithGoogle,
                        icon: _googleLoading
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryColor),
                              )
                            : Image.network(
                                'https://www.google.com/favicon.ico',
                                height: 20,
                                width: 20,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.g_mobiledata, color: kPrimaryColor, size: 24),
                              ),
                        label: Text(_googleLoading ? 'Signing up...' : 'Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kPrimaryColor,
                          padding: EdgeInsets.symmetric(vertical: getProportionateScreenHeight(14)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(getProportionateScreenWidth(12)),
                          ),
                          side: BorderSide(color: kMutedTextColor.withOpacity(0.3)),
                        ),
                      ),
                    ),
                    SizedBox(height: getProportionateScreenHeight(16)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already have an account? ", style: TextStyle(color: kMutedTextColor)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text('Sign In', style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold)),
                        )
                      ],
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