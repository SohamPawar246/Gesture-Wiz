import 'dart:collection';
import 'dart:math';
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
  static const double yellowThreshold = 0.30;
  static const double redThreshold = 0.62;
  static const double gameOverDuration = 5.0;

  // ── Tuning constants ──
  static const double actionFireGain = 0.08;
  static const double rapidFireMultiplier = 0.55;
  static const double rapidFireWindow = 2.2;
  static const double actionMinInterval = 0.14;
  static const double baseDecayRate = 0.17;
  static const double greenDecayRate = 0.26;

  // ── Movement signal shaping ──
  // Ignore near-zero jitter and hard-reject impossible one-frame spikes.
  static const double _velocityNoiseFloor = 0.00005;
  static const double _velocityCautionStart = 0.00055;
  static const double _velocityDangerStart = 0.0018;
  static const double _velocityGlitchCutoff = 0.035;
  static const double _velocityEmaFast = 0.35;
  static const double _velocityEmaSlow = 0.16;

  static const double _movementEvidenceRise = 1.70;
  static const double _movementEvidenceFall = 1.25;
  static const double _maxMovementGainPerSecond = 0.30;
  static const double _maxGainPerFrame = 0.040;

  double _velocityEma = 0.0;
  double _movementEvidence = 0.0;

  // ── Rolling window for action fires ──
  final Queue<double> _actionFireTimes = Queue<double>();
  double _gameTime = 0.0;
  double _lastActionAt = -999.0;

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

    // ── Movement detection with jitter filtering and evidence accumulation ──
    if (wristVelocitySq > 0.0) {
      if (wristVelocitySq < _velocityGlitchCutoff) {
        final alpha = wristVelocitySq > _velocityEma
            ? _velocityEmaFast
            : _velocityEmaSlow;
        _velocityEma += alpha * (wristVelocitySq - _velocityEma);
      } else {
        // Tracking swaps can create impossible jumps; treat those as noise.
        _velocityEma *= 0.85;
      }

      final normalized =
          ((_velocityEma - _velocityCautionStart) /
                  (_velocityDangerStart - _velocityCautionStart))
              .clamp(0.0, 1.0);

      if (normalized > 0.0) {
        _movementEvidence +=
            (0.45 + 0.55 * normalized * normalized) *
            _movementEvidenceRise *
            dt;
      } else {
        final extra = _velocityEma < _velocityNoiseFloor ? 0.35 : 0.0;
        _movementEvidence -= (_movementEvidenceFall + extra) * dt;
      }
    } else {
      _movementEvidence -= (_movementEvidenceFall + 0.25) * dt;
      _velocityEma *= 0.90;
    }

    _movementEvidence = _movementEvidence.clamp(0.0, 1.0);

    if (_movementEvidence > 0.0) {
      final rawGain =
          pow(_movementEvidence, 1.35) * _maxMovementGainPerSecond * dt;
      _detectionLevel += rawGain.clamp(0.0, _maxGainPerFrame);
    }

    // Decay with stronger recovery when the player is calm.
    final calmBonus = (_movementEvidence < 0.10 && _actionFireTimes.length <= 1)
        ? 0.06
        : 0.0;
    final decayRate = _detectionLevel < yellowThreshold
        ? (greenDecayRate + calmBonus)
        : (baseDecayRate + calmBonus * 0.5);
    final redRecoveryBoost =
        (_detectionLevel >= redThreshold && _movementEvidence < 0.08)
        ? 0.22
        : 0.0;
    _detectionLevel -= (decayRate + redRecoveryBoost) * dt;

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

    // Coalesce duplicated triggers from the same cast animation.
    if (_gameTime - _lastActionAt < actionMinInterval) return;
    _lastActionAt = _gameTime;

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
    _velocityEma = 0.0;
    _movementEvidence = 0.0;
    _gameTime = 0.0;
    _lastActionAt = -999.0;
    _graceTimer = 1.5;
    _pushToJs(0.0);
  }
}

enum SurveillanceZone { green, yellow, red }
