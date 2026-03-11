import 'package:flutter/foundation.dart';

import '../systems/hand_tracking/tracking_service.dart';
import '../systems/gesture/rule_based_recognizer.dart';
import '../systems/gesture/gesture_state_machine.dart';
import '../systems/gesture/gesture_type.dart';

/// Tracks the hand position and gesture for cursor-based UI navigation on
/// the main menu and game over screens. Updated each frame by a Ticker in
/// GameScreen via [update].
class GestureCursorController extends ChangeNotifier {
  // ── Cursor position (normalized 0–1 screen space, index fingertip) ──
  double posX = 0.5;
  double posY = 0.5;

  /// True when at least one hand is visible to the tracking service.
  bool isVisible = false;

  /// Current stable gesture.
  GestureType gestureType = GestureType.none;

  /// True while a pinch is held.
  bool isPinching = false;

  /// True only on the single frame the pinch first becomes active (rising edge).
  bool pinchJustFired = false;

  /// Smoothed face position (normalized 0–1). Updated every frame from
  /// [TrackingService.facePosition], independent of hand visibility.
  double faceX = 0.5;
  double faceY = 0.5;

  // ── Dwell state — managed cooperatively with GestureTapTargets ──────
  /// 0–1 fill of the dwell ring drawn on the cursor.
  double dwellProgress = 0.0;

  /// ID of the GestureTapTarget currently controlling dwell.
  int? _activeTargetId;

  // ── Internal helpers ─────────────────────────────────────────────────
  double _smoothX = 0.5;
  double _smoothY = 0.5;
  bool _prevPinching = false;

  /// While > 0, GestureTapTargets will not accumulate dwell.
  /// Triggered after any button click to prevent immediate re-fire on a new screen.
  double globalCooldown = 0.0;

  final _recognizer = RuleBasedRecognizer();
  final _stateMachine = GestureStateMachine();

  // ── Called from GameScreen's Ticker ──────────────────────────────────
  void update(TrackingService service, double dt) {
    if (globalCooldown > 0) globalCooldown -= dt;
    // Web service needs an explicit poll each frame.
    try {
      // ignore: avoid_dynamic_calls
      (service as dynamic).poll();
    } catch (_) {}

    final landmarks = service.getHandLandmarks(0);
    if (landmarks != null && landmarks.isNotEmpty) {
      isVisible = true;

      // Index fingertip = MediaPipe landmark 8.
      final tip = landmarks.length > 8 ? landmarks[8] : landmarks[0];
      _smoothX += (tip.x - _smoothX) * 0.65;
      _smoothY += (tip.y - _smoothY) * 0.65;
      posX = _smoothX.clamp(0.0, 1.0);
      posY = _smoothY.clamp(0.0, 1.0);

      final raw = _recognizer.recognize(landmarks);
      gestureType = _stateMachine.processFrame(
        raw,
        dt: dt,
      );

      _prevPinching = isPinching;
      isPinching = gestureType == GestureType.pinch;
      pinchJustFired = isPinching && !_prevPinching;
    } else {
      isVisible = false;
      gestureType = GestureType.none;
      _prevPinching = isPinching;
      isPinching = false;
      pinchJustFired = false;
    }

    // Face tracking is independent of hand visibility — update every frame.
    final face = service.facePosition;
    if (face != null) {
      faceX += (face.x - faceX) * 0.55;
      faceY += (face.y - faceY) * 0.55;
    } else {
      faceX += (0.5 - faceX) * dt * 2.0;
      faceY += (0.5 - faceY) * dt * 2.0;
    }

    notifyListeners();
  }

  // ── Dwell API for GestureTapTargets ──────────────────────────────────

  /// Called when a target begins being hovered.
  void startDwell(int targetId) {
    _activeTargetId = targetId;
    dwellProgress = 0.0;
  }

  /// Called each frame while a target is hovered with the current progress.
  void updateDwell(int targetId, double progress) {
    if (_activeTargetId == targetId) {
      dwellProgress = progress;
    }
  }

  /// Called when a target is no longer hovered (or fires).
  void endDwell(int targetId) {
    if (_activeTargetId == targetId) {
      _activeTargetId = null;
      dwellProgress = 0.0;
    }
  }

  /// Prevent any button from accumulating dwell for [seconds] seconds.
  /// Call this immediately after a button fires to avoid instant re-click
  /// on the next screen.
  void triggerGlobalCooldown(double seconds) {
    globalCooldown = seconds;
    _activeTargetId = null;
    dwellProgress = 0.0;
  }
}
