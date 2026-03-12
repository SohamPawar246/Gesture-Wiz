import 'dart:collection';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Tracks player behavior and computes a "detection level" for the
/// Big Brother surveillance mechanic.
///
/// Detection rises when the player:
///   1. Moves hands erratically (high wrist velocity)
///   2. Fires actions in rapid succession (spam detection)
///
/// Detection decays slowly when the player is calm.
/// If detection stays at red for [gameOverDuration] continuous seconds → game over.
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
  static const double yellowThreshold = 0.28;
  static const double redThreshold = 0.60;
  static const double gameOverDuration = 4.5;

  // ── Tuning constants ──
  static const double velocityGain = 8.0;
  static const double actionFireGain = 0.10;
  static const double rapidFireMultiplier = 0.9;
  static const double rapidFireWindow = 3.0;
  static const double baseDecayRate = 0.05;
  static const double greenDecayRate = 0.07;

  // ── Velocity smoothing (rolling average over N frames) ──
  static const int _velocitySmoothFrames = 4;
  static const double _velocityFloor = 0.00005;
  static const double _maxGainPerFrame = 0.04;
  final Queue<double> _velocityHistory = Queue<double>();

  // ── Rolling window for action fires ──
  final Queue<double> _actionFireTimes = Queue<double>();
  double _gameTime = 0.0;

  /// Grace period after reset where no detection accumulates.
  double _graceTimer = 0.0;

  /// Push detection level to JS so the webcam overlay can colorize the
  /// bounding box. Uses globalContext for reliable cross-compilation writes.
  void _pushToJs(double level) {
    globalContext.setProperty('_bbDetectionLevel'.toJS, level.toJS);
  }

  /// Called each frame from FpvGame.update().
  void update(double dt, {double wristVelocitySq = 0.0}) {
    if (_triggered) return;

    // Grace period after a reset — no accumulation.
    if (_graceTimer > 0) {
      _graceTimer -= dt;
      _pushToJs(0.0);
      return;
    }

    _gameTime += dt;

    // Prune old fire events from the rolling window
    while (_actionFireTimes.isNotEmpty &&
        _gameTime - _actionFireTimes.first > rapidFireWindow) {
      _actionFireTimes.removeFirst();
    }

    // ── Velocity smoothing: rolling average to filter tracking noise ──
    _velocityHistory.addLast(wristVelocitySq);
    while (_velocityHistory.length > _velocitySmoothFrames) {
      _velocityHistory.removeFirst();
    }
    double smoothedVelocity = 0.0;
    for (final v in _velocityHistory) {
      smoothedVelocity += v;
    }
    smoothedVelocity /= _velocityHistory.length;

    // Accumulate detection from smoothed velocity (ignore below floor)
    if (smoothedVelocity > _velocityFloor) {
      final rawGain =
          (smoothedVelocity - _velocityFloor) * velocityGain * dt * 60.0;
      _detectionLevel += rawGain.clamp(0.0, _maxGainPerFrame);
    }

    // Decay — slower so gains actually accumulate
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
    _pushToJs(_detectionLevel);
  }

  /// Called when FpvGame fires an instant action (attack, push, ultimate).
  /// Sustained actions (shield, grab) should NOT call this.
  void onActionFired() {
    if (_graceTimer > 0) return;

    _actionFireTimes.addLast(_gameTime);

    final fireCount = _actionFireTimes.length;
    final gain = actionFireGain * (1.0 + (fireCount - 1) * rapidFireMultiplier);
    _detectionLevel = (_detectionLevel + gain).clamp(0.0, 1.0);

    // Also push immediately so the JS overlay responds to spam instantly
    _pushToJs(_detectionLevel);
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
    _velocityHistory.clear();
    _gameTime = 0.0;
    _graceTimer = 1.5;
    _pushToJs(0.0);
  }
}

enum SurveillanceZone { green, yellow, red }
