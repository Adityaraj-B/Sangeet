import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _kIsLoggedIn = 'is_logged_in';
  static const _kUserEmail = 'user_email';
  static const _kUserPassword = 'user_password';

  /// Save signup credentials (for demo). In production use secure backend.
  static Future<void> signUp(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserEmail, email);
    await prefs.setString(_kUserPassword, password);
    await prefs.setBool(_kIsLoggedIn, true);
  }

  /// Attempt sign-in; returns true if credentials match stored ones.
  static Future<bool> signIn(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString(_kUserEmail);
    final storedPassword = prefs.getString(_kUserPassword);
    final ok = (storedEmail != null && storedPassword != null && storedEmail == email && storedPassword == password);
    if (ok) await prefs.setBool(_kIsLoggedIn, true);
    return ok;
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLoggedIn, false);
    // keep credentials for demo so sign in can work again; if you want remove them uncomment below:
    // await prefs.remove(_kUserEmail);
    // await prefs.remove(_kUserPassword);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLoggedIn) ?? false;
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserEmail);
  }
}
