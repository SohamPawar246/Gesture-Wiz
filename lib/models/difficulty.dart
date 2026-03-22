/// Game difficulty levels with associated stat multipliers.
///
/// Difficulty affects enemy stats and player advantages.
enum Difficulty {
  easy,
  normal,
  hard;

  String get displayName {
    switch (this) {
      case Difficulty.easy:
        return 'EASY';
      case Difficulty.normal:
        return 'NORMAL';
      case Difficulty.hard:
        return 'HARD';
    }
  }

  String get description {
    switch (this) {
      case Difficulty.easy:
        return 'Enemies deal less damage, slower spawn rates';
      case Difficulty.normal:
        return 'Balanced gameplay experience';
      case Difficulty.hard:
        return 'Enemies hit harder, faster spawns, less mana regen';
    }
  }

  /// Multiplier for enemy damage dealt to player (lower = easier)
  double get enemyDamageMultiplier {
    switch (this) {
      case Difficulty.easy:
        return 0.6;
      case Difficulty.normal:
        return 1.0;
      case Difficulty.hard:
        return 1.5;
    }
  }

  /// Multiplier for enemy health (lower = easier)
  double get enemyHealthMultiplier {
    switch (this) {
      case Difficulty.easy:
        return 0.75;
      case Difficulty.normal:
        return 1.0;
      case Difficulty.hard:
        return 1.25;
    }
  }

  /// Multiplier for enemy movement speed (lower = easier)
  double get enemySpeedMultiplier {
    switch (this) {
      case Difficulty.easy:
        return 0.85;
      case Difficulty.normal:
        return 1.0;
      case Difficulty.hard:
        return 1.2;
    }
  }

  /// Multiplier for spawn interval (higher = slower spawns = easier)
  double get spawnIntervalMultiplier {
    switch (this) {
      case Difficulty.easy:
        return 1.4;
      case Difficulty.normal:
        return 1.0;
      case Difficulty.hard:
        return 0.75;
    }
  }

  /// Multiplier for player mana regeneration (higher = easier)
  double get manaRegenMultiplier {
    switch (this) {
      case Difficulty.easy:
        return 1.3;
      case Difficulty.normal:
        return 1.0;
      case Difficulty.hard:
        return 0.8;
    }
  }

  /// Multiplier for player spell damage (higher = easier)
  double get playerDamageMultiplier {
    switch (this) {
      case Difficulty.easy:
        return 1.25;
      case Difficulty.normal:
        return 1.0;
      case Difficulty.hard:
        return 0.9;
    }
  }

  /// Multiplier for surveillance detection gain (lower = easier)
  double get surveillanceGainMultiplier {
    switch (this) {
      case Difficulty.easy:
        return 0.7;
      case Difficulty.normal:
        return 1.0;
      case Difficulty.hard:
        return 1.3;
    }
  }

  /// Multiplier for score points (higher difficulties reward more)
  double get scoreMultiplier {
    switch (this) {
      case Difficulty.easy:
        return 0.75;
      case Difficulty.normal:
        return 1.0;
      case Difficulty.hard:
        return 1.5;
    }
  }

  /// Parse from string (for persistence)
  static Difficulty fromString(String? value) {
    switch (value) {
      case 'easy':
        return Difficulty.easy;
      case 'hard':
        return Difficulty.hard;
      default:
        return Difficulty.normal;
    }
  }
}
