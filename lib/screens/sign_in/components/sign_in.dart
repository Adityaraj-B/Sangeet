import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _SignInScreenState extends State<SignInScreen> with TickerProviderStateMixin {
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
  bool _obscurePassword = true;

  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late AnimationController _glowController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;

  final List<Animation<double>> _staggeredAnimations = [];

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Slow, smooth glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    );

    _glowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Staggered animations
    for (int i = 0; i < 8; i++) {
      final start = i * 0.08;
      final end = start + 0.35;
      _staggeredAnimations.add(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
        ),
      );
    }

    _fadeController.forward();
    _staggerController.forward();
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
    _fadeController.dispose();
    _staggerController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _signInWithBiometric() async {
    HapticFeedback.mediumImpact();
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
        final ok = await AuthService.signIn(credentials['email']!, credentials['password']!);
        if (!mounted) return;
        if (ok) {
          HapticFeedback.heavyImpact();
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
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    HapticFeedback.mediumImpact();
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
      HapticFeedback.heavyImpact();
      if (_biometricAvailable && !_biometricEnabled) {
        _offerBiometricSetup(email, password);
      } else {
        context.read<PlaylistProvider>().initialize();
        Navigator.of(context).pushReplacementNamed(Body.routeName);
      }
    } else {
      HapticFeedback.lightImpact();
      setState(() => _error = 'Invalid credentials. Try signing up first.');
    }
  }

  Future<void> _offerBiometricSetup(String email, String password) async {
    final shouldEnable = await showGeneralDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha :0.75),
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 20 * animation.value,
            sigmaY: 20 * animation.value,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
            child: FadeTransition(
              opacity: animation,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161618),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha :0.06),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha :0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: kAccentColor.withValues(alpha :0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _biometricType.contains('Face') ? Icons.face_rounded : Icons.fingerprint_rounded,
                          color: kAccentColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Enable $_biometricType',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Sign in faster and more securely with $_biometricType authentication.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha :0.5),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: _DialogButton(
                              text: 'Skip',
                              onTap: () => Navigator.of(context).pop(false),
                              isPrimary: false,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DialogButton(
                              text: 'Enable',
                              onTap: () => Navigator.of(context).pop(true),
                              isPrimary: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (shouldEnable == true) {
      try {
        await BiometricAuthService.enableBiometric(email: email, password: password);
        if (mounted) setState(() => _biometricEnabled = true);
      } catch (_) {}
    }

    if (mounted) {
      context.read<PlaylistProvider>().initialize();
      Navigator.of(context).pushReplacementNamed(Body.routeName);
    }
  }

  Future<void> _signInWithGoogle() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    try {
      final credential = await AuthService.signInWithGoogle();
      if (!mounted) return;
      if (credential != null) {
        HapticFeedback.heavyImpact();
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
    final screenW = SizeConfig.screenWidth;
    final verticalPad = getProportionateScreenHeight(20);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: Stack(
        children: [
          // Subtle animated gradient orbs
          _buildAmbientBackground(),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenW * 0.07,
                vertical: verticalPad,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        SizedBox(height: getProportionateScreenHeight(32)),
                        _buildHeader(),
                        SizedBox(height: getProportionateScreenHeight(44)),

                        if (_biometricAvailable && _biometricEnabled) ...[
                          _buildAnimatedChild(0, _buildBiometricButton()),
                          SizedBox(height: getProportionateScreenHeight(28)),
                          _buildAnimatedChild(1, _buildDivider()),
                          SizedBox(height: getProportionateScreenHeight(28)),
                        ],

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildAnimatedChild(2, _buildTextField(
                                controller: _emailCtrl,
                                label: 'Email',
                                hint: 'you@example.com',
                                keyboardType: TextInputType.emailAddress,
                                validator: Validators.validateEmail,
                                icon: Icons.mail_outline_rounded,
                              )),
                              SizedBox(height: getProportionateScreenHeight(16)),
                              _buildAnimatedChild(3, _buildTextField(
                                controller: _passCtrl,
                                label: 'Password',
                                hint: '••••••••',
                                obscureText: _obscurePassword,
                                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                icon: Icons.lock_outline_rounded,
                                suffixIcon: _buildPasswordToggle(),
                              )),

                              if (_error != null) ...[
                                SizedBox(height: getProportionateScreenHeight(20)),
                                _buildErrorMessage(),
                              ],

                              SizedBox(height: getProportionateScreenHeight(28)),
                              _buildAnimatedChild(4, _buildSignInButton()),
                              SizedBox(height: getProportionateScreenHeight(24)),
                              _buildAnimatedChild(5, _buildDivider()),
                              SizedBox(height: getProportionateScreenHeight(24)),
                              _buildAnimatedChild(6, _buildGoogleButton()),
                              SizedBox(height: getProportionateScreenHeight(36)),
                              _buildAnimatedChild(7, _buildSignUpPrompt()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientBackground() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Top-right orb
            Positioned(
              top: -100 + (_glowAnimation.value * 30),
              right: -80 + (_glowAnimation.value * 20),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kAccentColor.withValues(alpha :0.08 + _glowAnimation.value * 0.04),
                      kAccentColor.withValues(alpha :0),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom-left orb
            Positioned(
              bottom: -120 + (_glowAnimation.value * 25),
              left: -100 + (_glowAnimation.value * 15),
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kAccentColor.withValues(alpha :0.05 + _glowAnimation.value * 0.03),
                      kAccentColor.withValues(alpha :0),
                    ],
                  ),
                ),
              ),
            ),
            // Noise overlay for texture
            Positioned.fill(
              child: Opacity(
                opacity: 0.015,
                child: Image.asset(
                  'assets/images/noise.png',
                  fit: BoxFit.cover,
                  repeat: ImageRepeat.repeat,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kAccentColor, kAccentColor.withValues(alpha :0.75)],
            ),
            boxShadow: [
              BoxShadow(
                color: kAccentColor.withValues(alpha :0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 32),
        ),
        SizedBox(height: getProportionateScreenHeight(32)),
        Text(
          'Welcome back',
          style: TextStyle(
            color: Colors.white,
            fontSize: getProportionateScreenWidth(30),
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        SizedBox(height: getProportionateScreenHeight(8)),
        Text(
          'Sign in to your account',
          style: TextStyle(
            color: Colors.white.withValues(alpha :0.4),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedChild(int index, Widget child) {
    if (index >= _staggeredAnimations.length) return child;
    return FadeTransition(
      opacity: _staggeredAnimations[index],
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_staggeredAnimations[index]),
        child: child,
      ),
    );
  }

  Widget _buildBiometricButton() {
    return _PremiumButton(
      onTap: _biometricLoading ? null : _signInWithBiometric,
      isLoading: _biometricLoading,
      backgroundColor: Colors.white.withValues(alpha :0.04),
      borderColor: Colors.white.withValues(alpha :0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kAccentColor.withValues(alpha :0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _biometricType.contains('Face') ? Icons.face_rounded : Icons.fingerprint_rounded,
              size: 18,
              color: kAccentColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Continue with $_biometricType',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha :0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha :0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha :0.06)),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            cursorColor: kAccentColor,
            cursorWidth: 1.5,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: Colors.white.withValues(alpha :0.3), size: 20),
              suffixIcon: suffixIcon,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha :0.2),
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordToggle() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _obscurePassword = !_obscurePassword);
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(
          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: Colors.white.withValues(alpha :0.3),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return _PremiumButton(
      onTap: _loading ? null : _submit,
      isLoading: _loading,
      isPrimary: true,
      child: const Text(
        'Sign in',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return _PremiumButton(
      onTap: _googleLoading ? null : _signInWithGoogle,
      isLoading: _googleLoading,
      backgroundColor: Colors.white.withValues(alpha :0.04),
      borderColor: Colors.white.withValues(alpha :0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            '<https://www.google.com/favicon.ico>',
            height: 18,
            width: 18,
            errorBuilder: (_, __, ___) => Icon(
              Icons.g_mobiledata_rounded,
              color: Colors.white.withValues(alpha :0.8),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Continue with Google',
            style: TextStyle(
              color: Colors.white.withValues(alpha :0.9),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha :0.06))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: TextStyle(
              color: Colors.white.withValues(alpha :0.3),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.white.withValues(alpha :0.06))),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - value)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha :0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha :0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade200, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSignUpPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(color: Colors.white.withValues(alpha :0.4), fontSize: 14),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => const SignUpScreen(),
                transitionsBuilder: (_, animation, __, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          },
          child: Text(
            'Sign up',
            style: TextStyle(
              color: kAccentColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// Reusable premium button component
class _PremiumButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final bool isLoading;
  final bool isPrimary;
  final Color? backgroundColor;
  final Color? borderColor;

  const _PremiumButton({
    required this.onTap,
    required this.child,
    this.isLoading = false,
    this.isPrimary = false,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null ? (_) => _controller.reverse() : null,
      onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: getProportionateScreenHeight(17)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: widget.isPrimary ? null : widget.backgroundColor,
                gradient: widget.isPrimary
                    ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kAccentColor, kAccentColor.withValues(alpha :0.85)],
                )
                    : null,
                border: widget.borderColor != null
                    ? Border.all(color: widget.borderColor!)
                    : null,
                boxShadow: widget.isPrimary
                    ? [
                  BoxShadow(
                    color: kAccentColor.withValues(alpha :0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
                    : null,
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.isPrimary ? Colors.black : Colors.white.withValues(alpha :0.7),
                    ),
                  )
                      : widget.child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Dialog button helper
class _DialogButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isPrimary;

  const _DialogButton({
    required this.text,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isPrimary ? kAccentColor : Colors.white.withValues(alpha :0.06),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isPrimary ? Colors.black : Colors.white.withValues(alpha :0.6),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
