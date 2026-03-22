import 'package:flutter/material.dart';
import 'gesture/gesture_type.dart';

/// Handles touch input and converts it to simulated hand tracking data for mobile.
class TouchInputHandler {
  Vector2? _currentTouchPosition;
  bool _isTouching = false;
  GestureType _currentGesture = GestureType.none;
  int _tapCount = 0;
  DateTime? _lastTapTime;

  static const Duration _doubleTapWindow = Duration(milliseconds: 300);
  static const Duration _longPressThreshold = Duration(milliseconds: 500);
  DateTime? _touchStartTime;

  /// Current touch position (normalized 0-1)
  Vector2? get touchPosition => _currentTouchPosition;

  /// Whether user is currently touching the screen
  bool get isTouching => _isTouching;

  /// Current gesture derived from touch interaction
  GestureType get currentGesture => _currentGesture;

  /// Handle touch down event
  void onTouchDown(Offset position, Size screenSize) {
    _isTouching = true;
    _touchStartTime = DateTime.now();

    // Normalize position to 0-1 range
    _currentTouchPosition = Vector2(
      position.dx / screenSize.width,
      position.dy / screenSize.height,
    );

    // Track tap count for multi-tap gestures
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleTapWindow) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;

    // Default to open palm when first touching
    _currentGesture = GestureType.openPalm;
  }

  /// Handle touch move event
  void onTouchMove(Offset position, Size screenSize) {
    if (!_isTouching) return;

    _currentTouchPosition = Vector2(
      position.dx / screenSize.width,
      position.dy / screenSize.height,
    );

    // Update gesture based on hold duration
    final now = DateTime.now();
    if (_touchStartTime != null &&
        now.difference(_touchStartTime!) > _longPressThreshold) {
      // Long press = fist (power attack gesture)
      _currentGesture = GestureType.fist;
    }
  }

  /// Handle touch up event
  void onTouchUp() {
    _isTouching = false;

    // Determine final gesture based on tap pattern
    if (_tapCount == 2) {
      // Double tap = pinch (grab gesture)
      _currentGesture = GestureType.pinch;
    } else if (_tapCount == 3) {
      // Triple tap = V sign (special ability)
      _currentGesture = GestureType.vSign;
    } else {
      final now = DateTime.now();
      if (_touchStartTime != null &&
          now.difference(_touchStartTime!) < _longPressThreshold) {
        // Short tap = point (quick attack)
        _currentGesture = GestureType.point;
      }
      // Long press already set gesture to fist during move
    }

    // Reset after a delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isTouching) {
        _currentGesture = GestureType.none;
      }
    });
  }

  /// Reset all state
  void reset() {
    _currentTouchPosition = null;
    _isTouching = false;
    _currentGesture = GestureType.none;
    _tapCount = 0;
    _lastTapTime = null;
    _touchStartTime = null;
  }

  /// Get simulated hand tracking result
  GestureResult getGestureResult() {
    return GestureResult(_currentGesture, _isTouching ? 1.0 : 0.0);
  }

  /// Get touch position as screen coordinates (for cursor display)
  Offset? getScreenPosition(Size screenSize) {
    if (_currentTouchPosition == null) return null;
    return Offset(
      _currentTouchPosition!.x * screenSize.width,
      _currentTouchPosition!.y * screenSize.height,
    );
  }
}

/// Simple 2D vector for normalized positions
class Vector2 {
  final double x;
  final double y;

  const Vector2(this.x, this.y);

  @override
  String toString() => 'Vector2($x, $y)';
}
