import 'gesture_type.dart';

/// Time-based gesture stabilization with confidence gating.
///
/// Two mechanisms:
///   1. Confirmation timer — gesture must persist for a time threshold
///      to confirm (time-based, not frame-based — works at any FPS).
///   2. Rest gate — after an instant gesture fires, requires brief neutral
///      pose before re-firing. Sustained gestures (shield/grab) bypass this.
class GestureStateMachine {
  GestureType _confirmedGesture = GestureType.none;
  GestureType _pendingGesture = GestureType.none;
  double _pendingTime = 0;

  // Rest gate
  bool _needsRest = false;
  double _restTimer = 0;

  // --- Tuning ---
  static const double _instantConfirmTime = 0.015;   // ~1 frame at 60fps
  static const double _sustainedConfirmTime = 0.01;   // Near-instant for shield/grab
  static const double _restDuration = 0.06;           // ~4 frames neutral before re-fire
  static const double _minConfidence = 0.30;           // Low gate for responsiveness

  /// Process one frame. Returns the confirmed gesture type.
  ///
  /// [result] — gesture with confidence from recognizer.
  /// [dt] — frame delta time in seconds.
  GestureType processFrame(GestureResult result, {required double dt}) {
    // === Rest gate ===
    if (_needsRest) {
      final isNeutral = result.type == GestureType.none ||
                        result.type == GestureType.openPalm;
      if (isNeutral) {
        _restTimer += dt;
        if (_restTimer >= _restDuration) {
          _needsRest = false;
          _restTimer = 0;
          _confirmedGesture = GestureType.none;
        }
      } else {
        _restTimer = 0;
      }

      // Sustained gestures bypass rest gate — player can fire bolt then
      // immediately shield without waiting
      final isSustained = result.type == GestureType.openPalm ||
                          result.type == GestureType.pinch;
      if (isSustained && result.confidence >= _minConfidence) {
        _needsRest = false;
        _restTimer = 0;
        _confirmedGesture = result.type;
        _pendingGesture = GestureType.none;
        _pendingTime = 0;
        return _confirmedGesture;
      }

      return GestureType.none;
    }

    // === Confidence gate ===
    if (result.confidence < _minConfidence) {
      _pendingTime = 0;
      _pendingGesture = GestureType.none;

      // Keep returning confirmed gesture for sustained actions (shield/grab)
      final wasSustained = _confirmedGesture == GestureType.openPalm ||
                           _confirmedGesture == GestureType.pinch;
      if (!wasSustained) {
        _confirmedGesture = GestureType.none;
      }
      return _confirmedGesture;
    }

    // === Already confirmed and same gesture continues ===
    if (result.type == _confirmedGesture) {
      _pendingTime = 0;
      _pendingGesture = GestureType.none;
      return _confirmedGesture;
    }

    // === New gesture building ===
    if (result.type == _pendingGesture) {
      _pendingTime += dt;
    } else {
      _pendingGesture = result.type;
      _pendingTime = dt;
    }

    final isSustained = _pendingGesture == GestureType.openPalm ||
                        _pendingGesture == GestureType.pinch;
    final threshold = isSustained ? _sustainedConfirmTime : _instantConfirmTime;

    if (_pendingTime >= threshold) {
      _confirmedGesture = _pendingGesture;
      _pendingGesture = GestureType.none;
      _pendingTime = 0;

      // Instant gestures trigger rest gate
      if (!isSustained) {
        _needsRest = true;
        _restTimer = 0;
      }

      return _confirmedGesture;
    }

    // Still building — return previous confirmed or none
    return _confirmedGesture;
  }

  void reset() {
    _confirmedGesture = GestureType.none;
    _pendingGesture = GestureType.none;
    _pendingTime = 0;
    _needsRest = false;
    _restTimer = 0;
  }
}
