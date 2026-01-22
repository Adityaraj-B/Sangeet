import 'package:flutter/foundation.dart';

/// Rate limiter service to prevent brute force attacks on authentication endpoints
class RateLimiterService {
  // Singleton pattern
  static final RateLimiterService _instance = RateLimiterService._internal();
  factory RateLimiterService() => _instance;
  RateLimiterService._internal();

  // Track attempts per email/action
  final Map<String, List<DateTime>> _attempts = {};

  // Configuration
  static const int maxAttempts = 5; // Maximum attempts allowed
  static const Duration windowDuration = Duration(minutes: 15); // Time window
  static const Duration lockoutDuration = Duration(minutes: 30); // Lockout period after max attempts

  // Lockout tracking
  final Map<String, DateTime> _lockedUntil = {};

  /// Check if an action is allowed for the given identifier (email)
  /// Returns true if allowed, false if rate limited
  bool isAllowed(String identifier, {String action = 'auth'}) {
    final key = _getKey(identifier, action);

    // Check if currently locked out
    if (_isLockedOut(key)) {
      return false;
    }

    // Clean old attempts outside the window
    _cleanOldAttempts(key);

    // Check if under the limit
    final attempts = _attempts[key] ?? [];
    return attempts.length < maxAttempts;
  }

  /// Record an attempt for the given identifier
  void recordAttempt(String identifier, {String action = 'auth'}) {
    final key = _getKey(identifier, action);

    // Initialize if needed
    _attempts[key] ??= [];

    // Add current attempt
    _attempts[key]!.add(DateTime.now());

    // Check if we should lock out
    _cleanOldAttempts(key);
    if (_attempts[key]!.length >= maxAttempts) {
      _lockedUntil[key] = DateTime.now().add(lockoutDuration);
      debugPrint('Rate limiter: $identifier locked out until ${_lockedUntil[key]}');
    }
  }

  /// Reset attempts for an identifier (called on successful action)
  void resetAttempts(String identifier, {String action = 'auth'}) {
    final key = _getKey(identifier, action);
    _attempts.remove(key);
    _lockedUntil.remove(key);
  }

  /// Get remaining attempts before lockout
  int getRemainingAttempts(String identifier, {String action = 'auth'}) {
    final key = _getKey(identifier, action);

    if (_isLockedOut(key)) {
      return 0;
    }

    _cleanOldAttempts(key);
    final attempts = _attempts[key] ?? [];
    return maxAttempts - attempts.length;
  }

  /// Get time until lockout expires
  Duration? getTimeUntilUnlock(String identifier, {String action = 'auth'}) {
    final key = _getKey(identifier, action);
    final lockoutTime = _lockedUntil[key];

    if (lockoutTime == null) {
      return null;
    }

    final now = DateTime.now();
    if (now.isAfter(lockoutTime)) {
      _lockedUntil.remove(key);
      return null;
    }

    return lockoutTime.difference(now);
  }

  /// Check if identifier is currently locked out
  bool _isLockedOut(String key) {
    final lockoutTime = _lockedUntil[key];
    if (lockoutTime == null) return false;

    final now = DateTime.now();
    if (now.isAfter(lockoutTime)) {
      // Lockout expired, clean up
      _lockedUntil.remove(key);
      _attempts.remove(key);
      return false;
    }

    return true;
  }

  /// Remove attempts outside the time window
  void _cleanOldAttempts(String key) {
    final attempts = _attempts[key];
    if (attempts == null) return;

    final cutoff = DateTime.now().subtract(windowDuration);
    attempts.removeWhere((attempt) => attempt.isBefore(cutoff));

    if (attempts.isEmpty) {
      _attempts.remove(key);
    }
  }

  /// Generate a unique key for identifier and action
  String _getKey(String identifier, String action) {
    return '${action}_${identifier.toLowerCase()}';
  }

  /// Clear all rate limit data (for testing or admin purposes)
  void clearAll() {
    _attempts.clear();
    _lockedUntil.clear();
  }

  /// Get a user-friendly error message
  String getErrorMessage(String identifier, {String action = 'auth'}) {
    final timeUntilUnlock = getTimeUntilUnlock(identifier, action: action);

    if (timeUntilUnlock != null) {
      final minutes = timeUntilUnlock.inMinutes;
      final seconds = timeUntilUnlock.inSeconds % 60;
      return 'Too many attempts. Please try again in ${minutes}m ${seconds}s';
    }

    final remaining = getRemainingAttempts(identifier, action: action);
    return 'Too many attempts. You have $remaining attempts remaining';
  }
}

