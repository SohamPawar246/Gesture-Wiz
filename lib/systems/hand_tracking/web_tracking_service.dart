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

/// Web implementation of TrackingService.
/// Reads hand/face data from MediaPipe JS bridge via js_interop.
class WebTrackingService implements TrackingService {
  /// Smoothing factor (same as UDP service)
  static const double _smoothAlpha = 0.55;

  final Map<int, List<Landmark>> _smoothedHands = {};
  final Map<int, List<Landmark>> _rawHands = {};
  Vector2? _rawFace;
  Vector2? _smoothedFace;
  DateTime _lastReceived = DateTime(2000);

  @override
  List<Landmark>? getHandLandmarks(int handId) => _smoothedHands[handId];

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
    // We just need to poll in the game loop.
  }

  /// Call this every frame from the game update loop.
  /// Reads latest data from JS and applies smoothing.
  void poll() {
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

      // Apply temporal smoothing
      for (final entry in _rawHands.entries) {
        final handId = entry.key;
        final rawLandmarks = entry.value;
        final existing = _smoothedHands[handId];

        if (existing == null || existing.length != rawLandmarks.length) {
          _smoothedHands[handId] = rawLandmarks;
        } else {
          _smoothedHands[handId] = List.generate(rawLandmarks.length, (i) {
            return existing[i].lerp(rawLandmarks[i], _smoothAlpha);
          });
        }
      }

      _smoothedHands.removeWhere((id, _) => !_rawHands.containsKey(id));
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
        _smoothedFace!.lerp(_rawFace!, _smoothAlpha);
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
