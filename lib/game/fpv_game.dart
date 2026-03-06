import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../systems/hand_tracking/coordinate_mapper.dart';
import '../systems/hand_tracking/landmark_model.dart';
import '../systems/hand_tracking/udp_service.dart';
import '../systems/gesture/gesture_type.dart';
import '../systems/gesture/rule_based_recognizer.dart';
import '../systems/gesture/gesture_state_machine.dart';
import '../systems/spell/spell_engine.dart';
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
import 'components/combo_ring.dart';
import 'components/impact_frame.dart';
import 'components/texel_splat.dart';
import '../systems/audio_manager.dart';

class FpvGame extends FlameGame with MouseMovementDetector, TapCallbacks, SecondaryTapCallbacks {
  late CoordinateMapper _mapper;
  final Map<int, VirtualHand> _hands = {};
  late DungeonBackground _background;
  late ScreenShake _screenShake;
  late DamageFlash _damageFlash;
  late ComboRing _comboRing;

  // Active enemies
  final List<Enemy> _enemies = [];

  // Combo / kill streak
  double _lastKillTime = 0;
  int _comboMultiplier = 1;
  int _killStreak = 0;
  double _killStreakTimer = 0;
  static const double _comboWindow = 2.0;

  // Shield active
  double _shieldTimer = 0;

  // Global spell cooldown (prevent spam)
  double _spellCooldown = 0;
  static const double _spellCooldownDuration = 0.8; // 800ms between casts

  // Gesture Subsystem — per hand
  final RuleBasedRecognizer _gestureRecognizer = RuleBasedRecognizer();
  final GestureStateMachine _stateMachine0 = GestureStateMachine(); // left/primary hand
  final GestureStateMachine _stateMachine1 = GestureStateMachine(); // right/secondary hand
  final void Function(GestureType detectedGesture)? onGestureDetected;
  final void Function(List<GestureType> combo, double timeoutProgress)? onComboChanged;

  // Game state callbacks
  final void Function()? onGameOver;
  final void Function(int wave)? onWaveChanged;
  final void Function()? onVictory;

  // Spell Subsystem — 6 spells
  final SpellEngine _spellEngine = SpellEngine(
    knownSpells: const [
      Spell(
        name: 'Fireball',
        requiredGestures: [GestureType.pinch, GestureType.point],
        difficulty: 1,
        manaCost: 10,
        castWindow: Duration(seconds: 3),
        effectColor: Colors.deepOrange,
        type: SpellType.attack,
        damage: 1.0,
      ),
      Spell(
        name: 'Ice Shield',
        requiredGestures: [GestureType.point, GestureType.vSign],
        difficulty: 2,
        manaCost: 20,
        castWindow: Duration(seconds: 3),
        effectColor: Colors.cyanAccent,
        type: SpellType.defense,
        damage: 0,
      ),
      Spell(
        name: 'Healing Aura',
        requiredGestures: [GestureType.vSign, GestureType.fist],
        difficulty: 2,
        manaCost: 15,
        castWindow: Duration(seconds: 3),
        effectColor: Colors.greenAccent,
        type: SpellType.heal,
        damage: 0,
      ),
      Spell(
        name: 'Lightning Bolt',
        requiredGestures: [GestureType.point, GestureType.point],
        difficulty: 2,
        manaCost: 15,
        castWindow: Duration(seconds: 3),
        effectColor: Color(0xFFFFFF44),
        type: SpellType.attack,
        damage: 1.5,
      ),
      Spell(
        name: 'Earth Wall',
        requiredGestures: [GestureType.fist, GestureType.fist],
        difficulty: 2,
        manaCost: 25,
        castWindow: Duration(seconds: 3),
        effectColor: Color(0xFF886633),
        type: SpellType.defense,
        damage: 0,
      ),
      Spell(
        name: 'Meteor Storm',
        requiredGestures: [GestureType.pinch, GestureType.fist, GestureType.point],
        difficulty: 3,
        manaCost: 50,
        castWindow: Duration(seconds: 4),
        effectColor: Color(0xFFFF4400),
        type: SpellType.ultimate,
        damage: 3.0,
        radius: 999,
      ),
    ],
  );

  List<Spell> get knownSpells => _spellEngine.knownSpells;

  // Wave Manager
  late WaveManager _waveManager;

  // Progression
  final PlayerStats playerStats;

  // Hand Tracking
  final UdpService? udpService;

  // Mouse Input
  Vector2 _mouseCursor = Vector2.zero();
  bool _isMousePressed = false;
  bool _isRightMousePressed = false;

  // Game state
  bool _gameRunning = false;
  double _gameTime = 0;

