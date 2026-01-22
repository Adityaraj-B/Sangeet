import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sangeet/constants.dart';
import '../../../services/auth.dart';
import '../../../services/biometric_auth_service.dart';
import '../../../services/playlist_provider.dart';
import '../../../size_config.dart';
import '../../../utils/validators.dart';
import '../../body.dart';
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
  bool _googleLoading = false;
  bool _biometricLoading = false;
  String? _error;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _biometricType = 'Biometric';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final canUse = await BiometricAuthService.canUseBiometric();
    final isEnabled = await BiometricAuthService.isBiometricEnabled();

    if (canUse) {
      final biometrics = await BiometricAuthService.getAvailableBiometrics();
      final typeName = BiometricAuthService.getBiometricTypeName(biometrics);

      if (mounted) {
        setState(() {
          _biometricAvailable = canUse;
          _biometricEnabled = isEnabled;
          _biometricType = typeName;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithBiometric() async {
    setState(() {
      _biometricLoading = true;
      _error = null;
    });

    try {
      final credentials = await BiometricAuthService.authenticateAndGetCredentials(
        reason: 'Authenticate to sign in to Sangeet',
      );

      if (!mounted) return;

      if (credentials != null) {
        // Sign in with stored credentials
        final ok = await AuthService.signIn(credentials['email']!, credentials['password']!);

        if (!mounted) return;

        if (ok) {
          context.read<PlaylistProvider>().initialize();
          Navigator.of(context).pushReplacementNamed(Body.routeName);
        } else {
          setState(() {
            _error = 'Biometric sign-in failed. Please use password.';
            _biometricLoading = false;
          });
        }
      } else {
        setState(() => _biometricLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _biometricLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;
    final ok = await AuthService.signIn(email, password);
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      // Offer to enable biometric authentication if available and not already enabled
      if (_biometricAvailable && !_biometricEnabled) {
        _offerBiometricSetup(email, password);
      } else {
        // Navigate to main screen
        context.read<PlaylistProvider>().initialize();
        Navigator.of(context).pushReplacementNamed(Body.routeName);
      }
    } else {
      setState(() => _error = 'Invalid credentials. Try signing up first.');
    }
  }

  Future<void> _offerBiometricSetup(String email, String password) async {
    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enable $_biometricType?'),
        content: Text(
          'Would you like to use $_biometricType for quick sign-in next time?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
              foregroundColor: Colors.black,
            ),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (shouldEnable == true) {
      try {
        await BiometricAuthService.enableBiometric(
          email: email,
          password: password,
        );

        if (mounted) {
          setState(() => _biometricEnabled = true);
        }
      } catch (e) {
        // Silently fail, don't disrupt the flow
      }
    }

    // Navigate to main screen
    if (mounted) {
      context.read<PlaylistProvider>().initialize();
      Navigator.of(context).pushReplacementNamed(Body.routeName);
    }
  }

  Future<void> _signInWithGoogle() async {
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

                  // Biometric button (only shown if enabled)
                  if (_biometricAvailable && _biometricEnabled) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _biometricLoading ? null : _signInWithBiometric,
                        icon: _biometricLoading
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : Icon(
                                _biometricType.contains('Face')
                                    ? Icons.face
                                    : Icons.fingerprint,
                                size: 24,
                              ),
                        label: Text('Sign in with $_biometricType'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentColor,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: getProportionateScreenHeight(14)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(getProportionateScreenWidth(12)),
                          ),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SizedBox(height: getProportionateScreenHeight(16)),
                    Row(
                      children: [
                        Expanded(child: Divider(color: kMutedTextColor.withOpacity(0.3))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: getProportionateScreenWidth(12)),
                          child: Text('or use password', style: TextStyle(color: kMutedTextColor, fontSize: 14)),
                        ),
                        Expanded(child: Divider(color: kMutedTextColor.withOpacity(0.3))),
                      ],
                    ),
                    SizedBox(height: getProportionateScreenHeight(16)),
                  ],

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
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
                          validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                          ),
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
                        // Google Sign In Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _googleLoading ? null : _signInWithGoogle,
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
                            label: Text(_googleLoading ? 'Signing in...' : 'Continue with Google'),
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

