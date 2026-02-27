import 'dart:io';
import 'dart:typed_data';

/// Listens for JPEG frames from the Python tracker via UDP port 5006.
/// Exposes the latest frame as raw bytes for display in Flutter.
class VideoUdpService {
  static const int _port = 5006;

  RawDatagramSocket? _socket;
  Uint8List? _latestFrame;
  DateTime _lastReceived = DateTime(2000);

  Uint8List? get latestFrame => _latestFrame;

  bool get isConnected =>
      DateTime.now().difference(_lastReceived).inMilliseconds < 1000;

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
    _socket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null && datagram.data.length > 100) {
          // JPEG files start with 0xFF 0xD8
          if (datagram.data[0] == 0xFF && datagram.data[1] == 0xD8) {
            _latestFrame = Uint8List.fromList(datagram.data);
            _lastReceived = DateTime.now();
          }
        }
      }
    });
  }

  void dispose() {
    _socket?.close();
  }
}
