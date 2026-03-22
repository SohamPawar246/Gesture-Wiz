import 'package:flutter/foundation.dart';

/// Monitors game performance metrics (FPS, frame time, memory).
class PerformanceMonitor extends ChangeNotifier {
  static final PerformanceMonitor _instance = PerformanceMonitor._();
  static PerformanceMonitor get instance => _instance;

  PerformanceMonitor._();

  // FPS tracking
  final List<double> _frameTimes = [];
  static const int _sampleSize = 60; // Track last 60 frames
  double _currentFps = 60.0;
  double _avgFrameTime = 16.67; // ms (60 FPS baseline)
  double _minFps = 60.0;
  double _maxFps = 60.0;

  // Entity tracking
  int _enemyCount = 0;
  int _projectileCount = 0;
  int _particleCount = 0;

  // Performance thresholds
  static const double targetFps = 60.0;
  static const double warningFps = 45.0;
  static const double criticalFps = 30.0;

  // Getters
  double get currentFps => _currentFps;
  double get avgFrameTime => _avgFrameTime;
  double get minFps => _minFps;
  double get maxFps => _maxFps;
  int get enemyCount => _enemyCount;
  int get projectileCount => _projectileCount;
  int get particleCount => _particleCount;
  int get totalEntities => _enemyCount + _projectileCount + _particleCount;

  /// Performance status based on current FPS
  PerformanceStatus get status {
    if (_currentFps >= targetFps * 0.95) return PerformanceStatus.excellent;
    if (_currentFps >= warningFps) return PerformanceStatus.good;
    if (_currentFps >= criticalFps) return PerformanceStatus.warning;
    return PerformanceStatus.critical;
  }

  /// Update FPS calculation with delta time
  void recordFrame(double dt) {
    if (dt <= 0) return;

    // Convert dt (seconds) to frame time (milliseconds)
    final frameTimeMs = dt * 1000;
    _frameTimes.add(frameTimeMs);

    // Keep only recent samples
    if (_frameTimes.length > _sampleSize) {
      _frameTimes.removeAt(0);
    }

    // Calculate average frame time
    if (_frameTimes.isNotEmpty) {
      _avgFrameTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;

      // Calculate FPS from average frame time
      _currentFps = 1000 / _avgFrameTime;

      // Track min/max FPS over the sample window
      final instantFps = 1000 / frameTimeMs;
      if (_frameTimes.length >= _sampleSize) {
        // Only track min/max after we have a full sample
        _minFps = _frameTimes
            .map((ft) => 1000 / ft)
            .reduce((a, b) => a < b ? a : b);
        _maxFps = _frameTimes
            .map((ft) => 1000 / ft)
            .reduce((a, b) => a > b ? a : b);
      } else {
        _minFps = instantFps;
        _maxFps = instantFps;
      }

      notifyListeners();
    }
  }

  /// Update entity counts
  void updateEntityCounts({
    required int enemies,
    required int projectiles,
    required int particles,
  }) {
    _enemyCount = enemies;
    _projectileCount = projectiles;
    _particleCount = particles;
    notifyListeners();
  }

  /// Reset all statistics
  void reset() {
    _frameTimes.clear();
    _currentFps = 60.0;
    _avgFrameTime = 16.67;
    _minFps = 60.0;
    _maxFps = 60.0;
    _enemyCount = 0;
    _projectileCount = 0;
    _particleCount = 0;
    notifyListeners();
  }

  /// Get performance summary string
  String getSummary() {
    return 'FPS: ${_currentFps.toStringAsFixed(1)} '
        '(${_minFps.toStringAsFixed(0)}-${_maxFps.toStringAsFixed(0)}) | '
        'Frame: ${_avgFrameTime.toStringAsFixed(2)}ms | '
        'Entities: $totalEntities';
  }

  /// Check if performance is degraded
  bool get isPerformanceDegraded => _currentFps < warningFps;

  /// Get quality reduction recommendation
  QualityLevel getRecommendedQuality() {
    if (_currentFps >= targetFps * 0.95) return QualityLevel.high;
    if (_currentFps >= warningFps) return QualityLevel.medium;
    if (_currentFps >= criticalFps) return QualityLevel.low;
    return QualityLevel.minimal;
  }
}

/// Performance status levels
enum PerformanceStatus {
  excellent, // >= 57 FPS
  good, // >= 45 FPS
  warning, // >= 30 FPS
  critical, // < 30 FPS
}

/// Quality level recommendations
enum QualityLevel {
  high, // Full effects
  medium, // Reduced particles
  low, // Minimal effects
  minimal; // Only essential visuals

  static QualityLevel fromString(String? str) {
    return QualityLevel.values.firstWhere(
      (level) => level.name == str,
      orElse: () => QualityLevel.high,
    );
  }
}
