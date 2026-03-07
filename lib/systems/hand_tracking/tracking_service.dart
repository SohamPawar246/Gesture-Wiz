import 'package:flame/components.dart';
import 'landmark_model.dart';

/// Abstract interface for hand/face tracking.
/// Desktop uses UdpService, Web uses WebTrackingService.
abstract class TrackingService {
  List<Landmark>? getHandLandmarks(int handId);
  Vector2? get facePosition;
  int get handCount;
  bool get isConnected;
  Future<void> start();
  void dispose();
}
