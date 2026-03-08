import '../hand_tracking/landmark_model.dart';
import 'gesture_type.dart';

/// Stabilizes raw gesture detections by requiring a gesture to be held
/// for multiple consecutive frames before confirming.
///
/// Also implements:
/// - Per-gesture debounce tuning (instant actions need fewer frames)
/// - Cooldown after confirmation to prevent rapid re-triggering
/// - Velocity gate: suppresses ALL recognition when the hand is shaking violently
/// - Requires-rest gate: after an instant gesture fires, the user must return
///   to a neutral pose (none / openPalm) for [_restRequired] frames before the
///   same or any other instant gesture can fire again.
class GestureStateMachine {
  GestureType _currentGesture = GestureType.none;
  GestureType _confirmedGesture = GestureType.none;
  int _framesHeld = 0;
  int _cooldownFrames = 0;

  /// Velocity gate state
  Landmark? _prevWrist;
  double _suppressionTimer = 0;

  /// Requires-rest state: set true after an instant gesture fires.
  /// Cleared only after the user holds a neutral pose for [_restRequired] frames.
  bool _needsReset = false;
  int _restFrames = 0;

  /// How many consecutive neutral frames are needed to exit the requires-rest state.
  static const int _restRequired = 5;

  /// Normalized velocity threshold — if wrist moves more than this between frames,
  /// we assume the hand is shaking and suppress all gesture recognition.
  static const double _velocityThreshold = 0.12;

  /// How long (in seconds) to suppress after a violent shake is detected.
  static const double _suppressionDuration = 0.15;

  /// How many consecutive frames a gesture must be detected to be confirmed.
  final int debounceFrames;

  /// Frames to wait after confirming a gesture before it can re-trigger.
  final int cooldownAfterConfirm;

  GestureStateMachine({
    this.debounceFrames = 3,
    this.cooldownAfterConfirm = 2,
  });

  /// Process a frame with velocity gate.
  /// [detectedThisFrame] — raw gesture from recognizer.
  /// [landmarks] — raw landmark list (for velocity computation). Can be null.
  /// [dt] — frame delta time in seconds.
  GestureType processFrame(
    GestureType detectedThisFrame, {
    List<Landmark>? landmarks,
    double dt = 0.016,
  }) {
    // --- Velocity gate ---
    if (_suppressionTimer > 0) {
      _suppressionTimer -= dt;
      _prevWrist = landmarks != null && landmarks.isNotEmpty ? landmarks[0] : _prevWrist;
      return GestureType.none;
    }

    if (landmarks != null && landmarks.isNotEmpty) {
      final wrist = landmarks[0];
      if (_prevWrist != null) {
        final dx = wrist.x - _prevWrist!.x;
        final dy = wrist.y - _prevWrist!.y;
        final velocity = (dx * dx + dy * dy);
        if (velocity > _velocityThreshold * _velocityThreshold) {
          _suppressionTimer = _suppressionDuration;
          _prevWrist = wrist;
          _framesHeld = 0;
          _currentGesture = GestureType.none;
          return GestureType.none;
        }
      }
      _prevWrist = wrist;
    }

    // --- Requires-rest gate ---
    // After an instant gesture fires, block everything until the user holds
    // a neutral / open-palm pose for _restRequired consecutive frames.
    if (_needsReset) {
      final isNeutral = detectedThisFrame == GestureType.none ||
                        detectedThisFrame == GestureType.openPalm;
      if (isNeutral) {
        _restFrames++;
        if (_restFrames >= _restRequired) {
          _needsReset = false;
          _restFrames = 0;
          _confirmedGesture = GestureType.none;
        }
      } else {
        _restFrames = 0;
      }
      return GestureType.none;
    }

    // --- Cooldown active — suppress all output ---
    if (_cooldownFrames > 0) {
      _cooldownFrames--;
      return GestureType.none;
    }

    // --- Debounce logic ---
    if (detectedThisFrame == _currentGesture) {
      _framesHeld++;
    } else {
      _currentGesture = detectedThisFrame;
      _framesHeld = 1;
    }

    // For sustained gestures (openPalm, pinch), confirm faster and
    // keep returning the gesture continuously while held.
    final isSustained = _currentGesture == GestureType.openPalm ||
                        _currentGesture == GestureType.pinch;

    final requiredFrames = isSustained ? 2 : debounceFrames;

    if (_framesHeld >= requiredFrames) {
      if (_currentGesture != GestureType.none) {
        if (isSustained) {
          // Sustained gestures: return continuously, no cooldown
          _confirmedGesture = _currentGesture;
          return _confirmedGesture;
        } else if (_currentGesture != _confirmedGesture) {
          // Instant gestures: fire once, then require rest before re-firing
          _confirmedGesture = _currentGesture;
          _cooldownFrames = cooldownAfterConfirm;
          _needsReset = true;
          _restFrames = 0;
          return _confirmedGesture;
        }
      }

      if (_currentGesture == GestureType.none) {
        _confirmedGesture = GestureType.none;
      }
      return _currentGesture;
    }

    return GestureType.none;
  }

  void reset() {
    _currentGesture = GestureType.none;
    _confirmedGesture = GestureType.none;
    _framesHeld = 0;
    _cooldownFrames = 0;
    _suppressionTimer = 0;
    _prevWrist = null;
    _needsReset = false;
    _restFrames = 0;
  }
}
