import 'dart:convert';
import 'dart:io';
import 'package:flame/components.dart';

import '../hand_tracking/landmark_model.dart';
import 'tracking_service.dart';

/// Listens for UDP datagrams from the Python MediaPipe tracker
/// and decodes them into hand landmark data.
///
/// Key improvements:
/// - Drains the socket on every callback event (reads all queued packets and
///   keeps only the freshest one), so the game never operates on stale data.
/// - Applies exponential temporal smoothing (alpha = 0.55) to raw landmarks,
///   reducing high-frequency jitter without introducing significant lag.
///
/// Supports both the new multi-hand format:
///   {"hands": [{"id": 0, "landmarks": [...]}, {"id": 1, "landmarks": [...]}]}
/// and the legacy single-hand format (array of 21 landmarks).
///
/// Also handles optional face tracking data for camera panning:
///   {"hands": [...], "face": {"x": 0.5, "y": 0.5}}

class TrackerData {
  final Map<int, List<Landmark>> hands;
  final Vector2? face;

  TrackerData({required this.hands, this.face});
}

class UdpService implements TrackingService {
  static const int _port = 5005;

  /// Smoothing factor: 0.0 = no movement (frozen), 1.0 = raw (no smoothing).
  /// 0.55 gives a good balance — fast enough to feel instant, smooth enough
  /// to eliminate per-landmark jitter.
  static const double _smoothAlpha = 0.55;

  RawDatagramSocket? _socket;

  /// All detected hands (raw, as received), keyed by hand ID
  final Map<int, List<Landmark>> _rawHands = {};

  /// Smoothed hands — used by the rest of the game for rendering + recognition
  final Map<int, List<Landmark>> _smoothedHands = {};

  Vector2? _rawFace;
  Vector2? _smoothedFace;

  DateTime _lastReceived = DateTime(2000);

  /// Get smoothed landmarks for a specific hand (0 or 1)
  List<Landmark>? getHandLandmarks(int handId) => _smoothedHands[handId];

  /// Convenience: get the first (primary) hand
  List<Landmark>? get latestLandmarks => _smoothedHands[0];

  /// Get smoothed face coordinate (normalized 0-1)
  Vector2? get facePosition => _smoothedFace;

  /// Number of currently tracked hands
  int get handCount => _smoothedHands.length;

  /// Returns true if we've received data within the last 500ms
  bool get isConnected =>
      DateTime.now().difference(_lastReceived).inMilliseconds < 500;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
    _socket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        _drainAndProcess();
      }
    });
  }

  /// Drain ALL pending packets from the socket in a tight loop.
  /// This ensures we always act on the freshest possible frame,
  /// not a packet that has been sitting in the OS buffer.
  void _drainAndProcess() {
    // First pass: read everything, keep only the last valid decode per hand.
    TrackerData? freshest;

    while (true) {
      final datagram = _socket?.receive();
      if (datagram == null) break;

      final decoded = _tryDecode(datagram);
      if (decoded != null) {
        freshest = decoded;
      }
    }

    if (freshest != null) {
      _lastReceived = DateTime.now();

      // Update raw hands
      _rawHands
        ..clear()
        ..addAll(freshest.hands);

      // Apply temporal smoothing to hands
      for (final entry in _rawHands.entries) {
        final handId = entry.key;
        final rawLandmarks = entry.value;
        final existing = _smoothedHands[handId];

        if (existing == null || existing.length != rawLandmarks.length) {
          // First frame for this hand — snap directly, no smoothing
          _smoothedHands[handId] = rawLandmarks;
        } else {
          // Blend: smoothed = smoothed + alpha * (raw - smoothed)
          _smoothedHands[handId] = List.generate(rawLandmarks.length, (i) {
            return existing[i].lerp(rawLandmarks[i], _smoothAlpha);
          });
        }
      }

      // Remove hands that are no longer tracked
      _smoothedHands.removeWhere((id, _) => !_rawHands.containsKey(id));

      // Handle Face Tracking data
      _rawFace = freshest.face;
      if (_rawFace != null) {
        if (_smoothedFace == null) {
          _smoothedFace = _rawFace!.clone();
        } else {
          _smoothedFace!.lerp(_rawFace!, _smoothAlpha);
        }
      } else {
        _smoothedFace = null; // Face lost
      }
    }
  }

  /// Try to parse a datagram into TrackerData.
  /// Returns null on any parse error or unexpected format.
  TrackerData? _tryDecode(Datagram datagram) {
    try {
      final jsonStr = utf8.decode(datagram.data);
      final decoded = json.decode(jsonStr);

      if (decoded is Map && decoded.containsKey('hands')) {
        final result = <int, List<Landmark>>{};
        final List<dynamic> handsJson = decoded['hands'];
        for (final handJson in handsJson) {
          final int handId = handJson['id'] as int;
          final List<dynamic> landmarksJson = handJson['landmarks'];
          if (landmarksJson.length == 21) {
            result[handId] = landmarksJson.map((item) {
              return Landmark(
                x: (item['x'] as num).toDouble(),
                y: (item['y'] as num).toDouble(),
                z: (item['z'] as num).toDouble(),
              );
            }).toList();
          }
        }
        
        Vector2? facePos;
        if (decoded.containsKey('face')) {
          final faceObj = decoded['face'];
          facePos = Vector2(
            (faceObj['x'] as num).toDouble(),
            (faceObj['y'] as num).toDouble(),
          );
        }

        return TrackerData(hands: result, face: facePos);
      } else if (decoded is List && decoded.length == 21) {
        // Legacy single-hand format
        final hands = {
          0: decoded.map((item) {
            return Landmark(
              x: (item['x'] as num).toDouble(),
              y: (item['y'] as num).toDouble(),
              z: (item['z'] as num).toDouble(),
            );
          }).toList(),
        };
        return TrackerData(hands: hands, face: null);
      }
    } catch (_) {
      // Silently ignore malformed packets
    }
    return null;
  }

  void dispose() {
    _socket?.close();
  }
}
