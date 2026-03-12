import 'dart:math';

import '../models/enemy_type.dart';

/// Manages wave progression — spawns enemies in escalating waves.
/// Supports multi-wave levels: startLevel(startWave, endWave) runs
/// consecutive waves and only fires onAllWavesClear when the last wave
/// in the range is complete.
class WaveManager {
  int currentWave = 0;
  int _enemiesSpawned = 0;
  int _enemiesInWave = 0;
  int _enemiesKilledInWave = 0;
  double _spawnTimer = 0;
  bool _isActive = false;
  bool _allWavesComplete = false;

  /// The inclusive range of waves for the current level.
  int _startWave = 1;
  int _endWave = 1;

  /// Pending next-wave transition timer (> 0 means waiting to start next wave).
  double _nextWaveDelay = 0;
  bool _nextWavePending = false;

  /// Which wave within the level (1-based relative index for HUD display).
  int get waveInLevel =>
      (currentWave - _startWave + 1).clamp(1, totalWavesInLevel);
  int get totalWavesInLevel => _endWave - _startWave + 1;

  final void Function(EnemyData enemyData)? onEnemySpawn;
  final void Function(int wave)? onWaveStart;
  final void Function(int wave)? onWaveComplete;
  final void Function()? onAllWavesClear;
  final void Function()? onBossSpawn;

  WaveManager({
    this.onEnemySpawn,
    this.onWaveStart,
    this.onWaveComplete,
    this.onAllWavesClear,
    this.onBossSpawn,
  });

  bool get isActive => _isActive;
  bool get allWavesComplete => _allWavesComplete;

  void reset() {
    currentWave = 0;
    _enemiesSpawned = 0;
    _enemiesInWave = 0;
    _enemiesKilledInWave = 0;
    _spawnTimer = 0;
    _isActive = false;
    _allWavesComplete = false;
    _startWave = 1;
    _endWave = 1;
    _nextWaveDelay = 0;
    _nextWavePending = false;
  }

  void onEnemyKilled() {
    _enemiesKilledInWave++;
    if (_enemiesKilledInWave >= _enemiesInWave &&
        _enemiesSpawned >= _enemiesInWave) {
      _isActive = false;
      onWaveComplete?.call(currentWave);

      if (currentWave >= _endWave) {
        // All waves in this level are done
        _allWavesComplete = true;
        onAllWavesClear?.call();
      } else {
        // Queue the next wave after a short delay
        _nextWavePending = true;
        _nextWaveDelay = 1.5;
      }
    }
  }

  void update(double dt) {
    // Handle pending next-wave transition
    if (_nextWavePending) {
      _nextWaveDelay -= dt;
      if (_nextWaveDelay <= 0) {
        _nextWavePending = false;
        if (!_allWavesComplete) {
          _startSingleWave(currentWave + 1);
        }
      }
      return;
    }

    if (_allWavesComplete || !_isActive) return;

    // Spawn enemies
    if (_enemiesSpawned < _enemiesInWave) {
      _spawnTimer += dt;
      final config = _getWaveConfig(currentWave);
      if (_spawnTimer >= config.spawnInterval) {
        _spawnTimer = 0;
        _spawnEnemy(config);
      }
    }
  }

  /// Start a multi-wave level from [startWave] to [endWave] inclusive.
  void startLevel(int startWave, int endWave) {
    _startWave = startWave;
    _endWave = endWave;
    _allWavesComplete = false;
    _nextWavePending = false;
    _nextWaveDelay = 0;
    _startSingleWave(startWave);
  }

  /// Legacy single-wave start — kept for backward compatibility.
  void startWave(int waveIndex) {
    _startWave = waveIndex;
    _endWave = waveIndex;
    _allWavesComplete = false;
    _nextWavePending = false;
    _nextWaveDelay = 0;
    _startSingleWave(waveIndex);
  }