  FpvGame({
    this.onGestureDetected,
    this.onComboChanged,
    this.onGameOver,
    this.onWaveChanged,
    this.onVictory,
    required this.playerStats,
    this.udpService,
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

    // Damage flash (renders above enemies, below CRT)
    _damageFlash = DamageFlash();
    add(_damageFlash);

    // Combo UI
    _comboRing = ComboRing()..position = Vector2(size.x / 2, size.y * 0.8);
    add(_comboRing);

    // CRT overlay (renders on top of everything)
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
          text: 'WAVE $wave',
          color: Palette.fireGold,
          fontSize: 36,
          duration: 2.0,
        ));
      },
      onWaveComplete: (wave) {
        AudioManager.playSfx('wave.wav', volume: 0.6);
        add(FloatingText(
          position: Vector2(size.x / 2, size.y / 2),
          text: 'WAVE $wave CLEAR!',
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
          text: 'BOSS: FLAME LORD',
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

    // --- Spell cooldown decay ---
    if (_spellCooldown > 0) _spellCooldown -= dt;

    // --- Compute active combo glow color ---
    Color? activeColor;
    if (_spellEngine.currentCombo.isNotEmpty) {
      final currentFirst = _spellEngine.currentCombo.first;
      for (final spell in _spellEngine.knownSpells) {
        if (spell.requiredGestures.first == currentFirst) {
          activeColor = spell.effectColor;
          break;
        }
      }
    }
    
    // Update combo ring
    if (_spellEngine.currentCombo.isNotEmpty && _spellCooldown <= 0) {
      _comboRing.progress = _spellEngine.timeoutProgress;
      _comboRing.ringColor = activeColor ?? Palette.fireGold;
    } else {
      _comboRing.progress = 0.0;
    }

    // --- Hand tracking (supports 2 hands) ---
    final bool usingUdp = udpService != null && udpService!.isConnected;

    for (int handId = 0; handId < 2; handId++) {
      final List<Landmark> landmarks;
      if (usingUdp && udpService!.getHandLandmarks(handId) != null) {
        landmarks = udpService!.getHandLandmarks(handId)!;
      } else if (handId == 0 && !usingUdp) {
        landmarks = _generateMouseDrivenLandmarks();
      } else {
        // No data for this hand — hide it
        _hands[handId]?.updateLandmarks([], _mapper, dt: dt);
        continue;
      }

      _hands[handId]?.activeGlowColor = activeColor;
      _hands[handId]?.updateLandmarks(landmarks, _mapper, dt: dt);

      // Update background parallax from primary hand
      if (handId == 0 && landmarks.isNotEmpty) {
        _background.parallaxX = landmarks[0].x;
        _background.parallaxY = landmarks[0].y;
      }

      // --- Gesture recognition per hand ---
      final rawGesture = _gestureRecognizer.recognize(landmarks);
      final stateMachine = handId == 0 ? _stateMachine0 : _stateMachine1;
      final stableGesture = stateMachine.processFrame(rawGesture);

      if (stableGesture != GestureType.none && _spellCooldown <= 0) {
        final matchedSpell = _spellEngine.processGesture(stableGesture);
        if (matchedSpell != null) {
          if (playerStats.canCast(matchedSpell.manaCost)) {
            final Vector2 spawnPos = landmarks.isNotEmpty
              ? _mapper.mapLandmarkToScreen(landmarks[0])
              : Vector2(size.x / 2, size.y / 2);
            _castSpell(matchedSpell, spawnPos);
          }
        }
      }

      // Gesture callback (from primary hand only)
      if (handId == 0 && onGestureDetected != null) {
        onGestureDetected!(stableGesture);
      }
    }

    _spellEngine.update(dt);
    playerStats.regenerateMana(dt);

    if (onComboChanged != null) {
      onComboChanged!(_spellEngine.currentCombo, _spellEngine.timeoutProgress);
    }

    // --- Wave manager ---
    _waveManager.update(dt);

    // --- Shield timer ---
    if (_shieldTimer > 0) _shieldTimer -= dt;

    // --- Enemy collision check ---
    final enemiesToRemove = <Enemy>[];
    for (final enemy in _enemies) {
      if (enemy.isDead) {
        enemiesToRemove.add(enemy);
        continue;
      }

      if (enemy.reachedPlayer) {
        if (_shieldTimer > 0) {
          AudioManager.playSfx('shield.wav', volume: 0.5);
          enemy.takeDamage(999);
          add(FloatingText(
            position: enemy.position.clone(),
            text: 'BLOCKED!',
            color: Colors.cyanAccent,
            fontSize: 18,
          ));
        } else {
          AudioManager.playSfx('hit.wav', volume: 0.7);
          playerStats.takeDamage(enemy.data.damage);
          _screenShake.trigger(intensity: 15.0);
          _damageFlash.trigger(); // RED FLASH!
          add(FloatingText(
            position: Vector2(size.x / 2, size.y * 0.7),
            text: '-${enemy.data.damage.toInt()} HP',
            color: Palette.impactRed,
            fontSize: 24,
          ));
          
          // Massive blood splat at the bottom of the screen
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

  void _spawnEnemy(EnemyData data) {
    final enemy = Enemy(data: data);
    _enemies.add(enemy);
    add(enemy);
  }

  void _onEnemyDeath(Enemy enemy) {
    _enemies.remove(enemy);
    enemy.removeFromParent();

    // Death pop particles + sound
    AudioManager.playSfx('pop.wav', volume: 0.4);
    add(DeathPop(
      position: enemy.position.clone(),
      primaryColor: enemy.data.primaryColor,
      popScale: enemy.data.kind == EnemyKind.boss ? 2.0 : 1.0,
    ));

    // Major Texel Splatting effect
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

    // Kill streak
    _killStreak++;
    _killStreakTimer = 2.0;

    final points = enemy.data.points * _comboMultiplier;
    playerStats.addScore(points);
    playerStats.addKill();
    playerStats.addXp(10 * _comboMultiplier);

    // Floating score text
    add(FloatingText(
      position: enemy.position.clone(),
      text: '+$points',
      color: Palette.fireGold,
      fontSize: 18,
    ));

    // Combo text
    if (_comboMultiplier > 1) {
      add(FloatingText(
        position: enemy.position.clone() + Vector2(0, -30),
        text: 'x$_comboMultiplier COMBO!',
        color: Palette.fireBright,
        fontSize: 22,
      ));
    }

    // Kill streak announcements!
    _announceKillStreak();

    // Notify wave manager
    _waveManager.onEnemyKilled();
  }

  void _announceKillStreak() {
    String? text;
    Color color = Palette.fireGold;
    double shakeIntensity = 0;

    switch (_killStreak) {
      case 2:
        text = 'DOUBLE KILL!';
        color = Palette.fireBright;
        shakeIntensity = 8;
        break;
      case 3:
        text = 'TRIPLE KILL!';
        color = const Color(0xFFFF8800);
        shakeIntensity = 12;
        break;
      case 5:
        text = 'KILLING SPREE!';
        color = Palette.impactRed;
        shakeIntensity = 16;
        break;
      case 8:
        text = 'UNSTOPPABLE!';
        color = const Color(0xFFFF0044);
        shakeIntensity = 20;
        break;
      case 10:
        text = 'GODLIKE!';
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

  void _castSpell(Spell spell, Vector2 position) {
    debugPrint("CASTING: ${spell.name}");
    _spellCooldown = _spellCooldownDuration; // Start cooldown
    
    switch (spell.type) {
      case SpellType.attack:
        AudioManager.playSfx('fireball.wav', volume: 0.5);
        break;
      case SpellType.defense:
        AudioManager.playSfx('shield.wav', volume: 0.6);
        break;
      case SpellType.heal:
        AudioManager.playSfx('heal.wav', volume: 0.6);
        break;
      case SpellType.ultimate:
        AudioManager.playSfx('explode.wav', volume: 0.8);
        break;
    }

    playerStats.consumeMana(spell.manaCost);
    playerStats.addXp(10);

    add(SpellEffect(
      position: position.clone(),
      effectColor: spell.effectColor,
      spellName: spell.name,
    ));

    _screenShake.trigger(intensity: 8.0 + spell.manaCost * 0.2);

    switch (spell.type) {
      case SpellType.attack:
        final target = _findNearestEnemy();
        add(Projectile(
          startPosition: position,
          spell: spell,
          target: target,
          onHit: (enemy, s) => _onProjectileHit(enemy, s),
        ));
        break;

      case SpellType.defense:
        _shieldTimer = 3.0;
        add(Projectile(startPosition: position, spell: spell));
        add(FloatingText(
          position: position + Vector2(0, -50),
          text: 'SHIELD UP!',
          color: Colors.cyanAccent,
          fontSize: 20,
        ));
        break;

      case SpellType.heal:
        final healAmount = 25.0 + playerStats.level * 5;
        playerStats.heal(healAmount);
        add(Projectile(startPosition: position, spell: spell));
        add(FloatingText(
          position: position + Vector2(0, -50),
          text: '+${healAmount.toInt()} HP',
          color: Colors.greenAccent,
          fontSize: 20,
        ));
        break;

      case SpellType.ultimate:
        add(Projectile(
          startPosition: Vector2(size.x / 2, size.y / 2),
          spell: spell,
        ));
        for (final enemy in List.of(_enemies)) {
          if (!enemy.isDead) {
            enemy.takeDamage(spell.damage);
          }
        }
        add(FloatingText(
          position: Vector2(size.x / 2, size.y * 0.3),
          text: 'METEOR STORM!',
          color: Palette.impactRed,
          fontSize: 30,
        ));
        break;
    }
  }

  void _onProjectileHit(Enemy enemy, Spell spell) {
    if (enemy.data.fireImmune && spell.effectColor == Colors.deepOrange) {
      add(FloatingText(
        position: enemy.position.clone(),
        text: 'IMMUNE!',
        color: Palette.uiGrey,
        fontSize: 16,
      ));
      return;
    }
    enemy.takeDamage(spell.damage);

    // High priority anime impact frame on big hits
    if (spell.type == SpellType.attack || spell.type == SpellType.ultimate) {
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
