import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to handle notification permission requests for Android 13+
class NotificationPermissionService {
  static final NotificationPermissionService _instance =
      NotificationPermissionService._internal();
  factory NotificationPermissionService() => _instance;
  NotificationPermissionService._internal();

  bool _permissionRequested = false;

  /// Request notification permission (required for Android 13+)
  /// Returns true if permission is granted
  Future<bool> requestNotificationPermission() async {
    // Only needed for Android
    if (!Platform.isAndroid) return true;

    // Don't request multiple times in same session
    if (_permissionRequested) {
      return await Permission.notification.isGranted;
    }

    _permissionRequested = true;

    try {
      // Check current status
      final status = await Permission.notification.status;

      if (status.isGranted) {
        debugPrint('NotificationPermission: Already granted');
        return true;
      }

      if (status.isPermanentlyDenied) {
        debugPrint('NotificationPermission: Permanently denied');
        // User needs to enable in settings
        return false;
      }

      // Request permission
      final result = await Permission.notification.request();
      debugPrint('NotificationPermission: Request result: $result');

      return result.isGranted;
    } catch (e) {
      debugPrint('NotificationPermission: Error requesting permission: $e');
      return false;
    }
  }

  /// Check if notification permission is granted
  Future<bool> isNotificationPermissionGranted() async {
    if (!Platform.isAndroid) return true;

    try {
      return await Permission.notification.isGranted;
    } catch (e) {
      return false;
    }
  }

  /// Open app settings so user can enable notifications
  Future<bool> openNotificationSettings() async {
    return await openAppSettings();
  }
}
