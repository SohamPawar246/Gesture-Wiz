import 'dart:collection';
import 'dart:js_interop';

/// Sets window._bbDetectionLevel on the JS side so the webcam overlay
/// can read it each frame and colorize the bounding box accordingly.
@JS('_bbDetectionLevel')
external set _jsBbDetectionLevel(JSNumber value);

/// Tracks player behavior and computes a "detection level" for the
/// Big Brother surveillance mechanic.
///
/// Detection rises when the player:
///   1. Moves hands erratically (high wrist velocity)
///   2. Fires actions in rapid succession (spam detection)
///
/// Detection decays slowly when the player is calm.
/// If detection stays at red (>= 0.7) for 5 continuous seconds, game over.
class SurveillanceSystem {
  /// Current detection level: 0.0 (invisible) to 1.0 (fully detected).
  double _detectionLevel = 0.0;
  double get detectionLevel => _detectionLevel;

  /// How long detection has been >= red threshold continuously.
  double _timeAtRed = 0.0;
  double get timeAtRed => _timeAtRed;

  /// Whether Big Brother has triggered game over.
  bool _triggered = false;
  bool get triggered => _triggered;

  // ── Thresholds ──
  static const double yellowThreshold = 0.35;
  static const double redThreshold = 0.72;
  static const double gameOverDuration = 6.0;

  // ── Tuning constants ──
  static const double velocityGain = 4.5;
  static const double actionFireGain = 0.04;
  static const double rapidFireMultiplier = 0.6;
  static const double rapidFireWindow = 2.0;
  static const double baseDecayRate = 0.10;
  static const double greenDecayRate = 0.22;

  // ── Rolling window for action fires ──
  final Queue<double> _actionFireTimes = Queue<double>();
  double _gameTime = 0.0;

  /// Grace period after reset where no detection accumulates.
  double _graceTimer = 0.0;

  /// Called each frame from FpvGame.update().
  ///
  /// [dt] - frame delta time in seconds.
  /// [wristVelocitySq] - squared distance the wrist moved this frame.
  ///   Pass 0.0 if no hand is tracked.
  void update(double dt, {double wristVelocitySq = 0.0}) {
    if (_triggered) return;

    // Grace period after a reset — no accumulation, just push zero to JS.
    if (_graceTimer > 0) {
      _graceTimer -= dt;
      _jsBbDetectionLevel = (0.0).toJS;
      return;
    }

    _gameTime += dt;

    // Prune old fire events from the rolling window
    while (_actionFireTimes.isNotEmpty &&
        _gameTime - _actionFireTimes.first > rapidFireWindow) {
      _actionFireTimes.removeFirst();
    }

    // Accumulate detection from velocity (ignore micro-jitter below floor)
    const double velocityFloor = 0.003;
    if (wristVelocitySq > velocityFloor) {
      _detectionLevel +=
          (wristVelocitySq - velocityFloor) * velocityGain * dt * 60.0;
    }

    // Decay
    final decayRate = _detectionLevel < yellowThreshold
        ? greenDecayRate
        : baseDecayRate;
    _detectionLevel -= decayRate * dt;

    // Clamp
    _detectionLevel = _detectionLevel.clamp(0.0, 1.0);

    // Red timer tracking
    if (_detectionLevel >= redThreshold) {
      _timeAtRed += dt;
      if (_timeAtRed >= gameOverDuration) {
        _triggered = true;
      }
    } else {
      _timeAtRed = 0.0;
    }

    // Push to JS for webcam overlay
    _jsBbDetectionLevel = _detectionLevel.toJS;
  }

  /// Called when FpvGame fires an instant action (attack, push, ultimate).
  /// Sustained actions (shield, grab) should NOT call this.
  void onActionFired() {
    if (_graceTimer > 0) return;

    _actionFireTimes.addLast(_gameTime);

    final fireCount = _actionFireTimes.length;
    final gain = actionFireGain * (1.0 + (fireCount - 1) * rapidFireMultiplier);
    _detectionLevel = (_detectionLevel + gain).clamp(0.0, 1.0);
  }

  /// Current surveillance zone for external queries.
  SurveillanceZone get zone {
    if (_detectionLevel >= redThreshold) return SurveillanceZone.red;
    if (_detectionLevel >= yellowThreshold) return SurveillanceZone.yellow;
    return SurveillanceZone.green;
  }

  void reset() {
    _detectionLevel = 0.0;
    _timeAtRed = 0.0;
    _triggered = false;
    _actionFireTimes.clear();
    _gameTime = 0.0;
    _graceTimer = 1.0; // 1 second grace after restart
    _jsBbDetectionLevel = (0.0).toJS;
  }
}

enum SurveillanceZone { green, yellow, red }
