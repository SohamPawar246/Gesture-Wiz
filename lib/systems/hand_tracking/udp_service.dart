import 'dart:convert';
import 'dart:io';

import '../hand_tracking/landmark_model.dart';

/// Listens for UDP datagrams from the Python MediaPipe tracker
/// and decodes them into hand landmark data.
///
/// Supports both the new multi-hand format:
///   {"hands": [{"id": 0, "landmarks": [...]}, {"id": 1, "landmarks": [...]}]}
/// and the legacy single-hand format (array of 21 landmarks).
class UdpService {
  static const int _port = 5005;

  RawDatagramSocket? _socket;

  /// All detected hands, keyed by hand ID
  final Map<int, List<Landmark>> _hands = {};
  DateTime _lastReceived = DateTime(2000);

  /// Get landmarks for a specific hand (0 or 1)
  List<Landmark>? getHandLandmarks(int handId) => _hands[handId];

  /// Convenience: get the first (primary) hand
  List<Landmark>? get latestLandmarks => _hands[0];

  /// Number of currently tracked hands
  int get handCount => _hands.length;

  /// Returns true if we've received data within the last 500ms
  bool get isConnected =>
      DateTime.now().difference(_lastReceived).inMilliseconds < 500;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
    _socket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          _decodeDatagram(datagram);
        }
      }
    });
  }

  void _decodeDatagram(Datagram datagram) {
    try {
      final jsonStr = utf8.decode(datagram.data);
      final decoded = json.decode(jsonStr);

      if (decoded is Map && decoded.containsKey('hands')) {
        // New multi-hand format
        _hands.clear();
        final List<dynamic> handsJson = decoded['hands'];
        for (final handJson in handsJson) {
          final int handId = handJson['id'] as int;
          final List<dynamic> landmarksJson = handJson['landmarks'];
          if (landmarksJson.length == 21) {
            _hands[handId] = landmarksJson.map((item) {
              return Landmark(
                x: (item['x'] as num).toDouble(),
                y: (item['y'] as num).toDouble(),
                z: (item['z'] as num).toDouble(),
              );
            }).toList();
          }
        }
        _lastReceived = DateTime.now();
      } else if (decoded is List && decoded.length == 21) {
        // Legacy single-hand format (backwards compatible)
        _hands.clear();
        _hands[0] = decoded.map((item) {
          return Landmark(
            x: (item['x'] as num).toDouble(),
            y: (item['y'] as num).toDouble(),
            z: (item['z'] as num).toDouble(),
          );
        }).toList();
        _lastReceived = DateTime.now();
      }
    } catch (_) {
      // Silently ignore malformed packets
    }
  }

  void dispose() {
    _socket?.close();
  }
}
