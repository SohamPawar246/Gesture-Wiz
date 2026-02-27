import '../hand_tracking/landmark_model.dart';
import 'gesture_type.dart';

abstract class GestureRecognizer {
  /// Analyzes a set of exactly 21 landmarks and returns the detected gesture.
  GestureType recognize(List<Landmark> landmarks);
}
