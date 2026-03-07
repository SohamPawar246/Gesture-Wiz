import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../systems/hand_tracking/coordinate_mapper.dart';
import '../systems/hand_tracking/landmark_model.dart';
import '../systems/hand_tracking/tracking_service.dart';
import '../systems/gesture/gesture_type.dart';
import '../systems/gesture/rule_based_recognizer.dart';
import '../systems/gesture/gesture_state_machine.dart';
import '../systems/action_system.dart';
import '../systems/wave_manager.dart';
import '../models/spell.dart';
import '../models/player_stats.dart';
import '../models/enemy_type.dart';
import 'palette.dart';
import 'components/virtual_hand.dart';
import 'components/spell_effect.dart';
import 'components/dungeon_background.dart';
import 'components/screen_shake.dart';
import 'components/retro_overlay.dart';
import 'components/enemy.dart';
import 'components/projectile.dart';
import 'components/floating_text.dart';
import 'components/damage_flash.dart';
import 'components/death_pop.dart';
import 'components/impact_frame.dart';
import 'components/texel_splat.dart';
import '../systems/audio_manager.dart';

class FpvGame extends FlameGame with MouseMovementDetector, TapCallbacks, SecondaryTapCallbacks {
  late CoordinateMapper _mapper;
  final Map<int, VirtualHand> _hands = {};
  late DungeonBackground _background;
  late ScreenShake _screenShake;
  late DamageFlash _damageFlash;

  // Active enemies
  final List<Enemy> _enemies = [];

  // Combo / kill streak
  double _lastKillTime = 0;
  int _comboMultiplier = 1;
  int _killStreak = 0;
  double _killStreakTimer = 0;
  static const double _comboWindow = 2.0;

  // Shield state
  double _shieldTimer = 0;
  bool _shieldActive = false;

  // Gesture Subsystem — per hand
  final RuleBasedRecognizer _gestureRecognizer = RuleBasedRecognizer();
  final GestureStateMachine _stateMachine0 = GestureStateMachine();
  final GestureStateMachine _stateMachine1 = GestureStateMachine();
  final void Function(GestureType detectedGesture)? onGestureDetected;

  // Game state callbacks
  final void Function()? onGameOver;
  final void Function(int wave)? onWaveChanged;
  final void Function()? onVictory;

  // Action System (replaces SpellEngine)
  final ActionSystem _actionSystem = ActionSystem.theEye();

  List<GameAction> get knownActions => _actionSystem.actions;

  // Wave Manager
  late WaveManager _waveManager;

  // Progression
  final PlayerStats playerStats;

  // Hand Tracking (abstract — UdpService on desktop, WebTrackingService on web)
  final TrackingService? trackingService;

  // Mouse Input
  Vector2 _mouseCursor = Vector2.zero();
  bool _isMousePressed = false;
  bool _isRightMousePressed = false;

  // Game state
  bool _gameRunning = false;
  double _gameTime = 0;

  FpvGame({
    this.onGestureDetected,
    this.onGameOver,
    this.onWaveChanged,
    this.onVictory,
    required this.playerStats,
    this.trackingService,
  });

  @override
  Color backgroundColor() => Palette.bgDeep;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _mapper = CoordinateMapper(size);

    // Background
    _background = DungeonBackground();
    add(_background);

    // Two hands
    for (int i = 0; i < 2; i++) {
      final hand = VirtualHand();
      _hands[i] = hand;
      add(hand);
    }

    // Screen shake
    _screenShake = ScreenShake();
    add(_screenShake);

    // Damage flash
    _damageFlash = DamageFlash();
    add(_damageFlash);

    // CRT overlay
    add(RetroOverlay());

    // Audio Init
    await AudioManager.init();

