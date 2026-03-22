import 'package:flutter_test/flutter_test.dart';
import 'package:fpv_magic/systems/wave_manager.dart';
import 'package:fpv_magic/models/enemy_type.dart';

void main() {
  group('WaveManager', () {
    late WaveManager waveManager;
    late List<EnemyData> spawnedEnemies;
    late List<int> startedWaves;
    late List<int> completedWaves;
    late int allWavesClearCount;

    setUp(() {
      spawnedEnemies = [];
      startedWaves = [];
      completedWaves = [];
      allWavesClearCount = 0;

      waveManager = WaveManager(
        onEnemySpawn: (data) => spawnedEnemies.add(data),
        onWaveStart: (wave) => startedWaves.add(wave),
        onWaveComplete: (wave) => completedWaves.add(wave),
        onAllWavesClear: () => allWavesClearCount++,
      );
    });

    group('initialization', () {
      test('should start inactive', () {
        expect(waveManager.isActive, false);
        expect(waveManager.currentWave, 0);
        expect(waveManager.allWavesComplete, false);
      });
    });

    group('startWave', () {
      test('should activate wave system', () {
        waveManager.startWave(1);
        expect(waveManager.isActive, true);
        expect(waveManager.currentWave, 1);
      });

      test('should call onWaveStart callback', () {
        waveManager.startWave(1);
        expect(startedWaves, contains(1));
      });

      test('should spawn first enemy immediately', () {
        waveManager.startWave(1);
        expect(spawnedEnemies.length, 1);
      });
    });

    group('startLevel (multi-wave)', () {
      test('should set wave range correctly', () {
        waveManager.startLevel(4, 6);
        expect(waveManager.currentWave, 4);
        expect(waveManager.waveInLevel, 1);
        expect(waveManager.totalWavesInLevel, 3);
      });

      test('waveInLevel should track progress within level', () {
        waveManager.startLevel(4, 6);
        expect(waveManager.waveInLevel, 1);

        // Complete wave 4, start wave 5
        _completeCurrentWave(waveManager, spawnedEnemies);
        waveManager.update(2.0); // Wait for next wave delay

        expect(waveManager.currentWave, 5);
        expect(waveManager.waveInLevel, 2);
      });
    });

    group('update spawning', () {
      test('should spawn enemies over time', () {
        waveManager.startWave(1);
        final initialCount = spawnedEnemies.length;

        // Wave 1 has spawn interval of 2.5s
        waveManager.update(3.0);
        expect(spawnedEnemies.length, greaterThan(initialCount));
      });

      test('should stop spawning after all enemies spawned', () {
        waveManager.startWave(1);
        // Wave 1 has 4 enemies

        // Update enough to spawn all
        for (int i = 0; i < 20; i++) {
          waveManager.update(1.0);
        }

        expect(spawnedEnemies.length, 4);
      });
    });

    group('onEnemyKilled', () {
      test('should complete wave when all enemies killed', () {
        waveManager.startWave(1);
        // Wave 1: 4 enemies

        // Spawn all enemies first
        for (int i = 0; i < 20; i++) {
          waveManager.update(1.0);
        }
        expect(spawnedEnemies.length, 4);

        // Kill all enemies
        for (int i = 0; i < 4; i++) {
          waveManager.onEnemyKilled();
        }

        expect(completedWaves, contains(1));
        expect(waveManager.isActive, false);
      });

      test('should trigger allWavesClear on single-wave completion', () {
        waveManager.startWave(1);

        _completeCurrentWave(waveManager, spawnedEnemies);

        expect(allWavesClearCount, 1);
        expect(waveManager.allWavesComplete, true);
      });

      test('should auto-start next wave in multi-wave level', () {
        waveManager.startLevel(1, 2);

        // Complete wave 1
        _completeCurrentWave(waveManager, spawnedEnemies);

        expect(waveManager.allWavesComplete, false);
        expect(completedWaves, contains(1));

        // Wait for next wave delay
        waveManager.update(2.0);

        expect(waveManager.currentWave, 2);
        expect(startedWaves, contains(2));
      });

      test('should trigger allWavesClear after final wave in level', () {
        waveManager.startLevel(1, 2);

        // Complete wave 1
        _completeCurrentWave(waveManager, spawnedEnemies);

        // Capture count BEFORE wave 2 starts
        final wave1Total = spawnedEnemies.length;

        // Wait for next wave delay - this starts wave 2 and spawns first enemy
        waveManager.update(2.0);

        // Spawn remaining wave 2 enemies
        for (int i = 0; i < 30; i++) {
          waveManager.update(1.0);
        }

        // Kill all wave 2 enemies (total - wave1 killed enemies)
        final wave2Count = spawnedEnemies.length - wave1Total;
        for (int i = 0; i < wave2Count; i++) {
          waveManager.onEnemyKilled();
        }

        expect(allWavesClearCount, 1);
        expect(waveManager.allWavesComplete, true);
      });
    });

    group('reset', () {
      test('should reset all state', () {
        waveManager.startWave(5);
        waveManager.onEnemyKilled();

        waveManager.reset();

        expect(waveManager.currentWave, 0);
        expect(waveManager.isActive, false);
        expect(waveManager.allWavesComplete, false);
        expect(waveManager.waveInLevel, 1);
        expect(waveManager.totalWavesInLevel, 1);
      });
    });

    group('wave configurations', () {
      test('wave 1 should have skulls only', () {
        waveManager.startWave(1);
        // All spawned enemies should be skulls
        for (final enemy in spawnedEnemies) {
          expect(enemy.kind, EnemyKind.skull);
        }
      });

      test('later waves should have mixed enemy types', () {
        waveManager.startWave(15);

        // Spawn several enemies
        for (int i = 0; i < 10; i++) {
          waveManager.update(2.0);
        }

        final kinds = spawnedEnemies.map((e) => e.kind).toSet();
        // Wave 15 pool includes skull, eyeball, slime, knight
        expect(kinds.length, greaterThan(1));
      });

      test('enemy count should increase with wave number', () {
        // Wave 1: 4 enemies
        waveManager.startWave(1);
        for (int i = 0; i < 20; i++) {
          waveManager.update(1.0);
        }
        final wave1Count = spawnedEnemies.length;

        waveManager.reset();
        spawnedEnemies.clear();

        // Wave 10: more enemies
        waveManager.startWave(10);
        for (int i = 0; i < 30; i++) {
          waveManager.update(1.0);
        }
        final wave10Count = spawnedEnemies.length;

        expect(wave10Count, greaterThan(wave1Count));
      });
    });
  });
}

/// Helper to fully complete the current wave
void _completeCurrentWave(WaveManager wm, List<EnemyData> spawned) {
  // Spawn all enemies
  for (int i = 0; i < 30; i++) {
    wm.update(1.0);
  }

  // Kill all spawned enemies
  for (int i = 0; i < spawned.length; i++) {
    wm.onEnemyKilled();
  }
}
