import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpv_magic/systems/action_system.dart';
import 'package:fpv_magic/systems/gesture/gesture_type.dart';
import 'package:fpv_magic/models/spell.dart';

void main() {
  group('ActionSystem', () {
    late ActionSystem actionSystem;

    setUp(() {
      actionSystem = ActionSystem.theEye();
    });

    group('initialization', () {
      test('should create with default TheEye actions', () {
        expect(actionSystem.actions.length, 5);
      });

      test('should have all gesture types mapped', () {
        final gestures = actionSystem.actions.map((a) => a.gesture).toSet();
        expect(gestures, contains(GestureType.point));
        expect(gestures, contains(GestureType.fist));
        expect(gestures, contains(GestureType.openPalm));
        expect(gestures, contains(GestureType.pinch));
        expect(gestures, contains(GestureType.vSign));
      });

      test('should initialize all cooldowns to zero', () {
        for (final action in actionSystem.actions) {
          expect(actionSystem.isOnCooldown(action.gesture), false);
        }
      });
    });

    group('processGesture', () {
      test('should return null for GestureType.none', () {
        final result = actionSystem.processGesture(
          GestureType.none,
          Vector2(100, 100),
        );
        expect(result, isNull);
      });

      test('should return ActionResult for valid gesture', () {
        final result = actionSystem.processGesture(
          GestureType.point,
          Vector2(100, 100),
        );
        expect(result, isNotNull);
        expect(result!.action.name, 'Fire Bolt');
        expect(result.handPosition, Vector2(100, 100));
      });

      test('should set cooldown after instant action fires', () {
        actionSystem.processGesture(GestureType.point, Vector2.zero());
        expect(actionSystem.isOnCooldown(GestureType.point), true);
      });

      test('should not fire instant action while on cooldown', () {
        // Fire first time
        final first = actionSystem.processGesture(
          GestureType.point,
          Vector2.zero(),
        );
        expect(first, isNotNull);

        // Try to fire again immediately
        final second = actionSystem.processGesture(
          GestureType.point,
          Vector2.zero(),
        );
        expect(second, isNull);
      });

      test('should allow sustained actions while on cooldown check', () {
        // Shield should always return result for sustained actions
        final result1 = actionSystem.processGesture(
          GestureType.openPalm,
          Vector2.zero(),
        );
        final result2 = actionSystem.processGesture(
          GestureType.openPalm,
          Vector2.zero(),
        );

        expect(result1, isNotNull);
        expect(result2, isNotNull);
        expect(result1!.action.type, ActionType.shield);
      });

      test('should return grab action for pinch gesture', () {
        final result = actionSystem.processGesture(
          GestureType.pinch,
          Vector2(50, 50),
        );
        expect(result, isNotNull);
        expect(result!.action.type, ActionType.grab);
        expect(result.action.name, 'Telekinesis');
      });

      test('should track held gesture', () {
        expect(actionSystem.currentHeldGesture, GestureType.none);

        actionSystem.processGesture(GestureType.fist, Vector2.zero());
        expect(actionSystem.currentHeldGesture, GestureType.fist);

        actionSystem.processGesture(GestureType.none, Vector2.zero());
        expect(actionSystem.currentHeldGesture, GestureType.none);
      });
    });

    group('update cooldowns', () {
      test('should decrease cooldowns over time', () {
        actionSystem.processGesture(GestureType.point, Vector2.zero());
        expect(actionSystem.isOnCooldown(GestureType.point), true);

        // Fire Bolt has 0.4s cooldown - update for 0.5s
        actionSystem.update(0.5);
        expect(actionSystem.isOnCooldown(GestureType.point), false);
      });

      test('should not go negative on cooldown', () {
        actionSystem.processGesture(GestureType.point, Vector2.zero());
        actionSystem.update(10.0); // Way more than cooldown

        expect(actionSystem.getCooldownProgress(GestureType.point), 0.0);
      });

      test('should return correct cooldown progress', () {
        actionSystem.processGesture(GestureType.point, Vector2.zero());
        // Fire Bolt cooldown is 0.4s

        expect(actionSystem.getCooldownProgress(GestureType.point), 1.0);

        actionSystem.update(0.2); // Half cooldown
        expect(
          actionSystem.getCooldownProgress(GestureType.point),
          closeTo(0.5, 0.01),
        );

        actionSystem.update(0.2); // Full cooldown elapsed
        expect(actionSystem.getCooldownProgress(GestureType.point), 0.0);
      });
    });

    group('action properties', () {
      test('Fire Bolt should have correct properties', () {
        final action = actionSystem.actions.firstWhere(
          (a) => a.gesture == GestureType.point,
        );
        expect(action.name, 'Fire Bolt');
        expect(action.manaCost, 8);
        expect(action.type, ActionType.attack);
        expect(action.damage, 1.0);
        expect(action.cooldown, 0.4);
      });

      test('Force Push should be AoE with radius', () {
        final action = actionSystem.actions.firstWhere(
          (a) => a.gesture == GestureType.fist,
        );
        expect(action.type, ActionType.push);
        expect(action.radius, greaterThan(0));
      });

      test('Overwatch Pulse (ultimate) should have high mana cost', () {
        final action = actionSystem.actions.firstWhere(
          (a) => a.gesture == GestureType.vSign,
        );
        expect(action.type, ActionType.ultimate);
        expect(action.manaCost, 70);
        expect(action.cooldown, 10.0);
      });
    });
  });

  group('GameAction', () {
    test('should create with required parameters', () {
      const action = GameAction(
        name: 'Test',
        gesture: GestureType.point,
        manaCost: 10,
      );
      expect(action.name, 'Test');
      expect(action.manaCost, 10);
      expect(action.type, ActionType.attack); // default
      expect(action.damage, 1.0); // default
      expect(action.cooldown, 0.5); // default
      expect(action.radius, 0.0); // default
    });
  });

  group('ActionResult', () {
    test('should store action and position', () {
      const action = GameAction(
        name: 'Test',
        gesture: GestureType.point,
        manaCost: 5,
      );
      final result = ActionResult(
        action: action,
        handPosition: Vector2(150, 200),
        confidence: 0.95,
      );

      expect(result.action.name, 'Test');
      expect(result.handPosition.x, 150);
      expect(result.handPosition.y, 200);
      expect(result.confidence, 0.95);
    });
  });
}