    // Wave manager
    _waveManager = WaveManager(
      onEnemySpawn: _spawnEnemy,
      onWaveStart: (wave) {
        AudioManager.playSfx('wave.wav', volume: 0.6);
        playerStats.setWave(wave);
        onWaveChanged?.call(wave);
        add(FloatingText(
          position: Vector2(size.x / 2, size.y / 2),
          text: 'CHAMBER $wave',
          color: Palette.fireGold,
          fontSize: 36,
          duration: 2.0,
        ));
      },
      onWaveComplete: (wave) {
        AudioManager.playSfx('wave.wav', volume: 0.6);
        add(FloatingText(
          position: Vector2(size.x / 2, size.y / 2),
          text: 'CHAMBER $wave CLEAR',
          color: Palette.fireGold,
          fontSize: 28,
          duration: 2.0,
        ));
      },
      onAllWavesClear: () {
        onVictory?.call();
      },
      onBossSpawn: () {
        AudioManager.playSfx('explode.wav', volume: 0.8);
        _screenShake.trigger(intensity: 20.0, decay: 3.0);
        add(FloatingText(
          position: Vector2(size.x / 2, size.y * 0.35),
          text: 'THE REBEL APPROACHES',
          color: Palette.impactRed,
          fontSize: 32,
          duration: 3.0,
        ));
      },
    );

