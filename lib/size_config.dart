import 'package:flutter/material.dart';
import 'dart:math' as math;

class SizeConfig {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double defaultSize;
  static late Orientation orientation;

  /// Whether the screen is wide enough for desktop layout (sidebar, etc.)
  static bool get isWideScreen => screenWidth > 800;

  /// Whether it's a very wide screen (ultra-wide / large monitor)
  static bool get isExtraWide => screenWidth > 1200;

  /// Content max width for centering content on very wide screens
  static double get contentMaxWidth => isExtraWide ? 1400 : screenWidth;

  static void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    orientation = _mediaQueryData.orientation;
    defaultSize = orientation == Orientation.portrait
        ? screenHeight / 100
        : screenWidth / 100;
  }
}

/// Returns proportionate screen height, clamped for desktop.
/// On desktop (>812 height), clamps the scaling factor so UI doesn't get
/// absurdly large.
double getProportionateScreenHeight(double inputHeight) {
  final double screenHeight = SizeConfig.screenHeight;
  // Clamp effective height to max 900 for scaling (prevents bloated desktop UI)
  final effectiveHeight = math.min(screenHeight, 900.0);
  return (inputHeight / 812.0) * effectiveHeight;
}

/// Returns proportionate screen width, clamped for desktop.
/// On desktop (>500 width), clamps the scaling factor.
double getProportionateScreenWidth(double inputWidth) {
  final double screenWidth = SizeConfig.screenWidth;
  // Clamp effective width to max 500 for scaling (prevents bloated desktop UI)
  final effectiveWidth = math.min(screenWidth, 500.0);
  return (inputWidth / 375.0) * effectiveWidth;
}

/// Returns horizontal padding that adapts to screen width.
/// On mobile: 20, on desktop: scales up to 32.
double getAdaptiveHorizontalPadding() {
  if (SizeConfig.isExtraWide) return 32;
  if (SizeConfig.isWideScreen) return 28;
  return 20;
}

/// Returns the number of grid columns based on screen width.
int getAdaptiveGridColumns() {
  if (SizeConfig.isExtraWide) return 6;
  if (SizeConfig.isWideScreen) return 4;
  return 2;
}
