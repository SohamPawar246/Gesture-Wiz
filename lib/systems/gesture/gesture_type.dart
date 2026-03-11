enum GestureType {
  none,
  pinch,
  fist,
  openPalm,
  point,
  vSign,
}

/// A gesture detection with confidence score (0.0–1.0).
class GestureResult {
  final GestureType type;
  final double confidence;

  const GestureResult(this.type, this.confidence);

  static const none = GestureResult(GestureType.none, 0.0);
}

extension GestureTypeExtension on GestureType {
  String get displayName {
    switch (this) {
      case GestureType.none:
        return 'None';
      case GestureType.pinch:
        return 'Pinch';
      case GestureType.fist:
        return 'Fist';
      case GestureType.openPalm:
        return 'Open Palm';
      case GestureType.point:
        return 'Point';
      case GestureType.vSign:
        return 'V Sign';
    }
  }
}