  /// Internal: begin a specific wave index.
  void _startSingleWave(int waveIndex) {
    currentWave = waveIndex;
    _enemiesSpawned = 0;
    _enemiesKilledInWave = 0;
    _isActive = true;

    final config = _getWaveConfig(currentWave);
    _enemiesInWave = config.enemyCount;

    onWaveStart?.call(currentWave);

    // Spawn the first enemy immediately — no waiting
    _spawnEnemy(config);
    _spawnTimer = 0;
  }

  void _spawnEnemy(_WaveConfig config) {
    final rng = Random();
    final pool = config.enemyPool;
    final kind = pool[rng.nextInt(pool.length)];
    final data = EnemyData.table[kind]!;

    _enemiesSpawned++;
    onEnemySpawn?.call(data);

    // Boss wave special handling (wave 21 is the boss wave)
    if (currentWave == 21 && _enemiesSpawned == 1) {
      final bossData = EnemyData.table[EnemyKind.boss]!;
      onEnemySpawn?.call(bossData);
      onBossSpawn?.call();
    }
  }

  _WaveConfig _getWaveConfig(int wave) {
    switch (wave) {
      // ═══════════════════════════════════════════════════════════════
      // SECTOR ALPHA (waves 1-3): Tutorial warmup — skulls only
      // ═══════════════════════════════════════════════════════════════
      case 1:
        return _WaveConfig(
          enemyCount: 4,
          spawnInterval: 2.5,
          enemyPool: [EnemyKind.skull],
        );
      case 2:
        return _WaveConfig(
          enemyCount: 5,
          spawnInterval: 2.2,
          enemyPool: [EnemyKind.skull],
        );
      case 3:
        return _WaveConfig(
          enemyCount: 6,
          spawnInterval: 2.0,
          enemyPool: [EnemyKind.skull],
        );

      // ═══════════════════════════════════════════════════════════════
      // NEON BLVD (waves 4-6): Introduce eyeballs
      // ═══════════════════════════════════════════════════════════════
      case 4:
        return _WaveConfig(
          enemyCount: 6,
          spawnInterval: 2.0,
          enemyPool: [EnemyKind.skull, EnemyKind.skull, EnemyKind.eyeball],
        );
      case 5:
        return _WaveConfig(
          enemyCount: 8,
          spawnInterval: 1.8,
          enemyPool: [EnemyKind.skull, EnemyKind.eyeball],
        );
      case 6:
        return _WaveConfig(
          enemyCount: 10,
          spawnInterval: 1.6,
          enemyPool: [EnemyKind.skull, EnemyKind.eyeball, EnemyKind.eyeball],
        );

      // ═══════════════════════════════════════════════════════════════
      // DARK ALLEY (waves 7-9): Eyeballs + introduce slimes
      // ═══════════════════════════════════════════════════════════════
      case 7:
        return _WaveConfig(
          enemyCount: 7,
          spawnInterval: 1.8,
          enemyPool: [EnemyKind.skull, EnemyKind.eyeball, EnemyKind.slime],
        );
      case 8:
        return _WaveConfig(
          enemyCount: 9,
          spawnInterval: 1.6,
          enemyPool: [EnemyKind.eyeball, EnemyKind.slime],
        );
      case 9:
        return _WaveConfig(
          enemyCount: 11,
          spawnInterval: 1.4,
          enemyPool: [EnemyKind.skull, EnemyKind.eyeball, EnemyKind.slime],
        );

      // ═══════════════════════════════════════════════════════════════
      // CORP PLAZA / UNDERGROUND (waves 10-13): Full roster minus knight
      // ═══════════════════════════════════════════════════════════════
      case 10:
        return _WaveConfig(
          enemyCount: 10,
          spawnInterval: 1.5,
          enemyPool: [EnemyKind.skull, EnemyKind.eyeball, EnemyKind.slime],
        );
      case 11:
        return _WaveConfig(
          enemyCount: 12,
          spawnInterval: 1.3,
          enemyPool: [EnemyKind.eyeball, EnemyKind.slime, EnemyKind.slime],
        );
      case 12:
        return _WaveConfig(
          enemyCount: 14,
          spawnInterval: 1.2,
          enemyPool: [EnemyKind.skull, EnemyKind.eyeball, EnemyKind.slime],
        );
      case 13:
        return _WaveConfig(
          enemyCount: 16,
          spawnInterval: 1.1,
          enemyPool: [EnemyKind.eyeball, EnemyKind.slime, EnemyKind.slime],
        );

      // ═══════════════════════════════════════════════════════════════
      // SYS-MAIN / THE HUB (waves 14-17): Introduce knights, harder
      // ═══════════════════════════════════════════════════════════════
      case 14:
        return _WaveConfig(
          enemyCount: 14,
          spawnInterval: 1.2,
          enemyPool: [EnemyKind.eyeball, EnemyKind.slime, EnemyKind.knight],
        );
      case 15:
        return _WaveConfig(
          enemyCount: 16,
          spawnInterval: 1.1,
          enemyPool: [
            EnemyKind.skull,
            EnemyKind.eyeball,
            EnemyKind.slime,
            EnemyKind.knight,
          ],
        );
      case 16:
        return _WaveConfig(
          enemyCount: 18,
          spawnInterval: 1.0,
          enemyPool: [EnemyKind.eyeball, EnemyKind.slime, EnemyKind.knight],
        );
      case 17:
        return _WaveConfig(
          enemyCount: 20,
          spawnInterval: 0.9,
          enemyPool: [
            EnemyKind.skull,
            EnemyKind.eyeball,
            EnemyKind.slime,
            EnemyKind.knight,
          ],
        );

      // ═══════════════════════════════════════════════════════════════
      // CORE FRAME (waves 18-21): Endgame gauntlet
      // ═══════════════════════════════════════════════════════════════
      case 18:
        return _WaveConfig(
          enemyCount: 18,
          spawnInterval: 1.0,
          enemyPool: [EnemyKind.eyeball, EnemyKind.slime, EnemyKind.knight],
        );
      case 19:
        return _WaveConfig(
          enemyCount: 20,
          spawnInterval: 0.9,
          enemyPool: [
            EnemyKind.skull,
            EnemyKind.eyeball,
            EnemyKind.slime,
            EnemyKind.knight,
          ],
        );
      case 20:
        return _WaveConfig(
          enemyCount: 22,
          spawnInterval: 0.8,
          enemyPool: [
            EnemyKind.eyeball,
            EnemyKind.slime,
            EnemyKind.knight,
            EnemyKind.knight,
          ],
        );
      case 21:
        return _WaveConfig(
          enemyCount: 24,
          spawnInterval: 0.7,
          enemyPool: [
            EnemyKind.skull,
            EnemyKind.eyeball,
            EnemyKind.slime,
            EnemyKind.knight,
          ],
        );

      // ═══════════════════════════════════════════════════════════════
      // SERVER ZERO (waves 22-24): Boss gauntlet
      // ═══════════════════════════════════════════════════════════════
      case 22:
        return _WaveConfig(
          enemyCount: 15,
          spawnInterval: 1.0,
          enemyPool: [EnemyKind.knight, EnemyKind.slime, EnemyKind.eyeball],
        );
      case 23:
        return _WaveConfig(
          enemyCount: 18,
          spawnInterval: 0.8,
          enemyPool: [
            EnemyKind.skull,
            EnemyKind.eyeball,
            EnemyKind.slime,
            EnemyKind.knight,
          ],
        );
      case 24:
        return _WaveConfig(
          enemyCount: 8,
          spawnInterval: 2.0,
          enemyPool: [EnemyKind.knight, EnemyKind.knight],
        );

      default:
        return _WaveConfig(
          enemyCount: 25,
          spawnInterval: 0.6,
          enemyPool: [
            EnemyKind.skull,
            EnemyKind.eyeball,
            EnemyKind.slime,
            EnemyKind.knight,
          ],
        );
    }
  }
}

class _WaveConfig {
  final int enemyCount;
  final double spawnInterval;
  final List<EnemyKind> enemyPool;

  _WaveConfig({
    required this.enemyCount,
    required this.spawnInterval,
    required this.enemyPool,
  });
}
