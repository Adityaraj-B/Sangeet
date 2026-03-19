import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sangeet/utils/platform_utils.dart';
import './secure_storage_service.dart';
import './rate_limiter_service.dart';
import './biometric_auth_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final RateLimiterService _rateLimiter = RateLimiterService();

  static const _kGoogleWebClientId =
      '857660537994-g78eq70mf9noc5ses9je9qojrvctki09.apps.googleusercontent.com';

  static const _kDesktopRedirectPort = 8234;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<UserCredential?> signUp(String email, String password) async {
    if (!_rateLimiter.isAllowed(email, action: 'signup')) {
      throw _rateLimiter.getErrorMessage(email, action: 'signup');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _saveLoginState(true);
      _rateLimiter.resetAttempts(email, action: 'signup');

      return credential;
    } on FirebaseAuthException catch (e) {
      _rateLimiter.recordAttempt(email, action: 'signup');
      throw _handleAuthException(e);
    }
  }

  static Future<bool> signIn(String email, String password) async {
    if (!_rateLimiter.isAllowed(email, action: 'signin')) {
      throw _rateLimiter.getErrorMessage(email, action: 'signin');
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _saveLoginState(true);
      _rateLimiter.resetAttempts(email, action: 'signin');

      return true;
    } on FirebaseAuthException {
      _rateLimiter.recordAttempt(email, action: 'signin');
      return false;
    }
  }

  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (PlatformUtils.isDesktop) {
        return await _signInWithGoogleDesktop();
      } else {
        return await _signInWithGoogleMobile();
      }
    } catch (e) {
      if (e is String && e.contains('Too many attempts')) rethrow;
      throw 'Google sign-in failed: $e';
    }
  }

  static Future<UserCredential?> _signInWithGoogleDesktop() async {
    HttpServer? server;

    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        _kDesktopRedirectPort,
      );

      final redirectUri = 'http://localhost:$_kDesktopRedirectPort';

      final rng = Random.secure();
      final state = List.generate(32, (_) => rng.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      final authUrl = Uri.https(
        'accounts.google.com',
        '/o/oauth2/v2/auth',
        {
          'client_id': _kGoogleWebClientId,
          'redirect_uri': redirectUri,
          'response_type': 'token',
          'scope': 'openid email profile',
          'state': state,
          'prompt': 'select_account',
        },
      );

      await _launchUrl(authUrl.toString());

      final accessToken = await _listenForOAuthToken(server, state)
          .timeout(const Duration(minutes: 2), onTimeout: () => null);

      await server.close(force: true);

      if (accessToken == null || accessToken.isEmpty) {
        throw 'Sign-in timed out or was cancelled. '
            'Also ensure this redirect URI is configured in Google Cloud: '
            '$redirectUri';
      }

      final credential = GoogleAuthProvider.credential(accessToken: accessToken);

      final userCredential = await _auth.signInWithCredential(credential);

      await _saveLoginState(true);

      final user = userCredential.user;
      if (user != null) {
        await _saveUserProfile(
          name: user.displayName ?? 'User',
          email: user.email ?? '',
          photoUrl: user.photoURL,
        );
      }

      return userCredential;
    } on SocketException {
      throw 'Could not start local sign-in callback server on port '
          '$_kDesktopRedirectPort. Close other apps using that port and try again.';
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('redirect_uri_mismatch') || msg.contains('Error 400')) {
        throw 'Google OAuth redirect URI mismatch. Add '
            '`http://localhost:$_kDesktopRedirectPort` to Authorized redirect URIs '
            'for your OAuth client in Google Cloud Console.';
      }
      rethrow;
    } finally {
      await server?.close(force: true);
    }
  }

  static Future<void> _launchUrl(String url) async {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', url.replaceAll('&', '^&')]);
      return;
    }

    if (Platform.isMacOS) {
      await Process.run('open', [url]);
      return;
    }

    await Process.run('xdg-open', [url]);
  }

  static Future<String?> _listenForOAuthToken(
      HttpServer server, String expectedState) {
    final completer = Completer<String?>();

    server.listen((HttpRequest req) async {
      final path = req.uri.path;

      if (path == '/' || path.isEmpty) {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('''
<html lang="en">
<body style="font-family: Arial, sans-serif; background:#121212; color:#fff;">
  <h3>Completing sign-in...</h3>
  <p>You can close this window after it finishes.</p>
  <script>
    const hash = window.location.hash.startsWith('#') ? window.location.hash.substring(1) : '';
    if (hash) {
      window.location.href = '/complete?' + hash;
    }
  </script>
</body>
</html>
''');
        await req.response.close();
        return;
      }

      if (path == '/complete') {
        final token = req.uri.queryParameters['access_token'];
        final st = req.uri.queryParameters['state'];
        final ok = token != null && token.isNotEmpty && st == expectedState;

        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write(ok
              ? '<html lang="en"><body>Signed in successfully. You can close this window.</body></html>'
              : '<html lang="en"><body>Sign-in failed. Please return to the app.</body></html>');
        await req.response.close();

        if (!completer.isCompleted) {
          completer.complete(ok ? token : null);
        }
      }
    });

    return completer.future;
  }

  static Future<UserCredential?> _signInWithGoogleMobile() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) return null;

    if (!_rateLimiter.isAllowed(googleUser.email, action: 'google_signin')) {
      await _googleSignIn.signOut();
      throw _rateLimiter.getErrorMessage(
          googleUser.email,
          action: 'google_signin');
    }

    final GoogleSignInAuthentication googleAuth =
    await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
    await _auth.signInWithCredential(credential);

    await _saveLoginState(true);

    await _saveUserProfile(
      name: googleUser.displayName ??
          userCredential.user?.displayName ??
          'User',
      email: googleUser.email,
      photoUrl: googleUser.photoUrl ??
          userCredential.user?.photoURL,
    );

    _rateLimiter.resetAttempts(
        googleUser.email,
        action: 'google_signin');

    return userCredential;
  }

  static Future<void> _saveUserProfile({
    required String name,
    required String email,
    String? photoUrl,
  }) async {
    await SecureStorageService.setString('user_name', name);
    await SecureStorageService.setString('user_email', email);

    if (photoUrl != null) {
      await SecureStorageService.setString('profile_image', photoUrl);
    }
  }

  static Future<void> signOut() async {
    if (PlatformUtils.isMobile) {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('GoogleSignIn signOut error: $e');
      }
    }


    await _auth.signOut();
    await _saveLoginState(false);

    if (PlatformUtils.isMobile) {
      await BiometricAuthService.disableBiometric();
    }
  }

  static Future<bool> isLoggedIn() async {
    if (PlatformUtils.isDesktop) {
      debugPrint('AuthService: waiting for Firebase session restore...');

      // On Windows, authStateChanges() emits null immediately on cold start,
      // then emits the real cached user ~300-500ms later once Firebase loads
      // its local credential store. We wait up to 3 seconds for a non-null
      // user before giving up and treating the session as expired.
      try {
        final user = await _auth
            .authStateChanges()
            .firstWhere(
              (u) => u != null,
          orElse: () => null,
        )
            .timeout(const Duration(seconds: 3));

        debugPrint('AuthService: session restore complete, user=${user?.email}');
        return user != null;
      } catch (_) {
        debugPrint('AuthService: no cached session found');
        return false;
      }
    }

    // Mobile path — unchanged
    final localLogin =
        await SecureStorageService.getBool('is_logged_in') ?? false;
    return localLogin && _auth.currentUser != null;
  }

  static Future<String?> getEmail() async => _auth.currentUser?.email;

  static String? getDisplayName() => _auth.currentUser?.displayName;

  static String? getPhotoUrl() => _auth.currentUser?.photoURL;

  static Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    final user = _auth.currentUser;

    if (user != null) {
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoURL);
      await user.reload();
    }
  }

  static Future<void> _saveLoginState(bool isLoggedIn) async {
    await SecureStorageService.setBool('is_logged_in', isLoggedIn);
  }

  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      default:
        return e.message ?? 'Authentication error.';
    }
  }
}

