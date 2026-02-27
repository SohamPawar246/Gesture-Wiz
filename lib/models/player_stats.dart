import 'dart:math';
import 'package:flutter/foundation.dart';

import '../systems/save_system.dart';

class PlayerStats extends ChangeNotifier {
  final SaveSystem _saveSystem;

  int _level = 1;
  int _currentXp = 0;
  double _currentMana = 100.0;
  double _currentHp = 100.0;
  int _score = 0;
  int _killCount = 0;
  int _currentWave = 1;

  // Throttle notifications to avoid excessive UI rebuilds
  double _notifyAccumulator = 0;
  static const double _notifyInterval = 0.1; // Max 10 notifications per second

  // Base constants
  static const int _baseXpNeeded = 100;
  static const double _baseMaxMana = 100.0;
  static const double _baseManaRegen = 5.0;
  static const double _baseMaxHp = 100.0;

  PlayerStats({required SaveSystem saveSystem}) : _saveSystem = saveSystem;

  // Getters
  int get level => _level;
  int get currentXp => _currentXp;
  double get currentMana => _currentMana;
  double get currentHp => _currentHp;
  int get score => _score;
  int get killCount => _killCount;
  int get currentWave => _currentWave;

  // Scaling stats
  int get maxXp => (_baseXpNeeded * pow(1.5, _level - 1)).toInt();
  double get maxMana => _baseMaxMana + (_level - 1) * 20.0;
  double get manaRegenRate => _baseManaRegen + (_level - 1) * 1.0;
  double get maxHp => _baseMaxHp + (_level - 1) * 10.0;

  bool get isDead => _currentHp <= 0;

  Future<void> load() async {
    _level = await _saveSystem.loadLevel();
    _currentXp = await _saveSystem.loadXp();
    _currentMana = maxMana;
    _currentHp = maxHp;
    _score = 0;
    _killCount = 0;
    _currentWave = 1;
    _immediateNotify();
  }

  void resetForNewGame() {
    _currentMana = maxMana;
    _currentHp = maxHp;
    _score = 0;
    _killCount = 0;
    _currentWave = 1;
    _immediateNotify();
  }

  /// Immediate notification for important state changes (damage, heal, score)
  void _immediateNotify() {
    Future.microtask(() {
      notifyListeners();
    });
  }

  // --- Mana ---
  bool canCast(double manaCost) => _currentMana >= manaCost;

  bool consumeMana(double manaCost) {
    if (_currentMana >= manaCost) {
      _currentMana -= manaCost;
      _immediateNotify();
      return true;
    }
    return false;
  }

  /// Regenerate mana — uses throttled notification to avoid per-frame rebuilds
  void regenerateMana(double dt) {
    if (_currentMana < maxMana) {
      _currentMana += manaRegenRate * dt;
      if (_currentMana > maxMana) _currentMana = maxMana;

      // Throttle: only notify UI periodically, not every frame
      _notifyAccumulator += dt;
      if (_notifyAccumulator >= _notifyInterval) {
        _notifyAccumulator = 0;
        _immediateNotify();
      }
    }
  }

  // --- HP ---
  void takeDamage(double amount) {
    _currentHp -= amount;
    if (_currentHp < 0) _currentHp = 0;
    _immediateNotify(); // Immediate — HP changes are critical
  }

  void heal(double amount) {
    _currentHp += amount;
    if (_currentHp > maxHp) _currentHp = maxHp;
    _immediateNotify();
  }

  // --- Score ---
  void addScore(int points) {
    _score += points;
    _immediateNotify();
  }

  void addKill() {
    _killCount++;
    // Don't notify separately — addScore will handle it
  }

  void setWave(int wave) {
    _currentWave = wave;
    _immediateNotify();
  }

  // --- XP ---
  void addXp(int amount) {
    _currentXp += amount;

    while (_currentXp >= maxXp) {
      _currentXp -= maxXp;
      _level++;
      _currentMana = maxMana;
      _currentHp = maxHp;
    }

    _saveSystem.saveProgress(_level, _currentXp);
    _immediateNotify();
  }
}
