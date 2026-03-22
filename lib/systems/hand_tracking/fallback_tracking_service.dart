import 'dart:async';
import 'package:flame/components.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'landmark_model.dart';
import 'tracking_service.dart';
import 'mouse_tracking_service.dart';
import '../error_notification_service.dart';

/// A tracking service that wraps another service and falls back to mouse
/// tracking when the primary service loses connection or fails to initialize.
///
/// This provides graceful degradation for players without webcams or when
/// hand tracking isn't working properly.
class FallbackTrackingService implements TrackingService {
  final TrackingService _primary;
  final MouseTrackingService _mouse = MouseTrackingService();

  bool _useMouseFallback = false;
  bool _hasNotifiedFallback = false;
  bool _started = false;

  // Track how long primary has been disconnected
  double _disconnectedTime = 0;
  static const double _fallbackThreshold = 3.0; // seconds

  // Allow manual override to force mouse mode
  bool forceMouseMode = false;

  FallbackTrackingService(this._primary);

  /// The mouse tracking service for direct event handling
  MouseTrackingService get mouseService => _mouse;

  /// Whether currently using mouse fallback
  bool get isUsingMouseFallback => _useMouseFallback || forceMouseMode;

  /// Forward pointer events to mouse service
  void onPointerDown(PointerDownEvent event) => _mouse.onPointerDown(event);
  void onPointerUp(PointerUpEvent event) => _mouse.onPointerUp(event);
  void onPointerMove(PointerMoveEvent event) => _mouse.onPointerMove(event);
  void onPointerHover(PointerHoverEvent event) => _mouse.onPointerHover(event);
  void onKeyEvent(KeyEvent event) => _mouse.onKeyEvent(event);
  void updateScreenSize(double w, double h) => _mouse.updateScreenSize(w, h);

  @override
  List<Landmark>? getHandLandmarks(int handId) {
    if (forceMouseMode || _useMouseFallback) {
      return _mouse.getHandLandmarks(handId);
    }

    final primaryLandmarks = _primary.getHandLandmarks(handId);
    if (primaryLandmarks != null && primaryLandmarks.isNotEmpty) {
      return primaryLandmarks;
    }

    // If primary returns null, check if we should use mouse
    if (_useMouseFallback) {
      return _mouse.getHandLandmarks(handId);
    }

    return null;
  }

  @override
  Vector2? get facePosition {
    if (forceMouseMode || _useMouseFallback) {
      return _mouse.facePosition;
    }
    return _primary.facePosition ?? _mouse.facePosition;
  }

  @override
  int get handCount {
    if (forceMouseMode || _useMouseFallback) {
      return _mouse.handCount;
    }
    final primary = _primary.handCount;
    return primary > 0 ? primary : (_useMouseFallback ? _mouse.handCount : 0);
  }

  @override
  bool get isConnected {
    if (forceMouseMode) return _mouse.isConnected;
    return _primary.isConnected || _mouse.isConnected;
  }

  @override
  Future<void> start() async {
    _started = true;

    // Start both services
    await _mouse.start();

    try {
      await _primary.start().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _enableMouseFallback(
            reason: 'Hand tracking initialization timed out',
          );
        },
      );
    } catch (e) {
      _enableMouseFallback(reason: 'Hand tracking failed to start: $e');
    }
  }

  @override
  Future<bool> requestCameraPermission() async {
    final granted = await _primary.requestCameraPermission();
    if (!granted) {
      forceMouseMode = true;
      _useMouseFallback = true;
    }
    return granted;
  }

  @override
  void dispose() {
    _started = false;
    _primary.dispose();
    _mouse.dispose();
  }

  /// Call each frame to check connection status and trigger fallback
  void update(double dt) {
    if (!_started || forceMouseMode) return;

    if (!_primary.isConnected || _primary.handCount == 0) {
      _disconnectedTime += dt;

      if (_disconnectedTime >= _fallbackThreshold && !_useMouseFallback) {
        _enableMouseFallback(
          reason:
              'Hand tracking lost for ${_fallbackThreshold.toInt()} seconds',
        );
      }
    } else {
      _disconnectedTime = 0;

      // If primary reconnects, disable fallback
      if (_useMouseFallback && !forceMouseMode) {
        _useMouseFallback = false;
        _hasNotifiedFallback = false;
        ErrorNotificationService.instance.info(
          'Hand Tracking Restored',
          'Switched back to webcam hand tracking.',
        );
      }
    }
  }

  void _enableMouseFallback({required String reason}) {
    _useMouseFallback = true;

    if (!_hasNotifiedFallback) {
      _hasNotifiedFallback = true;
      ErrorNotificationService.instance.handTrackingUnavailable(
        onRetry: () => _retryPrimaryTracking(),
      );
    }
  }

  Future<void> _retryPrimaryTracking() async {
    _hasNotifiedFallback = false;
    _disconnectedTime = 0;

    try {
      // Some tracking services may need restart
      _primary.dispose();
      await _primary.start();

      if (_primary.isConnected) {
        _useMouseFallback = false;
        ErrorNotificationService.instance.info(
          'Hand Tracking Restored',
          'Webcam hand tracking is now active.',
        );
      }
    } catch (e) {
      _enableMouseFallback(reason: 'Retry failed: $e');
    }
  }

  /// For compatibility with web tracking service poll pattern
  void poll() {
    try {
      // ignore: avoid_dynamic_calls
      (_primary as dynamic).poll();
    } catch (_) {}
    _mouse.poll();
  }
}
