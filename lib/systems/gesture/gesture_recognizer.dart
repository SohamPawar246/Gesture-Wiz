import '../hand_tracking/landmark_model.dart';
import 'gesture_type.dart';

abstract class GestureRecognizer {
  /// Analyzes a set of exactly 21 landmarks and returns the detected gesture
  /// with a confidence score (0.0–1.0).
  GestureResult recognize(List<Landmark> landmarks);
}