    _gameRunning = true;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _mapper = CoordinateMapper(size);
  }

  void restartGame() {
    for (final enemy in _enemies) {
      enemy.removeFromParent();
    }
    _enemies.clear();
    _waveManager.reset();
    _stateMachine0.reset();
    _stateMachine1.reset();
    playerStats.resetForNewGame();
    _comboMultiplier = 1;
    _killStreak = 0;
    _killStreakTimer = 0;
    _shieldTimer = 0;
    _shieldActive = false;
    _gameTime = 0;
    _gameRunning = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (size.x <= 0 || size.y <= 0) return;
    if (!_gameRunning) return;

    _gameTime += dt;

    // --- Kill streak timer decay ---
    if (_killStreakTimer > 0) {
      _killStreakTimer -= dt;
      if (_killStreakTimer <= 0) {
        _killStreak = 0;
      }
    }

    // --- Compute active action glow color ---
    Color? activeColor;

    // Reset shield state each frame — will be set if openPalm held
    _shieldActive = false;

    // --- Hand tracking (supports 2 hands) ---
    // Poll WebTrackingService if on web (it reads from JS each frame)
    if (trackingService is dynamic && trackingService != null) {
      try { (trackingService as dynamic).poll(); } catch (_) {}
    }
    final bool usingTracking = trackingService != null && trackingService!.isConnected;

    // --- Face tracking for camera pan/parallax ---
    if (usingTracking && trackingService!.facePosition != null) {
      final facePos = trackingService!.facePosition!;
      _background.parallaxX = facePos.x;
      _background.parallaxY = facePos.y;
    } else {
      // Return to center if no face detected
      _background.parallaxX += (0.5 - _background.parallaxX) * dt * 3.0;
      _background.parallaxY += (0.5 - _background.parallaxY) * dt * 3.0;
    }

    for (int handId = 0; handId < 2; handId++) {
      final List<Landmark> landmarks;
      if (usingTracking && trackingService!.getHandLandmarks(handId) != null) {
        landmarks = trackingService!.getHandLandmarks(handId)!;
      } else if (handId == 0 && !usingTracking) {
        landmarks = _generateMouseDrivenLandmarks();
      } else {
        _hands[handId]?.updateLandmarks([], _mapper, dt: dt);
        continue;
      }

      _hands[handId]?.activeGlowColor = activeColor;
      _hands[handId]?.updateLandmarks(landmarks, _mapper, dt: dt);

      // --- Gesture recognition per hand ---
      final rawGesture = _gestureRecognizer.recognize(landmarks);
      final stateMachine = handId == 0 ? _stateMachine0 : _stateMachine1;
      final stableGesture = stateMachine.processFrame(
        rawGesture,
        landmarks: landmarks,
        dt: dt,
      );

      if (stableGesture != GestureType.none) {
        final handPos = landmarks.isNotEmpty
          ? _mapper.mapLandmarkToScreen(landmarks[0])
          : Vector2(size.x / 2, size.y / 2);

        final result = _actionSystem.processGesture(stableGesture, handPos);
        if (result != null) {
          _executeAction(result.action, handPos, dt);
          activeColor = result.action.effectColor;
        }
      }

      // Update hand glow with active action color
      _hands[handId]?.activeGlowColor = activeColor;

      // Gesture callback (from primary hand only)
      if (handId == 0 && onGestureDetected != null) {
        onGestureDetected!(stableGesture);
      }
    }

    _actionSystem.update(dt);
    playerStats.regenerateMana(dt);

    // --- Wave manager ---
    _waveManager.update(dt);

    // --- Shield timer ---
    if (_shieldTimer > 0 && !_shieldActive) {
      _shieldTimer -= dt;
    }

    // --- Enemy collision check ---
    final enemiesToRemove = <Enemy>[];
    for (final enemy in _enemies) {
      if (enemy.isDead) {
        enemiesToRemove.add(enemy);
        continue;
      }

      if (enemy.reachedPlayer) {
        if (_shieldTimer > 0 || _shieldActive) {
          AudioManager.playSfx('shield.wav', volume: 0.5);
          enemy.takeDamage(999);
          add(FloatingText(
            position: enemy.position.clone(),
            text: 'BLOCKED',
            color: Colors.cyanAccent,
            fontSize: 18,
          ));
        } else {
          AudioManager.playSfx('hit.wav', volume: 0.7);
          playerStats.takeDamage(enemy.data.damage);
          _screenShake.trigger(intensity: 15.0);
          _damageFlash.trigger();
          add(FloatingText(
            position: Vector2(size.x / 2, size.y * 0.7),
            text: '-${enemy.data.damage.toInt()} HP',
            color: Palette.impactRed,
            fontSize: 24,
          ));
          
          add(TexelSplat(
            position: Vector2(size.x / 2, size.y), 
            baseColor: Palette.impactRed,
          )..priority = 100);

          enemy.takeDamage(999);
        }
      }
    }

    for (final enemy in enemiesToRemove) {
      _onEnemyDeath(enemy);
    }

    // --- Game over check ---
    if (playerStats.isDead) {
      _gameRunning = false;
      onGameOver?.call();
    }

    // --- Combo multiplier decay ---
    if (_gameTime - _lastKillTime > _comboWindow && _comboMultiplier > 1) {
      _comboMultiplier = 1;
    }
  }

  /// Execute a game action based on its type
  void _executeAction(GameAction action, Vector2 position, double dt) {
    switch (action.type) {
      case ActionType.attack:
        _executeAttack(action, position);
        break;
      case ActionType.push:
        _executeForcePush(action, position);
        break;
      case ActionType.shield:
        _executeShield(action, position, dt);
        break;
      case ActionType.grab:
        _executeGrab(action, position);
        break;
      case ActionType.ultimate:
        _executeUltimate(action, position);
        break;
    }
  }

  void _executeAttack(GameAction action, Vector2 position) {
    if (!playerStats.canCast(action.manaCost)) return;
    playerStats.consumeMana(action.manaCost);

    AudioManager.playSfx('fireball.wav', volume: 0.5);
    
    final target = _findNearestEnemy();
    add(Projectile(
      startPosition: position,
      action: action,
      target: target,
      onHit: (enemy, a) => _onProjectileHit(enemy, a),
    ));

    add(SpellEffect(
      position: position.clone(),
      effectColor: action.effectColor,
      spellName: action.name,
    ));

    _screenShake.trigger(intensity: 6.0);
    playerStats.addXp(5);
  }

  void _executeForcePush(GameAction action, Vector2 position) {
    if (!playerStats.canCast(action.manaCost)) return;
    playerStats.consumeMana(action.manaCost);

    AudioManager.playSfx('explode.wav', volume: 0.5);

    add(Projectile(
      startPosition: position,
      action: action,
    ));

    // Damage enemies near the fist position
    for (final enemy in _enemies) {
      if (!enemy.isDead) {
        final dist = (enemy.position - position).length;
        if (dist < action.radius) {
          enemy.takeDamage(action.damage);
          add(FloatingText(
            position: enemy.position.clone(),
            text: 'PUSHED',
            color: action.effectColor,
            fontSize: 16,
          ));
        }
      }
    }

    add(SpellEffect(
      position: position.clone(),
      effectColor: action.effectColor,
      spellName: action.name,
    ));

    _screenShake.trigger(intensity: 12.0);
    playerStats.addXp(8);
  }

  void _executeShield(GameAction action, Vector2 position, double dt) {
    // Sustained: drain mana per second while held
    final drain = action.manaCost * dt;
    if (!playerStats.canCast(drain)) return;
    playerStats.consumeMana(drain);

    _shieldActive = true;
    _shieldTimer = 0.3; // Lingers briefly after release
  }

  void _executeGrab(GameAction action, Vector2 position) {
    // Grab logic — will be expanded in Phase 2 with interactables
    // For now, check if pinch position is near an enemy (grab-throw preview)
    for (final enemy in _enemies) {
      if (!enemy.isDead) {
        final dist = (enemy.position - position).length;
        if (dist < 80) {
          // "Grabbed" enemy — deal minor damage
          enemy.takeDamage(0.2);
          add(FloatingText(
            position: enemy.position.clone(),
            text: 'GRIP',
            color: action.effectColor,
            fontSize: 14,
          ));
          break; // Only grab one
        }
      }
    }
  }

  void _executeUltimate(GameAction action, Vector2 position) {
    if (!playerStats.canCast(action.manaCost)) return;
    playerStats.consumeMana(action.manaCost);

    AudioManager.playSfx('explode.wav', volume: 0.8);

    add(Projectile(
      startPosition: Vector2(size.x / 2, size.y / 2),
      action: action,
    ));

    for (final enemy in List.of(_enemies)) {
      if (!enemy.isDead) {
        enemy.takeDamage(action.damage);
      }
    }

    add(FloatingText(
      position: Vector2(size.x / 2, size.y * 0.3),
      text: 'OVERWATCH PULSE',
      color: action.effectColor,
      fontSize: 30,
    ));
    add(ImpactFrame()..priority = 100);
    _screenShake.trigger(intensity: 20.0);
    playerStats.addXp(20);
  }

  void _spawnEnemy(EnemyData data) {
    final enemy = Enemy(data: data);
    _enemies.add(enemy);
    add(enemy);
  }

  void _onEnemyDeath(Enemy enemy) {
    _enemies.remove(enemy);
    enemy.removeFromParent();

    AudioManager.playSfx('pop.wav', volume: 0.4);
    add(DeathPop(
      position: enemy.position.clone(),
      primaryColor: enemy.data.primaryColor,
      popScale: enemy.data.kind == EnemyKind.boss ? 2.0 : 1.0,
    ));

    add(TexelSplat(
      position: enemy.position.clone(),
      baseColor: enemy.data.primaryColor,
    )..priority = 100);

    // Score with combo multiplier
    final now = _gameTime;
    if (now - _lastKillTime < _comboWindow) {
      _comboMultiplier = (_comboMultiplier + 1).clamp(1, 4);
    } else {
      _comboMultiplier = 1;
    }
    _lastKillTime = now;

    _killStreak++;
    _killStreakTimer = 2.0;

    final points = enemy.data.points * _comboMultiplier;
    playerStats.addScore(points);
    playerStats.addKill();
    playerStats.addXp(10 * _comboMultiplier);

    add(FloatingText(
      position: enemy.position.clone(),
      text: '+$points',
      color: Palette.fireGold,
      fontSize: 18,
    ));

    if (_comboMultiplier > 1) {
      add(FloatingText(
        position: enemy.position.clone() + Vector2(0, -30),
        text: 'x$_comboMultiplier',
        color: Palette.fireBright,
        fontSize: 22,
      ));
    }

    _announceKillStreak();
    _waveManager.onEnemyKilled();
  }

  void _announceKillStreak() {
    String? text;
    Color color = Palette.fireGold;
    double shakeIntensity = 0;

    switch (_killStreak) {
      case 2:
        text = 'DOUBLE KILL';
        color = Palette.fireBright;
        shakeIntensity = 8;
        break;
      case 3:
        text = 'TRIPLE KILL';
        color = const Color(0xFFFF8800);
        shakeIntensity = 12;
        break;
      case 5:
        text = 'KILLING SPREE';
        color = Palette.impactRed;
        shakeIntensity = 16;
        break;
      case 8:
        text = 'UNSTOPPABLE';
        color = const Color(0xFFFF0044);
        shakeIntensity = 20;
        break;
      case 10:
        text = 'ALL-SEEING';
        color = const Color(0xFFFFFF00);
        shakeIntensity = 25;
        break;
    }

    if (text != null) {
      add(FloatingText(
        position: Vector2(size.x / 2, size.y * 0.3),
        text: text,
        color: color,
        fontSize: 40,
        duration: 2.0,
      ));
      _screenShake.trigger(intensity: shakeIntensity);
    }
  }

  void _onProjectileHit(Enemy enemy, GameAction action) {
    enemy.takeDamage(action.damage);

    if (action.type == ActionType.attack || action.type == ActionType.ultimate) {
      add(ImpactFrame()..priority = 100);
    }
  }

  Enemy? _findNearestEnemy() {
    if (_enemies.isEmpty) return null;
    Enemy? nearest;
    double maxDepth = -1;
    for (final enemy in _enemies) {
      if (!enemy.isDead && enemy.depth > maxDepth) {
        maxDepth = enemy.depth;
        nearest = enemy;
      }
    }
    return nearest;
  }

  // --- Mouse input handlers ---
  @override
  void onMouseMove(PointerHoverInfo info) {
    _mouseCursor = info.eventPosition.global;
  }

  @override
  void onTapDown(TapDownEvent event) => _isMousePressed = true;

  @override
  void onTapUp(TapUpEvent event) => _isMousePressed = false;

  @override
  void onTapCancel(TapCancelEvent event) => _isMousePressed = false;

  @override
  void onSecondaryTapDown(SecondaryTapDownEvent event) => _isRightMousePressed = true;

  @override
  void onSecondaryTapUp(SecondaryTapUpEvent event) => _isRightMousePressed = false;

  @override
  void onSecondaryTapCancel(SecondaryTapCancelEvent event) => _isRightMousePressed = false;

  List<Landmark> _generateMouseDrivenLandmarks() {
    final screenWidth = size.x;
    final screenHeight = size.y;
    final double normX = screenWidth > 0 ? _mouseCursor.x / screenWidth : 0.5;
    final double normY = screenHeight > 0 ? _mouseCursor.y / screenHeight : 0.5;
    final double fingerExt = _isMousePressed ? 0.02 : 0.15;

    return [
      Landmark(x: normX, y: normY + 0.1, z: 0),
      Landmark(x: normX - 0.05, y: normY + 0.08, z: 0),
      Landmark(x: normX - 0.08, y: normY + 0.05, z: 0),
      Landmark(x: normX - 0.10, y: normY + 0.02, z: 0),
      Landmark(x: normX - 0.12, y: normY - (_isMousePressed ? 0.02 : 0.01), z: 0),
      Landmark(x: normX - 0.03, y: normY, z: 0),
      Landmark(x: normX - 0.04, y: normY - (_isRightMousePressed ? 0.15 : fingerExt) * 0.5, z: 0),
      Landmark(x: normX - 0.045, y: normY - (_isRightMousePressed ? 0.15 : fingerExt) * 0.8, z: 0),
      Landmark(x: normX - 0.05, y: normY - (_isRightMousePressed ? 0.15 : fingerExt), z: 0),
      Landmark(x: normX, y: normY - 0.01, z: 0),
      Landmark(x: normX, y: normY - (_isRightMousePressed ? 0.02 : fingerExt) * 0.5 - 0.01, z: 0),
      Landmark(x: normX, y: normY - (_isRightMousePressed ? 0.02 : fingerExt) * 0.8 - 0.01, z: 0),
      Landmark(x: normX, y: normY - (_isRightMousePressed ? 0.02 : fingerExt) - 0.02, z: 0),
      Landmark(x: normX + 0.03, y: normY, z: 0),
      Landmark(x: normX + 0.04, y: normY - (_isRightMousePressed ? 0.02 : fingerExt) * 0.5, z: 0),
      Landmark(x: normX + 0.045, y: normY - (_isRightMousePressed ? 0.02 : fingerExt) * 0.8, z: 0),
      Landmark(x: normX + 0.05, y: normY - (_isRightMousePressed ? 0.02 : fingerExt), z: 0),
      Landmark(x: normX + 0.06, y: normY + 0.02, z: 0),
      Landmark(x: normX + 0.07, y: normY - (_isRightMousePressed ? 0.02 : fingerExt) * 0.3, z: 0),
      Landmark(x: normX + 0.08, y: normY - (_isRightMousePressed ? 0.02 : fingerExt) * 0.5, z: 0),
      Landmark(x: normX + 0.09, y: normY - (_isRightMousePressed ? 0.02 : fingerExt) * 0.7, z: 0),
    ];
  }
}
