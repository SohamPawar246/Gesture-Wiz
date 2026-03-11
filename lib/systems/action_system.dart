import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../models/spell.dart';
import 'gesture/gesture_type.dart';
import '../game/components/enemy.dart';

/// Result from processing a gesture through the action system.
class ActionResult {
  final GameAction action;
  final Vector2 handPosition;
  final double confidence;
  final List<Enemy>? targets;

  ActionResult({
    required this.action,
    required this.handPosition,
    this.confidence = 1.0,
    this.targets,
  });
}

/// Direct gesture → action mapping system.
///
/// Replaces the old SpellEngine combo buffer with a simple 1:1 lookup.
/// Each gesture maps to exactly one action. Per-action cooldowns prevent spam.
/// OpenPalm (shield) is a continuous/held action — fires while the gesture is sustained.
class ActionSystem {
  /// All known actions
  final List<GameAction> actions;

  /// Per-action cooldown timers, keyed by gesture type
  final Map<GestureType, double> _cooldowns = {};

  /// Track currently held gesture for continuous actions (shield)
  GestureType _currentHeldGesture = GestureType.none;

  ActionSystem({required this.actions}) {
    for (final action in actions) {
      _cooldowns[action.gesture] = 0;
    }
  }

  /// The default set of actions for THE EYE.
  factory ActionSystem.theEye() {
    return ActionSystem(
      actions: const [
        GameAction(
          name: 'Fire Bolt',
          gesture: GestureType.point,
          manaCost: 8,
          effectColor: Color(0xFFFF6622),
          type: ActionType.attack,
          damage: 1.0,
          cooldown: 0.4,
        ),
        GameAction(
          name: 'Force Push',
          gesture: GestureType.fist,
          manaCost: 15,
          effectColor: Color(0xFF8844FF),
          type: ActionType.push,
          damage: 0.5,
          cooldown: 0.8,
          radius: 120.0,
        ),
        GameAction(
          name: 'Ward Shield',
          gesture: GestureType.openPalm,
          manaCost: 3,   // Per-second drain while held
          effectColor: Color(0xFF44DDFF),
          type: ActionType.shield,
          damage: 0,
          cooldown: 0.0,  // No cooldown — sustained
        ),
        GameAction(
          name: 'Telekinesis',
          gesture: GestureType.pinch,
          manaCost: 5,   // Per-second drain while holding
          effectColor: Color(0xFF88FF44),
          type: ActionType.grab,
          damage: 1.5,   // DoT per second while held
          cooldown: 0.0,
          radius: 140.0, // Grab range
        ),
        GameAction(
          name: 'Overwatch Pulse',
          gesture: GestureType.vSign,
          manaCost: 40,
          effectColor: Color(0xFFFFFF44),
          type: ActionType.ultimate,
          damage: 2.0,
          cooldown: 8.0,
          radius: 999.0,
        ),
      ],
    );
  }

  /// Process a gesture. Returns an ActionResult if the action should fire,
  /// or null if on cooldown / no matching action.
  ///
  /// For sustained actions (shield), returns the action every frame while held.
  ActionResult? processGesture(GestureType gesture, Vector2 handPosition, {double confidence = 1.0}) {
    if (gesture == GestureType.none) {
      _currentHeldGesture = GestureType.none;
      return null;
    }

    _currentHeldGesture = gesture;

    final action = _findAction(gesture);
    if (action == null) return null;

    // Sustained actions (shield, grab) fire continuously while held
    if (action.type == ActionType.shield || action.type == ActionType.grab) {
      return ActionResult(action: action, handPosition: handPosition, confidence: confidence);
    }

    // Instant actions check cooldown
    final cd = _cooldowns[gesture] ?? 0;
    if (cd > 0) return null;

    // Fire and set cooldown
    _cooldowns[gesture] = action.cooldown;
    return ActionResult(action: action, handPosition: handPosition, confidence: confidence);
  }

  /// Tick cooldowns. Call once per frame.
  void update(double dt) {
    for (final key in _cooldowns.keys) {
      final v = _cooldowns[key]!;
      if (v > 0) {
        _cooldowns[key] = (v - dt).clamp(0.0, double.infinity);
      }
    }
  }

  /// Check if an action is currently on cooldown
  bool isOnCooldown(GestureType gesture) => (_cooldowns[gesture] ?? 0) > 0;

  /// Get remaining cooldown fraction (0 = ready, 1 = full cooldown)
  double getCooldownProgress(GestureType gesture) {
    final action = _findAction(gesture);
    if (action == null || action.cooldown <= 0) return 0;
    return ((_cooldowns[gesture] ?? 0) / action.cooldown).clamp(0.0, 1.0);
  }

  GestureType get currentHeldGesture => _currentHeldGesture;

  GameAction? _findAction(GestureType gesture) {
    for (final action in actions) {
      if (action.gesture == gesture) return action;
    }
    return null;
  }
}
