import 'dart:async';
import 'package:camera/camera.dart';

import 'landmark_model.dart';

abstract class MediaPipeService {
  /// Initializes the tracking service
  Future<void> initialize();

  /// Processes a single camera frame and returns a map of Hand ID to List of 21 Landmarks.
  /// If no hands are detected, returns an empty map.
  Future<Map<int, List<Landmark>>> processFrame(CameraImage image);

  /// Disposes of the tracking resources
  void dispose();
}
