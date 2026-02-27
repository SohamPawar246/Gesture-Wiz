enum GestureType {
  none,
  pinch,
  fist,
  openPalm,
  point,
  vSign,
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
