import 'dart:convert';
import 'dart:js_interop';
import 'package:flame/components.dart';

import 'landmark_model.dart';
import 'tracking_service.dart';

@JS('getHandLandmarks')
external JSString? _jsGetHandLandmarks();

@JS('getFacePosition')
external JSString? _jsGetFacePosition();

@JS('isMediaPipeReady')
external JSBoolean _jsIsMediaPipeReady();

@JS('requestCameraPermission')
external JSPromise<JSBoolean> _jsRequestCameraPermission();

/// Web implementation of TrackingService.
/// Reads hand/face data from MediaPipe JS bridge via js_interop.
///
/// Uses velocity-adaptive EMA smoothing: heavy when stationary (kills jitter),
/// light when moving fast (reduces latency).
class WebTrackingService implements TrackingService {
  // --- Velocity-adaptive smoothing ---
  static const double _alphaMin = 0.30;        // Moderate smoothing when still
  static const double _alphaMax = 0.92;        // Nearly raw when moving fast
  static const double _velocityFloor = 0.0003; // Sq velocity below = "still"
  static const double _velocityCeiling = 0.005; // Sq velocity above = "fast"

  // Face uses fixed alpha (parallax, not gameplay-critical)
  static const double _faceAlpha = 0.65;

  final Map<int, List<Landmark>> _smoothedHands = {};
  final Map<int, List<Landmark>> _rawHands = {};
  final Map<int, Landmark> _prevWrist = {};
  Vector2? _rawFace;
  Vector2? _smoothedFace;
  DateTime _lastReceived = DateTime(2000);
  DateTime _lastPollTime = DateTime(2000);

  @override
  List<Landmark>? getHandLandmarks(int handId) => _smoothedHands[handId];

  /// Raw (unsmoothed) landmarks for gesture recognition — avoids
  /// double-smoothing the input to the recognizer.
  List<Landmark>? getRawHandLandmarks(int handId) => _rawHands[handId];

  @override
  Vector2? get facePosition => _smoothedFace;

  @override
  int get handCount => _smoothedHands.length;

  @override
  bool get isConnected =>
      DateTime.now().difference(_lastReceived).inMilliseconds < 500;

  @override
  Future<void> start() async {
    // Nothing to start — JS bridge auto-initializes.
  }

  @override
  Future<bool> requestCameraPermission() async {
    try {
      final jsResult = await _jsRequestCameraPermission().toDart;
      return jsResult.toDart;
    } catch (_) {
      return false;
    }
  }

  /// Call this every frame from the game update loop.
  /// Reads latest data from JS and applies smoothing.
  /// Deduplicated: no-op if called again within 10ms.
  void poll() {
    final now = DateTime.now();
    if (now.difference(_lastPollTime).inMilliseconds < 4) return;
    _lastPollTime = now;

    // Check if MediaPipe is ready
    if (!_jsIsMediaPipeReady().toDart) return;

    _pollHands();
    _pollFace();
  }

  void _pollHands() {
    final jsResult = _jsGetHandLandmarks();
    if (jsResult == null) {
      _rawHands.clear();
      _smoothedHands.clear();
      _prevWrist.clear();
      return;
    }

    try {
      final List<dynamic> handsJson = json.decode(jsResult.toDart);
      _lastReceived = DateTime.now();

      _rawHands.clear();
      for (int handIdx = 0; handIdx < handsJson.length; handIdx++) {
        final List<dynamic> landmarks = handsJson[handIdx];
        if (landmarks.length == 21) {
          _rawHands[handIdx] = landmarks.map((lm) {
            return Landmark(
              x: (lm['x'] as num).toDouble(),
              y: (lm['y'] as num).toDouble(),
              z: (lm['z'] as num).toDouble(),
            );
          }).toList();
        }
      }

      // Apply velocity-adaptive temporal smoothing per hand
      for (final entry in _rawHands.entries) {
        final handId = entry.key;
        final rawLandmarks = entry.value;
        final existing = _smoothedHands[handId];

        if (existing == null || existing.length != rawLandmarks.length) {
          // First frame for this hand — snap directly
          _smoothedHands[handId] = rawLandmarks;
          _prevWrist[handId] = rawLandmarks[0];
        } else {
          // Compute wrist velocity for adaptive alpha
          final wrist = rawLandmarks[0];
          final prev = _prevWrist[handId];
          double velocitySq = 0.0;
          if (prev != null) {
            final dx = wrist.x - prev.x;
            final dy = wrist.y - prev.y;
            velocitySq = dx * dx + dy * dy;
          }
          _prevWrist[handId] = wrist;

          // Map velocity to smoothing alpha
          final t = ((velocitySq - _velocityFloor) /
                  (_velocityCeiling - _velocityFloor))
              .clamp(0.0, 1.0);
          final adaptiveAlpha = _alphaMin + (_alphaMax - _alphaMin) * t;

          _smoothedHands[handId] = List.generate(rawLandmarks.length, (i) {
            return existing[i].lerp(rawLandmarks[i], adaptiveAlpha);
          });
        }
      }

      _smoothedHands.removeWhere((id, _) => !_rawHands.containsKey(id));
      _prevWrist.removeWhere((id, _) => !_rawHands.containsKey(id));
    } catch (_) {
      // Ignore parse errors
    }
  }

  void _pollFace() {
    final jsResult = _jsGetFacePosition();
    if (jsResult == null) {
      _rawFace = null;
      _smoothedFace = null;
      return;
    }

    try {
      final Map<String, dynamic> faceJson = json.decode(jsResult.toDart);
      _rawFace = Vector2(
        (faceJson['x'] as num).toDouble(),
        (faceJson['y'] as num).toDouble(),
      );

      if (_smoothedFace == null) {
        _smoothedFace = _rawFace!.clone();
      } else {
        _smoothedFace!.lerp(_rawFace!, _faceAlpha);
      }
    } catch (_) {
      _rawFace = null;
      _smoothedFace = null;
    }
  }

  @override
  void dispose() {
    // Nothing to dispose — JS handles cleanup
  }
}
