import 'package:flame/components.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'landmark_model.dart';
import 'tracking_service.dart';

/// A fallback tracking service that uses mouse position and clicks
/// to simulate hand tracking when webcam/hand tracking is unavailable.
///
/// This enables the game to be played without a webcam by using:
/// - Mouse position -> Hand position (index fingertip)
/// - Left click -> Pinch gesture (for UI navigation)
/// - Right click -> Fist gesture (Force Push)
/// - Middle click / Shift+Click -> Open Palm (Shield)
class MouseTrackingService implements TrackingService {
  // Normalized mouse position (0-1)
  double _mouseX = 0.5;
  double _mouseY = 0.5;

  // Mouse button states
  bool _leftPressed = false;
  bool _rightPressed = false;
  bool _middlePressed = false;
  bool _shiftHeld = false;

  // Screen size for normalization
  double _screenWidth = 1920;
  double _screenHeight = 1080;

  bool _started = false;

  /// Update mouse position (call from Flutter's mouse listener)
  void updateMousePosition(double x, double y) {
    _mouseX = (_screenWidth > 0) ? (x / _screenWidth).clamp(0.0, 1.0) : 0.5;
    _mouseY = (_screenHeight > 0) ? (y / _screenHeight).clamp(0.0, 1.0) : 0.5;
  }

  /// Update screen size for normalization
  void updateScreenSize(double width, double height) {
    _screenWidth = width;
    _screenHeight = height;
  }

  /// Handle mouse button events
  void onPointerDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryMouseButton != 0) {
      _leftPressed = true;
    }
    if (event.buttons & kSecondaryMouseButton != 0) {
      _rightPressed = true;
    }
    if (event.buttons & kMiddleMouseButton != 0) {
      _middlePressed = true;
    }
  }

  void onPointerUp(PointerUpEvent event) {
    // Check which button was released
    _leftPressed = false;
    _rightPressed = false;
    _middlePressed = false;
  }

  void onPointerMove(PointerMoveEvent event) {
    updateMousePosition(event.position.dx, event.position.dy);
    // Update button states for drag
    _leftPressed = event.buttons & kPrimaryMouseButton != 0;
    _rightPressed = event.buttons & kSecondaryMouseButton != 0;
    _middlePressed = event.buttons & kMiddleMouseButton != 0;
  }

  void onPointerHover(PointerHoverEvent event) {
    updateMousePosition(event.position.dx, event.position.dy);
  }

  /// Handle keyboard for shift modifier
  void onKeyEvent(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
        event.logicalKey == LogicalKeyboardKey.shiftRight) {
      _shiftHeld = event is KeyDownEvent;
    }
  }

  @override
  List<Landmark>? getHandLandmarks(int handId) {
    // Only provide landmarks for hand 0 (single hand mode with mouse)
    if (handId != 0 || !_started) return null;

    // Generate MediaPipe-style landmarks from mouse position
    // We simulate a basic hand shape with the mouse at the index fingertip
    return _generateLandmarksFromMouse();
  }

  List<Landmark> _generateLandmarksFromMouse() {
    // MediaPipe hand has 21 landmarks (0-20)
    // Key landmarks:
    // 0 = wrist
    // 4 = thumb tip
    // 8 = index fingertip (we put the mouse cursor here)
    // 12 = middle fingertip
    // 16 = ring fingertip
    // 20 = pinky fingertip

    final landmarks = <Landmark>[];

    // Base positions relative to index fingertip (which is at mouse position)
    final tipX = _mouseX;
    final tipY = _mouseY;

    // Determine finger extension based on gesture
    double fingerExtension = 0.15; // Default: fingers extended (open hand)

    if (_leftPressed && !_shiftHeld) {
      // Pinch: thumb and index close together
      fingerExtension = 0.02;
    } else if (_rightPressed) {
      // Fist: all fingers curled
      fingerExtension = 0.03;
    } else if (_middlePressed || (_leftPressed && _shiftHeld)) {
      // Open palm: fingers spread
      fingerExtension = 0.18;
    }

    // Helper to create landmark
    Landmark lm(double x, double y, double z) => Landmark(x: x, y: y, z: z);

    // Generate 21 landmarks in MediaPipe order
    // Wrist (0)
    landmarks.add(lm(tipX, tipY + 0.15, 0.5));

    // Thumb (1-4)
    landmarks.add(lm(tipX - 0.08, tipY + 0.10, 0.5));
    landmarks.add(lm(tipX - 0.10, tipY + 0.06, 0.5));
    landmarks.add(lm(tipX - 0.11, tipY + 0.02, 0.5));

    // Thumb tip - close to index for pinch
    final thumbTipX = _leftPressed && !_shiftHeld
        ? tipX -
              0.01 // Close for pinch
        : tipX - 0.12; // Extended
    landmarks.add(lm(thumbTipX, tipY - fingerExtension * 0.3, 0.5));

    // Index finger (5-8)
    landmarks.add(lm(tipX - 0.02, tipY + 0.08, 0.5));
    landmarks.add(lm(tipX - 0.01, tipY + 0.04, 0.5));
    landmarks.add(lm(tipX, tipY + fingerExtension * 0.3, 0.5));
    landmarks.add(lm(tipX, tipY, 0.5)); // Index tip at mouse position

    // Middle finger (9-12)
    landmarks.add(lm(tipX + 0.02, tipY + 0.08, 0.5));
    landmarks.add(lm(tipX + 0.02, tipY + 0.04, 0.5));
    landmarks.add(lm(tipX + 0.02, tipY + fingerExtension * 0.2, 0.5));
    landmarks.add(lm(tipX + 0.02, tipY - fingerExtension, 0.5));

    // Ring finger (13-16)
    landmarks.add(lm(tipX + 0.05, tipY + 0.09, 0.5));
    landmarks.add(lm(tipX + 0.05, tipY + 0.05, 0.5));
    landmarks.add(lm(tipX + 0.05, tipY + fingerExtension * 0.3, 0.5));
    landmarks.add(lm(tipX + 0.05, tipY - fingerExtension * 0.9, 0.5));

    // Pinky (17-20)
    landmarks.add(lm(tipX + 0.08, tipY + 0.10, 0.5));
    landmarks.add(lm(tipX + 0.08, tipY + 0.06, 0.5));
    landmarks.add(lm(tipX + 0.08, tipY + fingerExtension * 0.4, 0.5));
    landmarks.add(lm(tipX + 0.08, tipY - fingerExtension * 0.8, 0.5));

    return landmarks;
  }

  @override
  Vector2? get facePosition {
    // No face tracking with mouse - return center
    return Vector2(0.5, 0.5);
  }

  @override
  int get handCount => _started ? 1 : 0;

  @override
  bool get isConnected => _started;

  @override
  Future<void> start() async {
    _started = true;
  }

  @override
  void dispose() {
    _started = false;
  }

  /// For compatibility with web tracking service poll pattern
  void poll() {
    // No-op for mouse tracking - state is updated via event handlers
  }
}
