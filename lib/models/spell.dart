import 'package:flutter/material.dart';

import '../systems/gesture/gesture_type.dart';

/// The type of spell effect — determines combat behavior
enum SpellType {
  attack,    // Flies to nearest enemy, damages on hit
  defense,   // Creates shield wall, blocks enemies
  heal,      // Instant heal at player position
  ultimate,  // Damages ALL enemies on screen
}

class Spell {
  final String name;
  final List<GestureType> requiredGestures;
  final int difficulty;
  final double manaCost;
  final Duration castWindow;
  final Color effectColor;
  final SpellType type;
  final double damage;
  final double radius; // Area of effect radius (0 = single target)

  const Spell({
    required this.name,
    required this.requiredGestures,
    required this.difficulty,
    required this.manaCost,
    required this.castWindow,
    this.effectColor = Colors.white,
    this.type = SpellType.attack,
    this.damage = 1.0,
    this.radius = 0.0,
  });
}
