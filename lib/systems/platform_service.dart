import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Detects the current platform and provides platform-specific recommendations.
class PlatformService {
  static final PlatformService _instance = PlatformService._();
  static PlatformService get instance => _instance;

  PlatformService._();

  /// Current platform type
  PlatformType get platformType {
    if (kIsWeb) return PlatformType.web;
    if (Platform.isAndroid) return PlatformType.android;
    if (Platform.isIOS) return PlatformType.ios;
    if (Platform.isWindows) return PlatformType.windows;
    if (Platform.isMacOS) return PlatformType.macos;
    if (Platform.isLinux) return PlatformType.linux;
    return PlatformType.unknown;
  }

  /// Platform category for broader grouping
  PlatformCategory get category {
    switch (platformType) {
      case PlatformType.android:
      case PlatformType.ios:
        return PlatformCategory.mobile;
      case PlatformType.web:
        return PlatformCategory.web;
      case PlatformType.windows:
      case PlatformType.macos:
      case PlatformType.linux:
        return PlatformCategory.desktop;
      case PlatformType.unknown:
        return PlatformCategory.unknown;
    }
  }

  /// Whether platform is mobile
  bool get isMobile => category == PlatformCategory.mobile;

  /// Whether platform is desktop
  bool get isDesktop => category == PlatformCategory.desktop;

  /// Whether platform is web
  bool get isWeb => platformType == PlatformType.web;

  /// Whether platform likely supports webcam hand tracking
  bool get supportsHandTracking {
    return isDesktop || isWeb;
  }

  /// Whether platform should use touch input as primary
  bool get prefersTouchInput => isMobile;

  /// Whether platform can handle high quality effects by default
  bool get supportsHighQuality {
    // Desktop generally has better performance
    return isDesktop;
  }

  /// Recommended particle count limit based on platform
  int get recommendedParticleLimit {
    switch (category) {
      case PlatformCategory.mobile:
        return 100; // Conservative for mobile
      case PlatformCategory.web:
        return 200; // Moderate for web (varies by browser)
      case PlatformCategory.desktop:
        return 500; // Higher for desktop
      case PlatformCategory.unknown:
        return 150; // Conservative default
    }
  }

  /// Recommended target FPS based on platform
  double get recommendedTargetFps {
    // Most platforms target 60 FPS
    // Mobile might vary but we'll aim high and let auto-quality adjust
    return 60.0;
  }

  /// Platform display name
  String get displayName {
    switch (platformType) {
      case PlatformType.android:
        return 'Android';
      case PlatformType.ios:
        return 'iOS';
      case PlatformType.web:
        return 'Web';
      case PlatformType.windows:
        return 'Windows';
      case PlatformType.macos:
        return 'macOS';
      case PlatformType.linux:
        return 'Linux';
      case PlatformType.unknown:
        return 'Unknown';
    }
  }

  /// Get platform-specific input hint
  String get inputHint {
    if (prefersTouchInput) {
      return 'Tap and drag to control';
    } else if (supportsHandTracking) {
      return 'Use hand gestures or mouse';
    } else {
      return 'Use mouse to control';
    }
  }
}

/// Platform types
enum PlatformType { android, ios, web, windows, macos, linux, unknown }

/// Platform categories
enum PlatformCategory { mobile, desktop, web, unknown }
