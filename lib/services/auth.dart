import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import './secure_storage_service.dart';
import './rate_limiter_service.dart';
import './biometric_auth_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final RateLimiterService _rateLimiter = RateLimiterService();

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email and password
  static Future<UserCredential?> signUp(String email, String password) async {
    // Check rate limit before attempting
    if (!_rateLimiter.isAllowed(email, action: 'signup')) {
      throw _rateLimiter.getErrorMessage(email, action: 'signup');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveLoginState(true);

      // Reset rate limit on success
      _rateLimiter.resetAttempts(email, action: 'signup');

      return credential;
    } on FirebaseAuthException catch (e) {
      // Record failed attempt
      _rateLimiter.recordAttempt(email, action: 'signup');
      throw _handleAuthException(e);
    }
  }

  /// Sign in with email and password
  static Future<bool> signIn(String email, String password) async {
    // Check rate limit before attempting
    if (!_rateLimiter.isAllowed(email, action: 'signin')) {
      throw _rateLimiter.getErrorMessage(email, action: 'signin');
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _saveLoginState(true);

      // Reset rate limit on success
      _rateLimiter.resetAttempts(email, action: 'signin');

      return true;
    } on FirebaseAuthException {
      // Record failed attempt
      _rateLimiter.recordAttempt(email, action: 'signin');
      return false;
    }
  }

  /// Sign in with Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Check rate limit for Google sign-in
      if (!_rateLimiter.isAllowed(googleUser.email, action: 'google_signin')) {
        await _googleSignIn.signOut();
        throw _rateLimiter.getErrorMessage(googleUser.email, action: 'google_signin');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      await _saveLoginState(true);

      // Save Google profile data to SecureStorage
      await _saveUserProfile(
        name: googleUser.displayName ?? userCredential.user?.displayName ?? 'User',
        email: googleUser.email,
        photoUrl: googleUser.photoUrl ?? userCredential.user?.photoURL,
      );

      // Reset rate limit on success
      _rateLimiter.resetAttempts(googleUser.email, action: 'google_signin');

      return userCredential;
    } catch (e) {
      // Record failed attempt if email available
      if (e is String && e.contains('Too many attempts')) {
        rethrow;
      }
      throw 'Google sign-in failed: $e';
    }
  }

  /// Save user profile to SecureStorage
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

  /// Sign out
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    await _saveLoginState(false);

    // Clear biometric data on logout for security
    await BiometricAuthService.disableBiometric();
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final localLogin = await SecureStorageService.getBool('is_logged_in') ?? false;
    return localLogin && _auth.currentUser != null;
  }

  /// Get current user's email
  static Future<String?> getEmail() async {
    return _auth.currentUser?.email;
  }

  /// Get current user's display name
  static String? getDisplayName() {
    return _auth.currentUser?.displayName;
  }

  /// Get current user's photo URL
  static String? getPhotoUrl() {
    return _auth.currentUser?.photoURL;
  }

  /// Update user profile
  static Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(displayName);
      await user.updatePhotoURL(photoURL);
      await user.reload();
    }
  }

  // Helper to save login state locally
  static Future<void> _saveLoginState(bool isLoggedIn) async {
    await SecureStorageService.setBool('is_logged_in', isLoggedIn);
  }

  // Handle Firebase Auth exceptions
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
        return e.message ?? 'An error occurred during authentication.';
    }
  }
}
