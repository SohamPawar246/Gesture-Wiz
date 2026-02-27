import 'dart:math';

import '../models/enemy_type.dart';

/// Manages wave progression — spawns enemies in escalating waves.
class WaveManager {
  int currentWave = 0;
  int _enemiesSpawned = 0;
  int _enemiesInWave = 0;
  int _enemiesKilledInWave = 0;
  double _spawnTimer = 0;
  double _restTimer = 0;
  bool _isResting = true;
  bool _allWavesComplete = false;

  static const int maxWaves = 10;
  static const double restDuration = 4.0; // Seconds between waves

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

  bool get isResting => _isResting;
  bool get allWavesComplete => _allWavesComplete;
  double get restProgress => (_restTimer / restDuration).clamp(0.0, 1.0);

  void reset() {
    currentWave = 0;
    _enemiesSpawned = 0;
    _enemiesInWave = 0;
    _enemiesKilledInWave = 0;
    _spawnTimer = 0;
    _restTimer = 0;
    _isResting = true;
    _allWavesComplete = false;
  }

  void onEnemyKilled() {
    _enemiesKilledInWave++;
    if (_enemiesKilledInWave >= _enemiesInWave && _enemiesSpawned >= _enemiesInWave) {
      onWaveComplete?.call(currentWave);

      if (currentWave >= maxWaves) {
        _allWavesComplete = true;
        onAllWavesClear?.call();
      } else {
        _isResting = true;
        _restTimer = 0;
      }
    }
  }

  void update(double dt) {
    if (_allWavesComplete) return;

    if (_isResting) {
      _restTimer += dt;
      if (_restTimer >= restDuration) {
        _startNextWave();
      }
      return;
    }

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

  void _startNextWave() {
    currentWave++;
    _enemiesSpawned = 0;
    _enemiesKilledInWave = 0;
    _spawnTimer = 0;
    _isResting = false;

    final config = _getWaveConfig(currentWave);
    _enemiesInWave = config.enemyCount;

    onWaveStart?.call(currentWave);
  }

  void _spawnEnemy(_WaveConfig config) {
    final rng = Random();
    final pool = config.enemyPool;
    final kind = pool[rng.nextInt(pool.length)];
    final data = EnemyData.table[kind]!;

    _enemiesSpawned++;
    onEnemySpawn?.call(data);

    // Boss wave special handling
    if (currentWave == maxWaves && _enemiesSpawned == 1) {
      final bossData = EnemyData.table[EnemyKind.boss]!;
      onEnemySpawn?.call(bossData);
      onBossSpawn?.call();
    }
  }

  _WaveConfig _getWaveConfig(int wave) {
    switch (wave) {
      case 1:
        return _WaveConfig(
          enemyCount: 5,
          spawnInterval: 2.5,
          enemyPool: [EnemyKind.skull],
        );
      case 2:
        return _WaveConfig(
          enemyCount: 7,
          spawnInterval: 2.0,
          enemyPool: [EnemyKind.skull],
        );
      case 3:
        return _WaveConfig(
          enemyCount: 8,
          spawnInterval: 1.8,
          enemyPool: [EnemyKind.skull, EnemyKind.skull, EnemyKind.eyeball],
        );
      case 4:
        return _WaveConfig(
          enemyCount: 10,
          spawnInterval: 1.5,
          enemyPool: [EnemyKind.skull, EnemyKind.eyeball],
        );
      case 5:
        return _WaveConfig(
          enemyCount: 12,
          spawnInterval: 1.3,
          enemyPool: [EnemyKind.skull, EnemyKind.eyeball, EnemyKind.slime],
        );
      case 6:
        return _WaveConfig(
          enemyCount: 14,
          spawnInterval: 1.2,
          enemyPool: [EnemyKind.eyeball, EnemyKind.slime, EnemyKind.slime],
        );
      case 7:
        return _WaveConfig(
          enemyCount: 15,
          spawnInterval: 1.0,
          enemyPool: [EnemyKind.skull, EnemyKind.eyeball, EnemyKind.slime, EnemyKind.knight],
        );
      case 8:
        return _WaveConfig(
          enemyCount: 16,
          spawnInterval: 1.0,
          enemyPool: [EnemyKind.eyeball, EnemyKind.slime, EnemyKind.knight],
        );
      case 9:
        return _WaveConfig(
          enemyCount: 18,
          spawnInterval: 0.8,
          enemyPool: [EnemyKind.skull, EnemyKind.eyeball, EnemyKind.slime, EnemyKind.knight],
        );
      case 10:
        return _WaveConfig(
          enemyCount: 5,
          spawnInterval: 2.0,
          enemyPool: [EnemyKind.skull, EnemyKind.knight],
        );
      default:
        return _WaveConfig(
          enemyCount: 20,
          spawnInterval: 0.6,
          enemyPool: [EnemyKind.skull, EnemyKind.eyeball, EnemyKind.slime, EnemyKind.knight],
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
