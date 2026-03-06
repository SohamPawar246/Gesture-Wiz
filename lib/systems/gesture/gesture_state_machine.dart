import 'gesture_type.dart';

/// Stabilizes raw gesture detections by requiring a gesture to be held
/// for multiple consecutive frames before confirming.
///
/// Also implements cooldown after a confirmed gesture to prevent rapid re-triggering.
class GestureStateMachine {
  GestureType _currentGesture = GestureType.none;
  GestureType _confirmedGesture = GestureType.none;
  int _framesHeld = 0;
  int _cooldownFrames = 0;
  
  /// How many consecutive frames a gesture must be detected to be confirmed.
  /// Higher = more stable but slower to react.
  final int debounceFrames;

  /// Frames to wait after confirming a gesture before it can re-trigger.
  final int cooldownAfterConfirm;

  GestureStateMachine({
    this.debounceFrames = 3,       // ~50ms at 60fps — snappy without being too sensitive
    this.cooldownAfterConfirm = 3, // ~50ms dead zone after fire to prevent double-trigger
  });

  GestureType processFrame(GestureType detectedThisFrame) {
    // Cooldown active — suppress all output
    if (_cooldownFrames > 0) {
      _cooldownFrames--;
      return GestureType.none;
    }

    if (detectedThisFrame == _currentGesture) {
      _framesHeld++;
    } else {
      _currentGesture = detectedThisFrame;
      _framesHeld = 1;
    }

    // Confirm gesture once debounce threshold is met
    if (_framesHeld >= debounceFrames) {
      // Only fire once per gesture hold (not every frame after threshold)
      if (_currentGesture != _confirmedGesture && _currentGesture != GestureType.none) {
        _confirmedGesture = _currentGesture;
        _cooldownFrames = cooldownAfterConfirm;
        return _confirmedGesture;
      }
      // If gesture is 'none' held long enough, reset confirmed state
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
  }
}
