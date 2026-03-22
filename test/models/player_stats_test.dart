import 'package:flutter_test/flutter_test.dart';
import 'package:fpv_magic/models/player_stats.dart';
import 'package:fpv_magic/systems/save_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PlayerStats', () {
    late PlayerStats playerStats;
    late SaveSystem saveSystem;

    setUp(() async {
      // Set up mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      saveSystem = SaveSystem();
      playerStats = PlayerStats(saveSystem: saveSystem);
    });

    group('initialization', () {
      test('should have default values', () {
        expect(playerStats.level, 1);
        expect(playerStats.currentXp, 0);
        expect(playerStats.score, 0);
        expect(playerStats.killCount, 0);
      });

      test('should calculate maxMana based on level', () {
        expect(playerStats.maxMana, 100.0); // Level 1
      });

      test('should calculate maxHp based on level', () {
        expect(playerStats.maxHp, 100.0); // Level 1
      });
    });

    group('load', () {
      test('should load persisted values', () async {
        SharedPreferences.setMockInitialValues({
          'player_level': 5,
          'player_xp': 150,
          'map_unlocked_nodes': ['1', '2', '3'],
          'map_completed_nodes': ['1', '2'],
          'map_current_node': '3',
        });

        await playerStats.load();

        expect(playerStats.level, 5);
        expect(playerStats.currentXp, 150);
        expect(playerStats.unlockedNodes, ['1', '2', '3']);
        expect(playerStats.completedNodes, ['1', '2']);
        expect(playerStats.currentNodeId, '3');
      });

      test('should reset HP and mana to max on load', () async {
        await playerStats.load();
        expect(playerStats.currentHp, playerStats.maxHp);
        expect(playerStats.currentMana, playerStats.maxMana);
      });
    });

    group('mana management', () {
      test('canCast should return true when enough mana', () async {
        await playerStats.load();
        expect(playerStats.canCast(50.0), true);
      });

      test('canCast should return false when not enough mana', () async {
        await playerStats.load();
        expect(playerStats.canCast(200.0), false);
      });

      test('consumeMana should reduce mana', () async {
        await playerStats.load();
        final before = playerStats.currentMana;
        final consumed = playerStats.consumeMana(30.0);

        expect(consumed, true);
        expect(playerStats.currentMana, before - 30.0);
      });

      test('consumeMana should fail when insufficient mana', () async {
        await playerStats.load();
        final before = playerStats.currentMana;
        final consumed = playerStats.consumeMana(500.0);

        expect(consumed, false);
        expect(playerStats.currentMana, before);
      });

      test('regenerateMana should increase mana over time', () async {
        await playerStats.load();
        playerStats.consumeMana(50.0);
        final before = playerStats.currentMana;

        playerStats.regenerateMana(1.0);

        expect(playerStats.currentMana, greaterThan(before));
      });

      test('regenerateMana should not exceed maxMana', () async {
        await playerStats.load();
        // Regen when already at max
        playerStats.regenerateMana(10.0);

        expect(playerStats.currentMana, playerStats.maxMana);
      });
    });

    group('HP management', () {
      test('takeDamage should reduce HP', () async {
        await playerStats.load();
        final before = playerStats.currentHp;

        playerStats.takeDamage(25.0);

        expect(playerStats.currentHp, before - 25.0);
      });

      test('takeDamage should not go below zero', () async {
        await playerStats.load();
        playerStats.takeDamage(500.0);

        expect(playerStats.currentHp, 0);
      });

      test('isDead should return true when HP is zero', () async {
        await playerStats.load();
        playerStats.takeDamage(500.0);

        expect(playerStats.isDead, true);
      });

      test('heal should increase HP', () async {
        await playerStats.load();
        playerStats.takeDamage(50.0);
        final before = playerStats.currentHp;

        playerStats.heal(20.0);

        expect(playerStats.currentHp, before + 20.0);
      });

      test('heal should not exceed maxHp', () async {
        await playerStats.load();
        playerStats.takeDamage(10.0);
        playerStats.heal(100.0);

        expect(playerStats.currentHp, playerStats.maxHp);
      });
    });

    group('score and kills', () {
      test('addScore should increase score', () {
        playerStats.addScore(100);
        expect(playerStats.score, 100);

        playerStats.addScore(50);
        expect(playerStats.score, 150);
      });

      test('addKill should increment kill count', () {
        playerStats.addKill();
        playerStats.addKill();
        expect(playerStats.killCount, 2);
      });
    });

    group('XP and leveling', () {
      test('addXp should increase XP', () async {
        await playerStats.load();
        playerStats.addXp(50);
        expect(playerStats.currentXp, 50);
      });

      test('should level up when XP exceeds maxXp', () async {
        await playerStats.load();
        final initialMaxXp = playerStats.maxXp;

        playerStats.addXp(initialMaxXp + 10);

        expect(playerStats.level, 2);
        expect(playerStats.currentXp, 10);
      });

      test('should handle multiple level ups', () async {
        await playerStats.load();
        // Give massive XP
        playerStats.addXp(1000);

        expect(playerStats.level, greaterThan(2));
      });

      test('leveling up should restore HP and mana', () async {
        await playerStats.load();
        playerStats.takeDamage(50.0);
        playerStats.consumeMana(50.0);

        playerStats.addXp(playerStats.maxXp);

        expect(playerStats.currentHp, playerStats.maxHp);
        expect(playerStats.currentMana, playerStats.maxMana);
      });

      test('maxXp should scale with level', () async {
        SharedPreferences.setMockInitialValues({
          'player_level': 1,
          'player_xp': 0,
        });
        await playerStats.load();
        final level1MaxXp = playerStats.maxXp;

        SharedPreferences.setMockInitialValues({
          'player_level': 5,
          'player_xp': 0,
        });
        final stats2 = PlayerStats(saveSystem: saveSystem);
        await stats2.load();

        expect(stats2.maxXp, greaterThan(level1MaxXp));
      });
    });

    group('map progression', () {
      test('completeNode should add to completed list', () async {
        await playerStats.load();
        playerStats.completeNode('1', ['2', '3']);

        expect(playerStats.completedNodes, contains('1'));
      });

      test('completeNode should unlock new nodes', () async {
        await playerStats.load();
        playerStats.completeNode('1', ['2', '3']);

        expect(playerStats.unlockedNodes, containsAll(['1', '2', '3']));
      });

      test('should not duplicate completed nodes', () async {
        await playerStats.load();
        playerStats.completeNode('1', []);
        playerStats.completeNode('1', []);

        expect(playerStats.completedNodes.where((n) => n == '1').length, 1);
      });

      test('setCurrentNode should update current node', () async {
        await playerStats.load();
        playerStats.setCurrentNode('5');

        expect(playerStats.currentNodeId, '5');
      });

      test('unlockAllNodes should unlock every node', () async {
        await playerStats.load();
        playerStats.unlockAllNodes();

        // Should have many nodes unlocked
        expect(playerStats.unlockedNodes.length, greaterThan(5));
      });
    });

    group('resetForNewGame', () {
      test('should reset all progress except level', () async {
        await playerStats.load();
        playerStats.addScore(500);
        playerStats.takeDamage(50.0);
        playerStats.completeNode('1', ['2']);
        playerStats.setCurrentNode('2');

        playerStats.resetForNewGame();

        expect(playerStats.score, 0);
        expect(playerStats.killCount, 0);
        expect(playerStats.currentHp, playerStats.maxHp);
        expect(playerStats.currentMana, playerStats.maxMana);
        expect(playerStats.currentNodeId, '1');
        expect(playerStats.completedNodes, isEmpty);
        expect(playerStats.unlockedNodes, ['1']);
      });
    });

    group('resetForLevel', () {
      test('should reset HP and mana without affecting map progress', () async {
        await playerStats.load();
        playerStats.takeDamage(50.0);
        playerStats.consumeMana(50.0);
        playerStats.completeNode('1', ['2']);

        playerStats.resetForLevel();

        expect(playerStats.currentHp, playerStats.maxHp);
        expect(playerStats.currentMana, playerStats.maxMana);
        expect(playerStats.completedNodes, contains('1'));
      });
    });

    group('wave tracking', () {
      test('setWave should update current wave', () {
        playerStats.setWave(5);
        expect(playerStats.currentWave, 5);
      });

      test('setTotalWaves should update total', () {
        playerStats.setTotalWaves(10);
        expect(playerStats.totalWaves, 10);
      });
    });
  });
}
