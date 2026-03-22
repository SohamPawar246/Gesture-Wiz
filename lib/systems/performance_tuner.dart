import 'dart:async';
import 'package:flutter/foundation.dart';
import 'performance_monitor.dart';
import 'platform_service.dart';
import 'settings_manager.dart';

/// Manages dynamic performance tuning and quality adjustments.
class PerformanceTuner extends ChangeNotifier {
  static final PerformanceTuner _instance = PerformanceTuner._();
  static PerformanceTuner get instance => _instance;

  PerformanceTuner._();

  Timer? _tuningTimer;
  QualityLevel _activeQuality = QualityLevel.high;
  int _consecutiveLowFpsFrames = 0;
  int _consecutiveHighFpsFrames = 0;

  // Tuning parameters
  static const int _framesBeforeDowngrade = 180; // 3 seconds at 60 FPS
  static const int _framesBeforeUpgrade = 300; // 5 seconds at 60 FPS
  static const double _upgradeThreshold = 57.0; // FPS to consider upgrade
  static const double _downgradeThreshold = 45.0; // FPS to trigger downgrade

  /// Current active quality level
  QualityLevel get activeQuality => _activeQuality;

  /// Quality settings derived from active quality
  QualitySettings get settings => QualitySettings.fromLevel(_activeQuality);

  /// Initialize tuner with platform-appropriate defaults
  void initialize() {
    final platform = PlatformService.instance;
    final settings = SettingsManager();

    // Set initial quality based on platform if auto-quality is on
    if (settings.autoQuality) {
      _activeQuality = platform.supportsHighQuality
          ? QualityLevel.high
          : QualityLevel.medium;
    } else {
      _activeQuality = settings.qualityLevel;
    }

    // Start monitoring performance every frame
    _tuningTimer?.cancel();
    _tuningTimer = Timer.periodic(
      const Duration(milliseconds: 100), // Check every 100ms
      (_) => _updateQuality(),
    );

    notifyListeners();
  }

  /// Stop tuning (cleanup)
  void dispose() {
    _tuningTimer?.cancel();
    _tuningTimer = null;
    super.dispose();
  }

  /// Update quality based on performance
  void _updateQuality() {
    final settings = SettingsManager();

    // If auto-quality is off, use manual setting
    if (!settings.autoQuality) {
      if (_activeQuality != settings.qualityLevel) {
        _activeQuality = settings.qualityLevel;
        notifyListeners();
      }
      return;
    }

    final monitor = PerformanceMonitor.instance;
    final currentFps = monitor.currentFps;

    // Track consecutive low FPS frames
    if (currentFps < _downgradeThreshold) {
      _consecutiveLowFpsFrames++;
      _consecutiveHighFpsFrames = 0;

      // Downgrade quality if consistently low FPS
      if (_consecutiveLowFpsFrames >= _framesBeforeDowngrade) {
        _tryDowngradeQuality();
        _consecutiveLowFpsFrames = 0;
      }
    }
    // Track consecutive high FPS frames
    else if (currentFps >= _upgradeThreshold) {
      _consecutiveHighFpsFrames++;
      _consecutiveLowFpsFrames = 0;

      // Upgrade quality if consistently high FPS
      if (_consecutiveHighFpsFrames >= _framesBeforeUpgrade) {
        _tryUpgradeQuality();
        _consecutiveHighFpsFrames = 0;
      }
    }
    // Reset counters if FPS is in the middle range
    else {
      _consecutiveLowFpsFrames = 0;
      _consecutiveHighFpsFrames = 0;
    }
  }

  /// Try to downgrade quality level
  void _tryDowngradeQuality() {
    final newQuality = switch (_activeQuality) {
      QualityLevel.high => QualityLevel.medium,
      QualityLevel.medium => QualityLevel.low,
      QualityLevel.low => QualityLevel.minimal,
      QualityLevel.minimal => null, // Can't go lower
    };

    if (newQuality != null) {
      if (kDebugMode) {
        print('Performance Tuner: Downgrading quality to ${newQuality.name}');
      }
      _activeQuality = newQuality;
      notifyListeners();
    }
  }

  /// Try to upgrade quality level
  void _tryUpgradeQuality() {
    final newQuality = switch (_activeQuality) {
      QualityLevel.minimal => QualityLevel.low,
      QualityLevel.low => QualityLevel.medium,
      QualityLevel.medium => QualityLevel.high,
      QualityLevel.high => null, // Can't go higher
    };

    if (newQuality != null) {
      if (kDebugMode) {
        print('Performance Tuner: Upgrading quality to ${newQuality.name}');
      }
      _activeQuality = newQuality;
      notifyListeners();
    }
  }

  /// Force a specific quality level (bypasses auto-tuning for this frame)
  void setQuality(QualityLevel level) {
    _activeQuality = level;
    _consecutiveLowFpsFrames = 0;
    _consecutiveHighFpsFrames = 0;
    notifyListeners();
  }

  /// Reset tuning state
  void reset() {
    _consecutiveLowFpsFrames = 0;
    _consecutiveHighFpsFrames = 0;
    initialize();
  }
}

/// Quality-specific settings for rendering
class QualitySettings {
  final int maxParticles;
  final double particleLifetimeMultiplier;
  final bool showTrails;
  final bool showGlow;
  final int maxProjectiles;
  final bool enablePostProcessing;

  const QualitySettings({
    required this.maxParticles,
    required this.particleLifetimeMultiplier,
    required this.showTrails,
    required this.showGlow,
    required this.maxProjectiles,
    required this.enablePostProcessing,
  });

  /// Create settings from quality level
  factory QualitySettings.fromLevel(QualityLevel level) {
    return switch (level) {
      QualityLevel.high => const QualitySettings(
        maxParticles: 500,
        particleLifetimeMultiplier: 1.0,
        showTrails: true,
        showGlow: true,
        maxProjectiles: 100,
        enablePostProcessing: true,
      ),
      QualityLevel.medium => const QualitySettings(
        maxParticles: 250,
        particleLifetimeMultiplier: 0.75,
        showTrails: true,
        showGlow: true,
        maxProjectiles: 75,
        enablePostProcessing: true,
      ),
      QualityLevel.low => const QualitySettings(
        maxParticles: 100,
        particleLifetimeMultiplier: 0.5,
        showTrails: false,
        showGlow: true,
        maxProjectiles: 50,
        enablePostProcessing: false,
      ),
      QualityLevel.minimal => const QualitySettings(
        maxParticles: 50,
        particleLifetimeMultiplier: 0.3,
        showTrails: false,
        showGlow: false,
        maxProjectiles: 30,
        enablePostProcessing: false,
      ),
    };
  }

  /// Get platform-adjusted settings
  factory QualitySettings.forPlatform(QualityLevel level) {
    final platform = PlatformService.instance;
    final base = QualitySettings.fromLevel(level);

    // Apply platform-specific limits
    final platformParticleLimit = platform.recommendedParticleLimit;

    return QualitySettings(
      maxParticles: base.maxParticles.clamp(0, platformParticleLimit),
      particleLifetimeMultiplier: base.particleLifetimeMultiplier,
      showTrails: base.showTrails && !platform.isMobile,
      showGlow: base.showGlow,
      maxProjectiles: base.maxProjectiles,
      enablePostProcessing: base.enablePostProcessing && platform.isDesktop,
    );
  }
}
