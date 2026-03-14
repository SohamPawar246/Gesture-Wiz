import 'package:flutter/material.dart';

/// Defines the different types of enemies in the game.
enum EnemyKind { skull, eyeball, slime, knight, boss }

/// Static data for each enemy type.
class EnemyData {
  final EnemyKind kind;
  final String name;
  final double maxHp;
  final double speed; // Depth units per second (0→1 range)
  final double damage; // Damage dealt to player on reaching them
  final int points; // Score rewarded on kill
  final Color primaryColor;
  final Color outlineColor;
  final bool fireImmune; // Immune to fire-type spells?

  const EnemyData({
    required this.kind,
    required this.name,
    required this.maxHp,
    required this.speed,
    required this.damage,
    required this.points,
    required this.primaryColor,
    this.outlineColor = const Color(0xFF1A1A1A),
    this.fireImmune = false,
  });

  /// Pre-defined enemy data table
  static const Map<EnemyKind, EnemyData> table = {
    EnemyKind.skull: EnemyData(
      kind: EnemyKind.skull,
      name: 'Skull Spirit',
      maxHp: 1,
      speed: 0.12,
      damage: 20,
      points: 100,
      primaryColor: Color(0xFFD0D0C0),
    ),
    EnemyKind.eyeball: EnemyData(
      kind: EnemyKind.eyeball,
      name: 'Evil Eye',
      maxHp: 1,
      speed: 0.20,
      damage: 12,
      points: 150,
      primaryColor: Color(0xFFCC3333),
    ),
    EnemyKind.slime: EnemyData(
      kind: EnemyKind.slime,
      name: 'Toxic Slime',
      maxHp: 2,
      speed: 0.08,
      damage: 30,
      points: 200,
      primaryColor: Color(0xFF44CC44),
    ),
    EnemyKind.knight: EnemyData(
      kind: EnemyKind.knight,
      name: 'Armored Knight',
      maxHp: 3,
      speed: 0.07,
      damage: 45,
      points: 500,
      primaryColor: Color(0xFF8888AA),
      fireImmune: true,
    ),
    EnemyKind.boss: EnemyData(
      kind: EnemyKind.boss,
      name: 'Flame Lord',
      maxHp: 10,
      speed: 0.05,
      damage: 80,
      points: 2000,
      primaryColor: Color(0xFFDD4400),
      outlineColor: Color(0xFF331100),
    ),
  };
}
