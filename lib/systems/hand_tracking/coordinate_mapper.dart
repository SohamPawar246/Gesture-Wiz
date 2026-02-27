import 'package:flame/components.dart';

import 'landmark_model.dart';

/// Maps MediaPipe normalized coordinates (0-1) to the actual Flame screen coordinates.
class CoordinateMapper {
  /// The size of the Flame game view.
  final Vector2 gameSize;

  CoordinateMapper(this.gameSize);

  /// Converts a single normalized Landmark to an absolute Vector2 pixel coordinate.
  Vector2 mapLandmarkToScreen(Landmark landmark) {
    // Note: If the camera is mirrored, we might need to invert X:
    // x = (1.0 - landmark.x) * gameSize.x
    return Vector2(
      landmark.x * gameSize.x,
      landmark.y * gameSize.y,
    );
  }

  /// Updates the mapper when the screen resizes
  CoordinateMapper copyWithNewSize(Vector2 newSize) {
    return CoordinateMapper(newSize);
  }
}
