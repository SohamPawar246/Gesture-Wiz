import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpv_magic/systems/touch_input_handler.dart';
import 'package:fpv_magic/systems/gesture/gesture_type.dart';

void main() {
  group('TouchInputHandler', () {
    late TouchInputHandler handler;
    final screenSize = const Size(800, 600);

    setUp(() {
      handler = TouchInputHandler();
    });

    group('touch tracking', () {
      test('should not be touching initially', () {
        expect(handler.isTouching, isFalse);
        expect(handler.touchPosition, isNull);
      });

      test('should register touch down', () {
        handler.onTouchDown(const Offset(400, 300), screenSize);

        expect(handler.isTouching, isTrue);
        expect(handler.touchPosition, isNotNull);
      });

      test('should normalize touch position to 0-1 range', () {
        handler.onTouchDown(const Offset(400, 300), screenSize);

        expect(handler.touchPosition!.x, closeTo(0.5, 0.01));
        expect(handler.touchPosition!.y, closeTo(0.5, 0.01));
      });

      test('should handle edge positions', () {
        // Top-left corner
        handler.onTouchDown(const Offset(0, 0), screenSize);
        expect(handler.touchPosition!.x, closeTo(0.0, 0.01));
        expect(handler.touchPosition!.y, closeTo(0.0, 0.01));

        // Bottom-right corner
        handler.onTouchDown(const Offset(800, 600), screenSize);
        expect(handler.touchPosition!.x, closeTo(1.0, 0.01));
        expect(handler.touchPosition!.y, closeTo(1.0, 0.01));
      });

      test('should update position during move', () {
        handler.onTouchDown(const Offset(100, 100), screenSize);
        handler.onTouchMove(const Offset(400, 300), screenSize);

        expect(handler.touchPosition!.x, closeTo(0.5, 0.01));
        expect(handler.touchPosition!.y, closeTo(0.5, 0.01));
      });

      test('should clear touch on release', () {
        handler.onTouchDown(const Offset(400, 300), screenSize);
        handler.onTouchUp();

        expect(handler.isTouching, isFalse);
      });
    });

    group('gesture detection', () {
      test('should start with openPalm on touch down', () {
        handler.onTouchDown(const Offset(400, 300), screenSize);

        expect(handler.currentGesture, GestureType.openPalm);
      });

      test('should detect point gesture from quick tap', () async {
        handler.onTouchDown(const Offset(400, 300), screenSize);
        await Future.delayed(const Duration(milliseconds: 100));
        handler.onTouchUp();

        expect(handler.currentGesture, GestureType.point);
      });

      test('should detect fist gesture from long press', () async {
        handler.onTouchDown(const Offset(400, 300), screenSize);
        await Future.delayed(const Duration(milliseconds: 600));
        handler.onTouchMove(const Offset(400, 300), screenSize);

        expect(handler.currentGesture, GestureType.fist);
      });

      test('should detect pinch gesture from double tap', () async {
        // First tap
        handler.onTouchDown(const Offset(400, 300), screenSize);
        await Future.delayed(const Duration(milliseconds: 50));
        handler.onTouchUp();

        // Second tap (within double tap window)
        await Future.delayed(const Duration(milliseconds: 100));
        handler.onTouchDown(const Offset(400, 300), screenSize);
        await Future.delayed(const Duration(milliseconds: 50));
        handler.onTouchUp();

        expect(handler.currentGesture, GestureType.pinch);
      });

      test('should detect vSign gesture from triple tap', () async {
        // First tap
        handler.onTouchDown(const Offset(400, 300), screenSize);
        handler.onTouchUp();

        // Second tap
        await Future.delayed(const Duration(milliseconds: 100));
        handler.onTouchDown(const Offset(400, 300), screenSize);
        handler.onTouchUp();

        // Third tap
        await Future.delayed(const Duration(milliseconds: 100));
        handler.onTouchDown(const Offset(400, 300), screenSize);
        handler.onTouchUp();

        expect(handler.currentGesture, GestureType.vSign);
      });

      test('should reset tap count after double tap window', () async {
        // First tap
        handler.onTouchDown(const Offset(400, 300), screenSize);
        handler.onTouchUp();

        // Wait longer than double tap window
        await Future.delayed(const Duration(milliseconds: 400));

        // Second tap (should be treated as new first tap)
        handler.onTouchDown(const Offset(400, 300), screenSize);
        handler.onTouchUp();

        // Should be point, not pinch
        expect(handler.currentGesture, GestureType.point);
      });
    });

    group('gesture result', () {
      test('should return gesture with full confidence when touching', () {
        handler.onTouchDown(const Offset(400, 300), screenSize);

        final result = handler.getGestureResult();
        expect(result.confidence, 1.0);
        expect(result.type, GestureType.openPalm);
      });

      test('should return zero confidence when not touching', () {
        final result = handler.getGestureResult();
        expect(result.confidence, 0.0);
      });
    });

    group('screen position', () {
      test('should return null when not touching', () {
        final pos = handler.getScreenPosition(screenSize);
        expect(pos, isNull);
      });

      test('should convert normalized position to screen coordinates', () {
        handler.onTouchDown(const Offset(400, 300), screenSize);

        final pos = handler.getScreenPosition(screenSize);
        expect(pos, isNotNull);
        expect(pos!.dx, closeTo(400, 1));
        expect(pos.dy, closeTo(300, 1));
      });
    });

    group('reset', () {
      test('should clear all state', () async {
        handler.onTouchDown(const Offset(400, 300), screenSize);
        await Future.delayed(const Duration(milliseconds: 100));
        handler.onTouchMove(const Offset(500, 400), screenSize);

        handler.reset();

        expect(handler.isTouching, isFalse);
        expect(handler.touchPosition, isNull);
        expect(handler.currentGesture, GestureType.none);
      });
    });
  });

  group('Vector2', () {
    test('should store x and y coordinates', () {
      const vec = Vector2(0.5, 0.75);

      expect(vec.x, 0.5);
      expect(vec.y, 0.75);
    });

    test('should have readable toString', () {
      const vec = Vector2(0.25, 0.5);

      expect(vec.toString(), contains('0.25'));
      expect(vec.toString(), contains('0.5'));
    });
  });
}
