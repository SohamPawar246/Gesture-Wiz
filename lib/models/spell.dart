import 'package:flutter/material.dart';

import '../systems/gesture/gesture_type.dart';

/// The type of action effect — determines combat behavior
enum ActionType {
  attack,    // Fires projectile toward target
  push,      // AoE force wave centered on hand
  shield,    // Sustained ward while gesture held
  grab,      // Pick up / interact with nearby object
  ultimate,  // Damages all enemies on screen
}

/// Represents a single action mapped to a gesture.
/// Unlike the old Spell system, there are no combos —
/// each gesture directly triggers its action.
class GameAction {
  final String name;
  final GestureType gesture;
  final double manaCost;
  final Color effectColor;
  final ActionType type;
  final double damage;
  final double cooldown;     // Seconds before this action can fire again
  final double radius;       // AoE radius (0 = single target)

  const GameAction({
    required this.name,
    required this.gesture,
    required this.manaCost,
    this.effectColor = Colors.white,
    this.type = ActionType.attack,
    this.damage = 1.0,
    this.cooldown = 0.5,
    this.radius = 0.0,
  });
}
