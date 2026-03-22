import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/difficulty.dart';
import '../models/map_node.dart';
import '../models/spell.dart';
import '../models/spell_upgrade.dart';
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
  int _totalWaves = 1;

  // Skill points & spell upgrades
  int _skillPoints = 0;
  final SpellUpgradeState upgrades = SpellUpgradeState();

  // --- Map System Progress ---
  List<String> _unlockedNodes = ['1'];
  List<String> _completedNodes = [];
  String _currentNodeId = '1';
  bool _hasSeenCameraPermission = false;

  // Throttle notifications to avoid excessive UI rebuilds
  double _notifyAccumulator = 0;
  static const double _notifyInterval = 0.1; // Max 10 notifications per second

  // Base constants
  static const int _baseXpNeeded = 100;
  static const double _baseMaxMana = 100.0;
  static const double _baseManaRegen = 5.0;
  static const double _baseMaxHp = 100.0;

  // Difficulty setting (affects mana regen)
  Difficulty _difficulty = Difficulty.normal;

  // Artifact Buffs
  bool hasteActive = false;

  // Node-specific stats (for unlocking secrets)
  bool tookDamageThisNode = false;
  int maxComboThisNode = 0;
  bool usedAttackThisNode = false;
  int artifactsCollectedThisNode = 0;

  PlayerStats({required SaveSystem saveSystem}) : _saveSystem = saveSystem;

  void setDifficulty(Difficulty d) {
    _difficulty = d;
  }

  // Getters
  int get level => _level;
  int get currentXp => _currentXp;
  double get currentMana => _currentMana;
  double get currentHp => _currentHp;
  int get score => _score;
  int get killCount => _killCount;
  int get currentWave => _currentWave;
  int get totalWaves => _totalWaves;

  List<String> get unlockedNodes => _unlockedNodes;
  List<String> get completedNodes => _completedNodes;
  String get currentNodeId => _currentNodeId;
  String get currentNodeLabel =>
      MapGraph.nodes[_currentNodeId]?.label ?? 'UNKNOWN';
  int get skillPoints => _skillPoints;
  bool get hasSeenCameraPermission => _hasSeenCameraPermission;

  // Scaling stats
  int get maxXp => (_baseXpNeeded * pow(1.5, _level - 1)).toInt();
  double get maxMana => _baseMaxMana + (_level - 1) * 20.0;
  double get manaRegenRate =>
      (_baseManaRegen + (_level - 1) * 1.0) * _difficulty.manaRegenMultiplier;
  double get maxHp => _baseMaxHp + (_level - 1) * 10.0;

  bool get isDead => _currentHp <= 0;

  Future<void> load() async {
    _level = await _saveSystem.loadLevel();
    _currentXp = await _saveSystem.loadXp();
    _skillPoints = await _saveSystem.loadSkillPoints();
    upgrades.loadFromJson(await _saveSystem.loadUpgrades());
    _currentMana = maxMana;
    _currentHp = maxHp;
    _score = 0;
    _killCount = 0;
    _currentWave = 1;
    _unlockedNodes = await _saveSystem.loadUnlockedNodes();
    _completedNodes = await _saveSystem.loadCompletedNodes();
    _currentNodeId = await _saveSystem.loadCurrentNode();
    _hasSeenCameraPermission = await _saveSystem.loadHasSeenCameraPermission();
    _immediateNotify();
  }

  Future<void> setHasSeenCameraPermission(bool seen) async {
    _hasSeenCameraPermission = seen;
    await _saveSystem.saveHasSeenCameraPermission(seen);
    _immediateNotify();
  }

  void resetForNewGame() {
    _currentMana = maxMana;
    _currentHp = maxHp;
    _score = 0;
    _killCount = 0;
    _currentWave = 1;
    _skillPoints = 0;
    upgrades.reset();
    _unlockedNodes = ['1'];
    _completedNodes = [];
    _currentNodeId = '1';
    _saveSystem.saveMapProgress(
      _unlockedNodes,
      _completedNodes,
      _currentNodeId,
    );
    _saveSystem.saveUpgrades(_skillPoints, upgrades.toJson());
    _immediateNotify();
  }

  /// Resets HP and mana for a new level without wiping map/XP progress.
  void resetForLevel() {
    _currentMana = maxMana;
    _currentHp = maxHp;
    _currentWave = 1;
    _totalWaves = 1;
    _immediateNotify();
  }

  /// Immediate notification for important state changes (damage, heal, score)
  void _immediateNotify() {
    Future.microtask(() {
      notifyListeners();
    });
  }

  // Gameplay actions
  bool canCast(double cost) {
    if (hasteActive) return true;
    return _currentMana >= cost;
  }

  void consumeMana(double cost) {
    if (hasteActive) return;
    _currentMana = max(0.0, _currentMana - cost);
    _immediateNotify();
  }

  void addMana(double amount) {
    _currentMana = min(maxMana, _currentMana + amount);
    _immediateNotify();
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
    if (amount > 0) tookDamageThisNode = true;
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

  void setTotalWaves(int total) {
    _totalWaves = total;
    _immediateNotify();
  }

  // --- XP ---
  void addXp(int amount) {
    _currentXp += amount;

    while (_currentXp >= maxXp) {
      _currentXp -= maxXp;
      _level++;
      // Leveling up grants 1 skill point (no longer auto-heals)
      _skillPoints++;
    }

    _saveSystem.saveProgress(_level, _currentXp);
    _saveSystem.saveUpgrades(_skillPoints, upgrades.toJson());
    _immediateNotify();
  }

  /// Spend a skill point to upgrade a spell. Returns true if successful.
  bool spendSkillPoint(ActionType type) {
    final cost = upgrades.nextUpgradeCost(type);
    if (cost < 0 || _skillPoints < cost) return false;
    if (!upgrades.upgrade(type)) return false;
    _skillPoints -= cost;
    _saveSystem.saveUpgrades(_skillPoints, upgrades.toJson());
    _immediateNotify();
    return true;
  }

  /// Grant bonus skill points (e.g. from secret room rewards).
  void addSkillPoints(int amount) {
    _skillPoints += amount;
    _saveSystem.saveUpgrades(_skillPoints, upgrades.toJson());
    _immediateNotify();
  }

  // --- Map Progression ---
  void completeNode(String nodeId, List<String> newUnlocks) {
    if (!_completedNodes.contains(nodeId)) {
      _completedNodes.add(nodeId);
    }
    for (var unlock in newUnlocks) {
      if (!_unlockedNodes.contains(unlock)) {
        _unlockedNodes.add(unlock);
      }
    }
    _saveSystem.saveMapProgress(
      _unlockedNodes,
      _completedNodes,
      _currentNodeId,
    );
    _immediateNotify();
  }

  void setCurrentNode(String nodeId) {
    _currentNodeId = nodeId;
    tookDamageThisNode = false;
    maxComboThisNode = 0;
    usedAttackThisNode = false;
    artifactsCollectedThisNode = 0;
    _saveSystem.saveMapProgress(
      _unlockedNodes,
      _completedNodes,
      _currentNodeId,
    );
    _immediateNotify();
  }

  /// Cheat: unlock every node on the map.
  void unlockAllNodes() {
    for (final id in MapGraph.nodes.keys) {
      if (!_unlockedNodes.contains(id)) _unlockedNodes.add(id);
    }
    _saveSystem.saveMapProgress(
      _unlockedNodes,
      _completedNodes,
      _currentNodeId,
    );
    _immediateNotify();
  }
}
