import 'package:flutter_test/flutter_test.dart';
import 'package:fpv_magic/systems/gesture/gesture_type.dart';

void main() {
  group('GestureType', () {
    test('should have all expected gesture types', () {
      expect(GestureType.values.length, 6);
      expect(GestureType.values, contains(GestureType.none));
      expect(GestureType.values, contains(GestureType.pinch));
      expect(GestureType.values, contains(GestureType.fist));
      expect(GestureType.values, contains(GestureType.openPalm));
      expect(GestureType.values, contains(GestureType.point));
      expect(GestureType.values, contains(GestureType.vSign));
    });

    test('displayName should return human-readable names', () {
      expect(GestureType.none.displayName, 'None');
      expect(GestureType.pinch.displayName, 'Pinch');
      expect(GestureType.fist.displayName, 'Fist');
      expect(GestureType.openPalm.displayName, 'Open Palm');
      expect(GestureType.point.displayName, 'Point');
      expect(GestureType.vSign.displayName, 'V Sign');
    });
  });

  group('GestureResult', () {
    test('should store type and confidence', () {
      const result = GestureResult(GestureType.fist, 0.85);
      expect(result.type, GestureType.fist);
      expect(result.confidence, 0.85);
    });

    test('none constant should have GestureType.none and 0 confidence', () {
      expect(GestureResult.none.type, GestureType.none);
      expect(GestureResult.none.confidence, 0.0);
    });

    test('confidence can range from 0 to 1', () {
      const low = GestureResult(GestureType.point, 0.0);
      const high = GestureResult(GestureType.point, 1.0);
      const mid = GestureResult(GestureType.point, 0.5);

      expect(low.confidence, 0.0);
      expect(high.confidence, 1.0);
      expect(mid.confidence, 0.5);
    });
  });
}
