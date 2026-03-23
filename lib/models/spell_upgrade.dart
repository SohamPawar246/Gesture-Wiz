import 'spell.dart';

/// Defines the upgrade tree for each spell type.
/// Each action type has 3 upgrade levels (0 = base, 1-3 = upgraded).
class SpellUpgrade {
  final ActionType actionType;
  final int level; // 0-3
  final String name;
  final String description;
  final int cost; // Skill points required

  const SpellUpgrade({
    required this.actionType,
    required this.level,
    required this.name,
    required this.description,
    this.cost = 1,
  });

  /// Master upgrade table: all upgrades for all spells.
  static const Map<ActionType, List<SpellUpgrade>> upgradeTree = {
    ActionType.attack: [
      SpellUpgrade(
        actionType: ActionType.attack,
        level: 1,
        name: 'Accelerated Bolts',
        description: '+15% projectile speed',
        cost: 1,
      ),
      SpellUpgrade(
        actionType: ActionType.attack,
        level: 2,
        name: 'Efficient Runes',
        description: '-10% mana cost',
        cost: 2,
      ),
      SpellUpgrade(
        actionType: ActionType.attack,
        level: 3,
        name: 'Piercing',
        description: 'Hits a second target at 60% damage',
        cost: 3,
      ),
    ],
    ActionType.shield: [
      SpellUpgrade(
        actionType: ActionType.shield,
        level: 1,
        name: 'Extended Ward',
        description: '+0.5s linger duration',
        cost: 1,
      ),
      SpellUpgrade(
        actionType: ActionType.shield,
        level: 2,
        name: 'Efficient Ward',
        description: '-15% mana drain',
        cost: 2,
      ),
      SpellUpgrade(
        actionType: ActionType.shield,
        level: 3,
        name: 'Kinetic Battery',
        description: 'Blocking restores 10 Mana',
        cost: 3,
      ),
    ],
    ActionType.push: [
      SpellUpgrade(
        actionType: ActionType.push,
        level: 1,
        name: 'Healing Push',
        description: '+10 HP healed per cast',
        cost: 1,
      ),
      SpellUpgrade(
        actionType: ActionType.push,
        level: 2,
        name: 'Swift Recovery',
        description: '-1.5s cooldown',
        cost: 2,
      ),
      SpellUpgrade(
        actionType: ActionType.push,
        level: 3,
        name: 'Overheal',
        description: 'Excess healing creates 1-hit Overshield (3s)',
        cost: 3,
      ),
    ],
    ActionType.ultimate: [
      SpellUpgrade(
        actionType: ActionType.ultimate,
        level: 1,
        name: 'Overcharged Pulse',
        description: '+10% damage & +1s shake',
        cost: 1,
      ),
      SpellUpgrade(
        actionType: ActionType.ultimate,
        level: 2,
        name: 'Rapid Deployment',
        description: '-2s cooldown',
        cost: 2,
      ),
      SpellUpgrade(
        actionType: ActionType.ultimate,
        level: 3,
        name: 'Executioner',
        description: 'Killing 3+ triggers free Shield',
        cost: 3,
      ),
    ],
  };
}

/// Runtime state tracking which upgrades the player has unlocked.
/// Stored as Map<String, int> (actionType.name → level) for serialization.
class SpellUpgradeState {
  final Map<ActionType, int> _levels = {
    ActionType.attack: 0,
    ActionType.shield: 0,
    ActionType.push: 0, // Push = Heal (Force Push doubles as heal upgrade)
    ActionType.ultimate: 0,
  };

  int getLevel(ActionType type) => _levels[type] ?? 0;

  /// Returns true if the upgrade was applied, false if already maxed.
  bool upgrade(ActionType type) {
    final current = _levels[type] ?? 0;
    if (current >= 3) return false;
    _levels[type] = current + 1;
    return true;
  }

  /// The cost to upgrade to the next level.
  int nextUpgradeCost(ActionType type) {
    final current = _levels[type] ?? 0;
    final upgrades = SpellUpgrade.upgradeTree[type];
    if (upgrades == null || current >= upgrades.length) return -1;
    return upgrades[current].cost;
  }

  /// Get the next available upgrade info, or null if maxed.
  SpellUpgrade? nextUpgrade(ActionType type) {
    final current = _levels[type] ?? 0;
    final upgrades = SpellUpgrade.upgradeTree[type];
    if (upgrades == null || current >= upgrades.length) return null;
    return upgrades[current];
  }

  /// Whether a specific apex (level 3) upgrade is unlocked.
  bool hasApex(ActionType type) => (_levels[type] ?? 0) >= 3;

  /// Serialize to JSON-compatible map.
  Map<String, int> toJson() {
    return _levels.map((k, v) => MapEntry(k.name, v));
  }

  /// Deserialize from JSON map.
  void loadFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    for (final entry in json.entries) {
      try {
        final type = ActionType.values.firstWhere((e) => e.name == entry.key);
        _levels[type] = (entry.value as int?) ?? 0;
      } catch (_) {
        // Unknown action type in save — skip
      }
    }
  }

  /// Reset all upgrades (for new game).
  void reset() {
    for (final key in _levels.keys) {
      _levels[key] = 0;
    }
  }
}
