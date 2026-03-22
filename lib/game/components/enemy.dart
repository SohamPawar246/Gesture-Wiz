import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'dungeon_background.dart';
import 'death_pop.dart';
import 'artifact_item.dart';
import 'damage_flash.dart';
import '../../models/enemy_type.dart';
import '../palette.dart';
import 'toxic_puddle.dart';
import '../fpv_game.dart';

/// An enemy that spawns deep in the corridor and drifts toward the player.
/// Depth ranges from 0.0 (far, vanishing point) to 1.0 (reached the player).
/// Visual size scales with depth to create the illusion of approach.
class Enemy extends PositionComponent with HasGameReference<FpvGame> {
  final EnemyData data;
  double hp;
  double depth; // 0.0 = far, 1.0 = reached player
  double _flashTimer = 0;
  bool isDead = false;
  bool isGrabbed = false;
  double _time = 0;

  // Special attack states
  double _slimePuddleTimer = 0;

  bool isEyeballCharging = false;
  double _eyeballChargeTimer = 0;
  bool _eyeballFired = false;

  bool isKnightCharging = false;

  double _bossSummonTimer = 0;
  double _bossSlimeTimer = 0;
  bool isBossChargingLaser = false;
  double _bossLaserChargeTimer = 0;

  final double corridorX;
  final double corridorY;

  Enemy({
    required this.data,
    double? startDepth,
    double? corridorX,
    double? corridorY,
  }) : hp = data.maxHp,
       depth = startDepth ?? 0.0,
       corridorX = corridorX ?? (Random().nextDouble() - 0.5) * 0.6,
       corridorY = corridorY ?? (Random().nextDouble() - 0.5) * 0.3;

  bool get reachedPlayer => depth >= 1.0;

  void takeDamage(double amount) {
    // Knight is immune to projectiles from the front while charging, handled by FpvGame
    hp -= amount;
    _flashTimer = 0.18;
    if (hp <= 0) {
      hp = 0;
      isDead = true;
      if (data.kind == EnemyKind.slime && Random().nextDouble() < 0.5) {
        // Slimes have a 50% chance to drop a puddle on death
        game.add(ToxicPuddle(position: position.clone()));
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (isDead) return;

    if (!isGrabbed) {
      // Special Movement & Attack Logic
      if (data.kind == EnemyKind.eyeball && depth >= 0.6 && !_eyeballFired) {
        // Eyeball stops and charges
        isEyeballCharging = true;
        _eyeballChargeTimer += dt;
        if (_eyeballChargeTimer >= 1.5) {
          _eyeballFired = true;
          isEyeballCharging = false;
          // Fire hitscan beam if player not shielded
          if (!game.isShieldActive) {
            game.playerStats.takeDamage(data.damage * 0.8);
            game.triggerScreenShake(8.0);
            game.add(DamageFlash());
          }
        }
      } else if (data.kind == EnemyKind.knight && depth > 0.2 && depth < 0.8) {
        // Knight charges rapidly
        isKnightCharging = true;
        depth += (data.speed * 3.5) * dt; 
      } else if (data.kind == EnemyKind.boss) {
        // Boss Multi-Phase Logic
        final hpPercent = hp / data.maxHp;
        
        if (hpPercent > 0.5) {
          // Phase 1 (100-50% HP): Standard movement, summons Skulls
          depth += data.speed * dt;
          _bossSummonTimer += dt;
          if (_bossSummonTimer >= 5.0) {
            _bossSummonTimer = 0;
            // Summon 2 skulls
            game.spawnEnemyByType(EnemyKind.skull, startDepth: depth - 0.1, corridorX: corridorX - 0.2);
            game.spawnEnemyByType(EnemyKind.skull, startDepth: depth - 0.1, corridorX: corridorX + 0.2);
          }
        } else {
          // Phase 2 (50-0% HP): Stops moving at depth 0.7. Alternates Laser and Slime puddles.
          if (depth < 0.7) {
            depth += data.speed * dt;
          } else {
            // Stopped at 0.7.
            // Laser charge
            if (!isBossChargingLaser) {
              // Wait before charging
              _bossLaserChargeTimer += dt;
              if (_bossLaserChargeTimer >= 3.0) {
                isBossChargingLaser = true;
                _bossLaserChargeTimer = 0;
              }
            } else {
              _bossLaserChargeTimer += dt;
              if (_bossLaserChargeTimer >= 2.0) { // 2s charge
                isBossChargingLaser = false;
                _bossLaserChargeTimer = 0;
                // Fire Laser
                if (!game.isShieldActive) {
                  game.playerStats.takeDamage(data.damage * 1.5); // Very heavy damage
                  game.triggerScreenShake(15.0);
                  game.add(DamageFlash());
                }
              }
            }
            
            // Spew Slime
            _bossSlimeTimer += dt;
            if (_bossSlimeTimer >= 2.5) {
              _bossSlimeTimer = 0;
              game.add(ToxicPuddle(position: position.clone()));
              game.add(ToxicPuddle(position: position.clone() + Vector2(100, 50)));
              game.add(ToxicPuddle(position: position.clone() + Vector2(-100, 50)));
            }
          }
        }
      } else {
        isEyeballCharging = false;
        isKnightCharging = false;
        depth += data.speed * dt;
      }

      // Slime passive puddle dropping
      if (data.kind == EnemyKind.slime && depth > 0.1) {
        _slimePuddleTimer += dt;
        if (_slimePuddleTimer >= 1.5) {
          _slimePuddleTimer = 0;
          if (Random().nextDouble() < 0.3) {
            game.add(ToxicPuddle(position: position.clone()));
          }
        }
      }
    }
    if (_flashTimer > 0) _flashTimer -= dt;

    final w = game.size.x;
    final h = game.size.y;
    if (w <= 0 || h <= 0) return;

    final vpX = w * 0.5;
    final vpY = h * 0.38;
    final t = depth.clamp(0.0, 1.0);
    final screenX = vpX + corridorX * w * t;
    final screenY = vpY + corridorY * h * t + (h * 0.1 * t);
    position = Vector2(screenX, screenY);
  }

  @override
  void render(Canvas canvas) {
    if (isDead) return;

    final t = depth.clamp(0.05, 1.0);
    final baseSize = (data.kind == EnemyKind.boss) ? 54.0 : 32.0;
    final scaledSize = baseSize * t;
    if (scaledSize < 3.0) return;

    final isFlashing = _flashTimer > 0;
    final mainColor = isFlashing ? Colors.white : data.primaryColor;

    if (game.isEmpActive) {
      // Draw as a shadowy silhouette
      canvas.saveLayer(
        Rect.fromCenter(center: Offset.zero, width: scaledSize * 3, height: scaledSize * 3),
        Paint()..colorFilter = const ColorFilter.mode(Color(0xFF030505), BlendMode.srcATop),
      );
    }

    switch (data.kind) {
      case EnemyKind.skull:
        _renderWraithSkull(canvas, scaledSize, mainColor, isFlashing);
        break;
      case EnemyKind.eyeball:
        _renderVoidEye(canvas, scaledSize, mainColor, isFlashing);
        break;
      case EnemyKind.slime:
        _renderAcidBlob(canvas, scaledSize, mainColor, isFlashing);
        break;
      case EnemyKind.knight:
        _renderDreadKnight(canvas, scaledSize, mainColor, isFlashing);
        break;
      case EnemyKind.boss:
        _renderTheLich(canvas, scaledSize, mainColor, isFlashing);
        break;
    }

    if (game.isEmpActive) {
      canvas.restore();
    } else {
      final hpFraction = hp / data.maxHp;
      if (data.kind == EnemyKind.boss || hpFraction < 0.999) {
        _renderHpBar(canvas, scaledSize, hpFraction);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // WRAITH SKULL — spectral floating undead skull with erupting eye flames
  // ══════════════════════════════════════════════════════════════════════
  void _renderWraithSkull(Canvas canvas, double s, Color color, bool flash) {
    final small = s < 14.0;

    // Ghost body / tail below the skull
    if (!flash && !small) {
      for (int i = 0; i < 6; i++) {
        final sw = sin(_time * 1.6 + i * pi / 3) * s * 0.22;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(sw, s * (0.58 + i * 0.28)),
            width: s * (0.88 - i * 0.12).clamp(0.04, 1.0),
            height: s * 0.26,
          ),
          Paint()
            ..color = const Color(0xFF5500AA).withValues(alpha: (0.26 - i * 0.04).clamp(0, 1))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.25),
        );
      }
    }

    // Outer spectral aura
    canvas.drawCircle(
      Offset(0, s * 0.05),
      s * 1.25,
      Paint()
        ..color = const Color(0xFF5500BB).withValues(alpha: 0.18 + 0.07 * sin(_time * 1.9))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 1.0),
    );

    // Wispy smoke tendrils
    if (!flash && !small) {
      for (int i = 0; i < 5; i++) {
        final sw = sin(_time * 2.0 + i * pi * 0.42) * s * 0.2;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(sw, s * (0.46 + i * 0.18)),
            width: s * (0.46 - i * 0.07).clamp(0.04, 0.5),
            height: s * 0.17,
          ),
          Paint()
            ..color = const Color(0x55330066)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.28),
        );
      }
    }

    // Drop shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, s * 0.14), width: s * 1.05, height: s * 0.2),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Inner skull glow pulse
    if (!flash && !small) {
      canvas.drawCircle(
        Offset(0, -s * 0.15),
        s * 0.55,
        Paint()
          ..color = const Color(0xFFFF4400).withValues(alpha: 0.06 + 0.04 * sin(_time * 3.2))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.35),
      );
    }

    // ─── Cranium ───
    final boneColor = flash ? Colors.white : const Color(0xFFDDD8C0);
    final craniumPath = Path()
      ..moveTo(-s * 0.48, s * 0.1)
      ..cubicTo(-s * 0.53, -s * 0.09, -s * 0.5, -s * 0.60, 0, -s * 0.64)
      ..cubicTo(s * 0.5, -s * 0.60, s * 0.53, -s * 0.09, s * 0.48, s * 0.1)
      ..close();
    canvas.drawPath(craniumPath, Paint()..color = boneColor);

    // Bone highlight (lighter patch top center)
    if (!flash && !small) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(s * 0.07, -s * 0.3), width: s * 0.42, height: s * 0.35),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // ─── Cracks with energy ───
    if (!flash) {
      final cg = 0.72 + 0.25 * sin(_time * 3.6);
      final crackGlow = Paint()
        ..color = const Color(0xFFFF6600).withValues(alpha: cg * 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, small ? 2.5 : 4.5)
        ..strokeWidth = small ? 2.0 : 3.5
        ..style = PaintingStyle.stroke;
      final crackCore = Paint()
        ..color = const Color(0xFFFFDD00).withValues(alpha: cg * 0.8)
        ..strokeWidth = small ? 0.8 : 1.5
        ..style = PaintingStyle.stroke;
      final crackDark = Paint()
        ..color = const Color(0xFF110400)
        ..strokeWidth = small ? 0.6 : 1.0
        ..style = PaintingStyle.stroke;

      final c1 = Path()
        ..moveTo(-s * 0.04, -s * 0.60)
        ..lineTo(s * 0.11, -s * 0.34)
        ..lineTo(s * 0.04, -s * 0.14)
        ..lineTo(s * 0.09, -s * 0.02);
      final c2 = Path()
        ..moveTo(s * 0.24, -s * 0.47)
        ..lineTo(s * 0.15, -s * 0.22)
        ..lineTo(s * 0.2, -s * 0.08);
      final c3 = Path()
        ..moveTo(-s * 0.22, -s * 0.4)
        ..lineTo(-s * 0.1, -s * 0.23);

      canvas.drawPath(c1, crackGlow);
      canvas.drawPath(c2, crackGlow..strokeWidth = small ? 1.6 : 2.5);
      canvas.drawPath(c3, crackGlow..strokeWidth = small ? 1.4 : 2.0);
      canvas.drawPath(c1, crackCore);
      canvas.drawPath(c2, crackCore);
      canvas.drawPath(c3, crackCore);
      canvas.drawPath(c1, crackDark);
      canvas.drawPath(c2, crackDark);
      canvas.drawPath(c3, crackDark);

      // Energy motes drifting up along main crack
      if (!small) {
        for (int ep = 0; ep < 5; ep++) {
          final epT = (_time * 2.2 + ep * 0.6) % 2.0;
          final epA = epT < 1.0 ? epT : 2.0 - epT;
          canvas.drawCircle(
            Offset(s * (-0.04 + ep * 0.04), s * (-0.60 + epT * 0.32)),
            s * 0.022,
            Paint()
              ..color = const Color(0xFFFF9900).withValues(alpha: epA * 0.9)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    }

    // Cranium outline
    canvas.drawPath(
      craniumPath,
      Paint()
        ..color = const Color(0xFF443322)
        ..strokeWidth = small ? 1.2 : 1.8
        ..style = PaintingStyle.stroke,
    );

    // ─── Nasal cavity ───
    final nosePath = Path()
      ..moveTo(0, -s * 0.12)
      ..lineTo(-s * 0.09, s * 0.06)
      ..lineTo(s * 0.09, s * 0.06)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = const Color(0xFF080808));
    if (!small) {
      canvas.drawPath(
        nosePath,
        Paint()
          ..color = const Color(0xFF441100)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke,
      );
    }

    // ─── Floating jaw ───
    final jawFloat = sin(_time * 2.8) * s * 0.08;
    final jawY = s * 0.2 + jawFloat;
    final jawPath = Path()
      ..moveTo(-s * 0.38, jawY)
      ..lineTo(-s * 0.38, jawY + s * 0.24)
      ..cubicTo(-s * 0.22, jawY + s * 0.36, s * 0.22, jawY + s * 0.36, s * 0.38, jawY + s * 0.24)
      ..lineTo(s * 0.38, jawY)
      ..cubicTo(s * 0.22, jawY - s * 0.06, -s * 0.22, jawY - s * 0.06, -s * 0.38, jawY)
      ..close();
    canvas.drawPath(jawPath, Paint()..color = boneColor);
    canvas.drawPath(
      jawPath,
      Paint()
        ..color = const Color(0xFF443322)
        ..strokeWidth = small ? 0.8 : 1.2
        ..style = PaintingStyle.stroke,
    );

    // ─── Teeth ───
    if (!flash) {
      final teethPaint = Paint()..color = const Color(0xFFF0ECDC);
      final chippedPaint = Paint()..color = const Color(0xFFCCC8B0);
      final tOut = Paint()
        ..color = const Color(0xFF443322)
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke;

      // Upper teeth (from cranium bottom)
      for (int i = -3; i <= 3; i++) {
        final tx = i * s * 0.09;
        final h2 = s * (i.abs() % 2 == 0 ? 0.19 : 0.13);
        final chipped = (i == -2 || i == 1);
        final tp = Path()
          ..moveTo(tx - s * 0.038, s * 0.1)
          ..lineTo(tx + (chipped ? s * 0.012 : 0), s * 0.1 - h2)
          ..lineTo(tx + s * 0.038, s * 0.1)
          ..close();
        canvas.drawPath(tp, chipped ? chippedPaint : teethPaint);
        if (!small) canvas.drawPath(tp, tOut);
      }
      // Lower teeth (on jaw)
      for (int i = -2; i <= 2; i++) {
        final tx = i * s * 0.1;
        final h2 = s * (i.abs() % 2 == 0 ? 0.14 : 0.09);
        final tp = Path()
          ..moveTo(tx - s * 0.034, jawY)
          ..lineTo(tx, jawY - h2)
          ..lineTo(tx + s * 0.034, jawY)
          ..close();
        canvas.drawPath(tp, teethPaint);
        if (!small) canvas.drawPath(tp, tOut);
      }
    }

    // ─── Eye sockets ───
    for (final ex in [-s * 0.17, s * 0.17]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex, -s * 0.17), width: s * 0.26, height: s * 0.3),
        Paint()..color = const Color(0xFF060606),
      );
    }

    // ─── Erupting eye flames ───
    if (!flash) {
      final lfb = 0.55 + 0.35 * sin(_time * 4.5);
      final rfb = 0.55 + 0.35 * sin(_time * 3.9 + 1.1);
      final int flameLayers = small ? 2 : 4;

      // Left: hellfire orange-to-yellow jets
      for (int fl = 0; fl < flameLayers; fl++) {
        final fw = sin(_time * (4.0 + fl * 0.7) + fl * 1.3) * s * 0.06;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-s * 0.17 + fw, -s * (0.17 + fl * 0.2)),
            width: s * (0.24 - fl * 0.045).clamp(0.04, 0.26),
            height: s * 0.22,
          ),
          Paint()
            ..color = [
              const Color(0xFFFF4400),
              const Color(0xFFFF8800),
              const Color(0xFFFFCC00),
              const Color(0xFFFFFF88),
            ][fl].withValues(alpha: (lfb - fl * 0.1).clamp(0.0, 1.0))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, (4.5 - fl * 0.8).clamp(1.0, 5.0)),
        );
      }
      canvas.drawCircle(
        Offset(-s * 0.17, -s * 0.2),
        s * 0.055,
        Paint()..color = const Color(0xFFFFFFCC).withValues(alpha: 0.95),
      );

      // Right: spectral cyan jets
      for (int fl = 0; fl < flameLayers; fl++) {
        final fw = sin(_time * (3.6 + fl * 0.8) + fl * 1.6) * s * 0.06;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(s * 0.17 + fw, -s * (0.17 + fl * 0.2)),
            width: s * (0.24 - fl * 0.045).clamp(0.04, 0.26),
            height: s * 0.22,
          ),
          Paint()
            ..color = [
              const Color(0xFF00CCFF),
              const Color(0xFF44EEFF),
              const Color(0xFF99FFFF),
              const Color(0xFFDDFFFF),
            ][fl].withValues(alpha: (rfb - fl * 0.1).clamp(0.0, 1.0))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, (4.5 - fl * 0.8).clamp(1.0, 5.0)),
        );
      }
      canvas.drawCircle(
        Offset(s * 0.17, -s * 0.2),
        s * 0.055,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );

      // Skull-top plumes (4 flame columns rising from crown)
      if (!small) {
        for (int i = 0; i < 4; i++) {
          final fi = sin(_time * (5.0 + i * 1.5) + i * 1.2) * s * 0.1;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset((-1.5 + i) * s * 0.22, -s * 0.64 - s * (0.2 + i % 2 * 0.07) - fi),
              width: s * (0.17 - i * 0.02).clamp(0.04, 0.2),
              height: s * 0.32,
            ),
            Paint()
              ..color = [
                const Color(0xFFFF5500),
                const Color(0xFFFF2200),
                const Color(0xFF9900EE),
                const Color(0xFF5500BB),
              ][i].withValues(alpha: 0.5 - i * 0.06)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // VOID EYE — monstrous bloodshot eyeball with eyelids and tentacles
  // ══════════════════════════════════════════════════════════════════════
  void _renderVoidEye(Canvas canvas, double s, Color color, bool flash) {
    final small = s < 14.0;

    // Eldritch outer aura
    canvas.drawCircle(
      Offset.zero,
      s * 1.1,
      Paint()
        ..color = const Color(0xFF880088).withValues(alpha: 0.22 + 0.07 * sin(_time * 2.1))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.95),
    );

    if (flash) {
      canvas.drawCircle(Offset.zero, s * 0.55, Paint()..color = Colors.white);
      return;
    }

    // ─── Tentacles (6 total, beneath sclera) ───
    final int tentacleCount = small ? 4 : 6;
    final tentaclePaint = Paint()
      ..color = const Color(0xFF220033).withValues(alpha: 0.8)
      ..strokeWidth = s * (small ? 0.04 : 0.06)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int t = 0; t < tentacleCount; t++) {
      final tAng = t * (pi * 2 / tentacleCount) + _time * 0.25;
      final tWave = sin(_time * 2.8 + t * 1.1) * 0.3;
      final tLen = s * (0.95 + 0.15 * sin(_time * 1.5 + t));
      final tPath = Path()
        ..moveTo(cos(tAng) * s * 0.42, sin(tAng) * s * 0.42)
        ..quadraticBezierTo(
          cos(tAng + tWave) * s * 0.72,
          sin(tAng + tWave) * s * 0.72,
          cos(tAng + tWave * 1.8) * tLen,
          sin(tAng + tWave * 1.8) * tLen,
        );
      canvas.drawPath(tPath, tentaclePaint);
      // Sucker tip highlight
      if (!small) {
        canvas.drawCircle(
          Offset(cos(tAng + tWave * 1.8) * tLen, sin(tAng + tWave * 1.8) * tLen),
          s * 0.04,
          Paint()..color = const Color(0xFF660066).withValues(alpha: 0.6),
        );
      }
    }

    // ─── Sclera (main eyeball) ───
    final scleraShader = RadialGradient(
      colors: [const Color(0xFFF5F0D8), const Color(0xFFE0CEB0), const Color(0xFFC8A888)],
      stops: const [0.0, 0.65, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 0.52));
    canvas.drawCircle(Offset.zero, s * 0.52, Paint()..shader = scleraShader);

    // ─── Blood veins (8 branching paths) ───
    final veinPaint = Paint()
      ..color = const Color(0xFFCC2222).withValues(alpha: 0.55)
      ..strokeWidth = small ? 0.7 : 1.1
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 8; i++) {
      final ang = i * pi / 4 + _time * 0.1;
      final veinPath = Path()
        ..moveTo(cos(ang) * s * 0.14, sin(ang) * s * 0.14)
        ..quadraticBezierTo(
          cos(ang + 0.15) * s * 0.34,
          sin(ang + 0.15) * s * 0.34,
          cos(ang + 0.02) * s * 0.46,
          sin(ang + 0.02) * s * 0.46,
        );
      canvas.drawPath(veinPath, veinPaint);

      // Sub-branch
      if (!small && i % 2 == 0) {
        final bAng = ang + 0.22;
        canvas.drawLine(
          Offset(cos(bAng) * s * 0.28, sin(bAng) * s * 0.28),
          Offset(cos(bAng) * s * 0.44, sin(bAng) * s * 0.44),
          veinPaint..color = const Color(0xFFCC2222).withValues(alpha: 0.3),
        );
      }
    }

    // ─── Iris with sweep gradient ───
    final irisR = s * 0.26;
    final irisShader = SweepGradient(
      colors: [color, color.withValues(alpha: 0.55), Palette.fireDeep, color],
      transform: GradientRotation(_time * 0.45),
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: irisR));
    canvas.drawCircle(Offset.zero, irisR, Paint()..shader = irisShader);

    // Iris inner ring detail
    if (!small) {
      canvas.drawCircle(
        Offset.zero,
        irisR * 0.82,
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
      // Rune marks rotating around iris
      final runePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke;
      for (int r = 0; r < 6; r++) {
        final ra = r * pi / 3 - _time * 0.8;
        final rx = cos(ra) * s * 0.16;
        final ry = sin(ra) * s * 0.16;
        canvas.drawLine(Offset(rx - s * 0.02, ry), Offset(rx + s * 0.02, ry), runePaint);
        canvas.drawLine(Offset(rx, ry - s * 0.02), Offset(rx, ry + s * 0.02), runePaint);
      }
    }

    canvas.drawCircle(Offset.zero, irisR * 0.65, Paint()..color = color.withValues(alpha: 0.7));

    // ─── Slit pupil ───
    final slitPath = Path()
      ..moveTo(0, -s * 0.14)
      ..cubicTo(-s * 0.03, -s * 0.07, -s * 0.03, s * 0.07, 0, s * 0.14)
      ..cubicTo(s * 0.03, s * 0.07, s * 0.03, -s * 0.07, 0, -s * 0.14)
      ..close();
    canvas.drawPath(slitPath, Paint()..color = const Color(0xFF000000));
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.04, height: s * 0.1),
      Paint()
        ..color = const Color(0x99FF2200)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Specular highlight
    canvas.drawCircle(
      Offset(-s * 0.06, -s * 0.07),
      s * 0.028,
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // ─── Top eyelid (sinister droop) ───
    if (!small) {
      final lidDroop = s * 0.06 + sin(_time * 0.7) * s * 0.04;
      final lidPath = Path()
        ..moveTo(-s * 0.52, -s * 0.04)
        ..cubicTo(-s * 0.28, -s * 0.52 - lidDroop, s * 0.28, -s * 0.52 - lidDroop, s * 0.52, -s * 0.04)
        ..close();
      canvas.drawPath(
        lidPath,
        Paint()
          ..color = const Color(0xFF331122)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      // Eyelid edge line
      canvas.drawPath(
        Path()
          ..moveTo(-s * 0.52, -s * 0.04)
          ..cubicTo(-s * 0.28, -s * 0.52 - lidDroop, s * 0.28, -s * 0.52 - lidDroop, s * 0.52, -s * 0.04),
        Paint()
          ..color = const Color(0xFF551133)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke,
      );
    }

    // ─── 3 Orbiting mini-eyes ───
    for (int me = 0; me < 3; me++) {
      final meAngle = me * pi * 2 / 3 + _time * 0.7;
      final meX = cos(meAngle) * s * 0.78;
      final meY = sin(meAngle) * s * 0.78;
      canvas.drawCircle(
        Offset(meX, meY),
        s * 0.13,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(Offset(meX, meY), s * 0.11, Paint()..color = const Color(0xFFEDE8C4));
      canvas.drawCircle(Offset(meX, meY), s * 0.065, Paint()..color = color);
      canvas.drawCircle(Offset(meX, meY), s * 0.035, Paint()..color = const Color(0xFF000000));
      // Mini specular
      canvas.drawCircle(
        Offset(meX - s * 0.03, meY - s * 0.03),
        s * 0.015,
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
    }

    // Sclera outline
    canvas.drawCircle(
      Offset.zero,
      s * 0.52,
      Paint()
        ..color = const Color(0xFF441111)
        ..strokeWidth = small ? 1.2 : 2.2
        ..style = PaintingStyle.stroke,
    );

    // ─── Fluid drips ───
    for (int d = 0; d < 3; d++) {
      final drop = sin(_time * 1.3 + d * 1.9) * 0.5 + 0.5;
      final dY = s * 0.58 + drop * s * 0.34;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset((-1 + d) * s * 0.18, dY),
          width: s * 0.09,
          height: s * 0.16 * drop,
        ),
        Paint()
          ..color = color.withValues(alpha: 0.65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ACID BLOB — toxic slime with trapped skulls and corrosive drips
  // ══════════════════════════════════════════════════════════════════════
  void _renderAcidBlob(Canvas canvas, double s, Color color, bool flash) {
    final small = s < 14.0;

    // Corrosive ground puddle
    if (!flash && !small) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, s * 0.7), width: s * 1.3, height: s * 0.22),
        Paint()
          ..color = const Color(0xFF66CC00).withValues(alpha: 0.18 + 0.06 * sin(_time * 2.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.3),
      );
    }

    // Toxic aura
    canvas.drawCircle(
      Offset(0, s * 0.05),
      s * 0.88,
      Paint()
        ..color = const Color(0xFF00FF44).withValues(alpha: 0.1 + 0.04 * sin(_time * 2.8))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.72),
    );

    // ─── Acid drips ───
    if (!flash) {
      for (int d = 0; d < 5; d++) {
        final drip = sin(_time * 1.1 + d * 1.7) * 0.5 + 0.5;
        final dY = s * 0.5 + drip * s * 0.44;
        final dX = (-2 + d) * s * 0.16;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(dX, dY),
            width: s * 0.09,
            height: s * 0.2 * drip,
          ),
          Paint()
            ..color = color.withValues(alpha: 0.72)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
        // Drip tip teardrop
        if (!small && drip > 0.5) {
          canvas.drawCircle(
            Offset(dX, dY + s * 0.1 * drip),
            s * 0.045,
            Paint()..color = color.withValues(alpha: 0.5),
          );
        }
      }
    }

    // ─── Outer blob body ───
    final wobX = sin(_time * 2.9) * s * 0.045;
    final wobY = cos(_time * 5.2) * s * 0.032;
    final wobX2 = cos(_time * 3.7) * s * 0.03;
    final blobPath = Path()
      ..moveTo(0, -s * 0.52 + wobX)
      ..cubicTo(
        s * 0.38 + wobY,
        -s * 0.56,
        s * 0.58 + wobX,
        -s * 0.18,
        s * 0.52,
        s * 0.14 + wobY,
      )
      ..cubicTo(s * 0.46, s * 0.52, -s * 0.46, s * 0.52, -s * 0.52, s * 0.14 + wobX)
      ..cubicTo(
        -s * 0.58 + wobX2,
        -s * 0.18,
        -s * 0.38,
        -s * 0.56 + wobY,
        0,
        -s * 0.52 + wobX,
      )
      ..close();

    canvas.drawPath(
      blobPath,
      Paint()..color = flash ? Colors.white : color.withValues(alpha: 0.75),
    );

    if (!flash) {
      // Inner acid radial glow
      final coreShader = RadialGradient(
        colors: [
          const Color(0xFFDDFF00).withValues(alpha: 0.95),
          color.withValues(alpha: 0.62),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(0, wobX), radius: s * 0.34));
      canvas.drawCircle(Offset(0, wobX), s * 0.34, Paint()..shader = coreShader);

      // Toxic gas wisps rising from top
      if (!small) {
        for (int g = 0; g < 4; g++) {
          final gt = (_time * 1.4 + g * 0.8) % 2.5;
          final gA = (gt < 1.0 ? gt : (2.5 - gt) / 1.5).clamp(0.0, 1.0);
          final gX = (-1.5 + g) * s * 0.2 + sin(_time * 2.5 + g) * s * 0.08;
          canvas.drawCircle(
            Offset(gX, -s * 0.52 - gt * s * 0.35),
            s * (0.08 + gt * 0.04),
            Paint()
              ..color = const Color(0xFF88FF44).withValues(alpha: gA * 0.38)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }
      }

      // ─── Trapped skulls (2 visible inside) ───
      final sk1 = const Color(0xFF3A5A3A).withValues(alpha: 0.52);
      final sk2 = const Color(0xFF284428).withValues(alpha: 0.42);
      // Skull 1
      canvas.drawCircle(Offset(s * 0.06, wobX - s * 0.04), s * 0.16, Paint()..color = sk1);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-s * 0.04 + s * 0.06, wobX - s * 0.08),
          width: s * 0.07,
          height: s * 0.09,
        ),
        Paint()..color = const Color(0xFF001800).withValues(alpha: 0.6),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * 0.1, wobX - s * 0.08),
          width: s * 0.07,
          height: s * 0.09,
        ),
        Paint()..color = const Color(0xFF001800).withValues(alpha: 0.6),
      );
      // Skull 2 (smaller, offset)
      if (!small) {
        canvas.drawCircle(Offset(-s * 0.18, wobX + s * 0.08), s * 0.1, Paint()..color = sk2);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(-s * 0.22, wobX + s * 0.04), width: s * 0.05, height: s * 0.06),
          Paint()..color = const Color(0xFF001800).withValues(alpha: 0.5),
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(-s * 0.14, wobX + s * 0.04), width: s * 0.05, height: s * 0.06),
          Paint()..color = const Color(0xFF001800).withValues(alpha: 0.5),
        );
      }

      // ─── Surface bubbles ───
      final int bubCount = small ? 5 : 9;
      for (int b = 0; b < bubCount; b++) {
        final bAng = b * pi * 2 / bubCount + _time * 0.5;
        final bDist = s * (0.36 + 0.04 * sin(_time * 3.0 + b));
        final bSize = s * (0.04 + 0.022 * sin(_time * 4.5 + b));
        final bAlpha = 0.3 + 0.15 * sin(_time * 2.2 + b);
        canvas.drawCircle(
          Offset(cos(bAng) * bDist, sin(bAng) * bDist),
          bSize,
          Paint()..color = const Color(0xFF99FF88).withValues(alpha: bAlpha),
        );
        // Bubble highlight
        canvas.drawCircle(
          Offset(cos(bAng) * bDist - bSize * 0.35, sin(bAng) * bDist - bSize * 0.35),
          bSize * 0.28,
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        );
      }

      // Corruption arc overlays
      for (int a = 0; a < 3; a++) {
        final arcAng = _time * 2.0 + a * pi * 2 / 3;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: s * (0.38 + a * 0.1)),
          arcAng,
          pi * 0.7,
          false,
          Paint()
            ..color = const Color(0xFFAAFF00).withValues(alpha: 0.3)
            ..strokeWidth = 1.6
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    // Blob outline
    if (!flash) {
      canvas.drawPath(
        blobPath,
        Paint()
          ..color = const Color(0xFF228822)
          ..strokeWidth = small ? 1.0 : 1.8
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DREAD KNIGHT — undead armored warrior with dark greatsword
  // ══════════════════════════════════════════════════════════════════════
  void _renderDreadKnight(Canvas canvas, double s, Color color, bool flash) {
    final small = s < 14.0;

    // Dark aura
    canvas.drawCircle(
      Offset(0, s * 0.1),
      s * 0.85,
      Paint()
        ..color = const Color(0xFF221133).withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.65),
    );

    // Ground mist
    if (!flash && !small) {
      for (int f = 0; f < 4; f++) {
        final fx = (-1.5 + f) * s * 0.22;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(fx, s * 0.7), width: s * (0.28 + f * 0.04), height: s * 0.1),
          Paint()
            ..color = const Color(0x44551155)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }
    }

    // ─── Dark greatsword (left side) ───
    if (!flash) {
      final swordSway = sin(_time * 1.4) * s * 0.04;
      // Blade
      final bladePath = Path()
        ..moveTo(-s * 0.58 + swordSway, -s * 0.82)
        ..lineTo(-s * 0.52 + swordSway, -s * 0.96)
        ..lineTo(-s * 0.44 + swordSway, -s * 0.82)
        ..lineTo(-s * 0.48 + swordSway, s * 0.32)
        ..lineTo(-s * 0.56 + swordSway, s * 0.32)
        ..close();
      // Blade glow
      canvas.drawPath(
        bladePath,
        Paint()
          ..color = const Color(0xFF330066).withValues(alpha: 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, small ? 3 : 6),
      );
      canvas.drawPath(bladePath, Paint()..color = small ? const Color(0xFF5A4A7A) : const Color(0xFF443355));
      // Blade edge highlight
      canvas.drawLine(
        Offset(-s * 0.52 + swordSway, -s * 0.96),
        Offset(-s * 0.5 + swordSway, s * 0.32),
        Paint()
          ..color = const Color(0xFF8866AA).withValues(alpha: 0.7)
          ..strokeWidth = small ? 0.6 : 1.0,
      );
      // Energy rune on blade
      if (!small) {
        final rg = 0.5 + 0.4 * sin(_time * 3.0);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-s * 0.5 + swordSway, -s * 0.28),
            width: s * 0.08,
            height: s * 0.16,
          ),
          Paint()
            ..color = const Color(0xFFAA44FF).withValues(alpha: rg * 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
      // Guard/crossguard
      final guardPath = Path()
        ..moveTo(-s * 0.72 + swordSway, s * 0.32)
        ..lineTo(-s * 0.3 + swordSway, s * 0.32)
        ..lineTo(-s * 0.3 + swordSway, s * 0.42)
        ..lineTo(-s * 0.72 + swordSway, s * 0.42)
        ..close();
      canvas.drawPath(guardPath, Paint()..color = const Color(0xFF3A3050));
      canvas.drawPath(
        guardPath,
        Paint()
          ..color = const Color(0xFF6A5A88)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke,
      );
    }

    // ─── Torn cape (5 strips) ───
    if (!flash) {
      for (int strip = 0; strip < 5; strip++) {
        final sf = strip / 4.0;
        final cw = sin(_time * 2.2 + strip * 0.45) * s * (0.08 + sf * 0.06);
        final ca = (0.88 - sf * 0.36).clamp(0.0, 1.0);
        final capePath = Path()
          ..moveTo(-s * 0.28, -s * 0.12)
          ..cubicTo(
            -s * 0.34 + sf * s * 0.1,
            s * 0.28 + cw,
            -s * 0.22 + sf * s * 0.14,
            s * 0.56 + cw * 1.3,
            -s * 0.12 + sf * s * 0.2,
            s * 0.78 + cw,
          )
          ..lineTo(-s * 0.06 + sf * s * 0.26, s * 0.78 + cw)
          ..cubicTo(
            -s * 0.18 + sf * s * 0.2,
            s * 0.5 + cw * 1.1,
            -s * 0.28 + sf * s * 0.14,
            s * 0.26 + cw,
            -s * 0.23,
            -s * 0.1,
          )
          ..close();
        canvas.drawPath(capePath, Paint()..color = const Color(0xFF180828).withValues(alpha: ca));
      }
    }

    final armorColor = flash ? Colors.white : color;

    // ─── Legs ───
    for (int leg = -1; leg <= 1; leg += 2) {
      final legX = leg * s * 0.15;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(legX, s * 0.44), width: s * 0.22, height: s * 0.52),
          Radius.circular(s * 0.025),
        ),
        Paint()..color = armorColor,
      );
      // Leg groove
      if (!flash && !small) {
        canvas.drawLine(
          Offset(legX, s * 0.18),
          Offset(legX, s * 0.7),
          Paint()
            ..color = const Color(0xFF1A1A2A).withValues(alpha: 0.7)
            ..strokeWidth = 1.0,
        );
      }
      // Knee cap
      canvas.drawOval(
        Rect.fromCenter(center: Offset(legX, s * 0.23), width: s * 0.24, height: s * 0.14),
        Paint()..color = const Color(0xFF5A5A7A),
      );
    }

    // ─── Torso / chest plate ───
    final torsoRect = Rect.fromCenter(center: Offset(0, s * 0.04), width: s * 0.66, height: s * 0.48);
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(s * 0.04)),
      Paint()..color = armorColor,
    );
    // Battle damage scratches on torso
    if (!flash && !small) {
      final scratchPaint = Paint()
        ..color = const Color(0xFF1A1A2A).withValues(alpha: 0.8)
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(-s * 0.18, -s * 0.12), Offset(-s * 0.08, s * 0.08), scratchPaint);
      canvas.drawLine(Offset(-s * 0.14, -s * 0.08), Offset(-s * 0.06, s * 0.06), scratchPaint);
      // Red glow from damage cracks
      canvas.drawLine(
        Offset(-s * 0.18, -s * 0.12),
        Offset(-s * 0.08, s * 0.08),
        Paint()
          ..color = const Color(0xFFFF2200).withValues(alpha: 0.3)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(s * 0.04)),
      Paint()
        ..color = const Color(0xFF1A1A2A)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // ─── Chest rune (larger, more elaborate) ───
    if (!flash) {
      final rg = 0.55 + 0.35 * sin(_time * 2.2);
      canvas.drawCircle(
        Offset(0, s * 0.03),
        s * 0.14,
        Paint()
          ..color = const Color(0xFFFF5500).withValues(alpha: rg * 0.65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      final rl = Paint()
        ..color = const Color(0xFFFF7700).withValues(alpha: rg * 0.9)
        ..strokeWidth = small ? 0.8 : 1.4
        ..style = PaintingStyle.stroke;
      // Rune pattern (hexagram-like)
      for (int r = 0; r < 3; r++) {
        final ra = r * pi / 3;
        canvas.drawLine(
          Offset(cos(ra) * s * 0.11, sin(ra) * s * 0.11 + s * 0.03),
          Offset(cos(ra + pi) * s * 0.11, sin(ra + pi) * s * 0.11 + s * 0.03),
          rl,
        );
      }
    }

    // ─── Shoulder pauldrons with spikes ───
    for (int side = -1; side <= 1; side += 2) {
      final px = side * s * 0.4;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(px, -s * 0.14), width: s * 0.32, height: s * 0.24),
        Paint()..color = const Color(0xFF555577),
      );
      // Main spike
      canvas.drawPath(
        Path()
          ..moveTo(px, -s * 0.24)
          ..lineTo(px - side * s * 0.06, -s * 0.48)
          ..lineTo(px + side * s * 0.06, -s * 0.24)
          ..close(),
        Paint()..color = const Color(0xFF443366),
      );
      // Second smaller spike
      if (!small) {
        canvas.drawPath(
          Path()
            ..moveTo(px + side * s * 0.08, -s * 0.18)
            ..lineTo(px + side * s * 0.15, -s * 0.34)
            ..lineTo(px + side * s * 0.2, -s * 0.18)
            ..close(),
          Paint()..color = const Color(0xFF3A2855),
        );
      }
    }

    // ─── Helmet ───
    final helmetPath = Path()
      ..moveTo(-s * 0.29, -s * 0.28)
      ..lineTo(-s * 0.29, -s * 0.62)
      ..cubicTo(-s * 0.29, -s * 0.86, s * 0.29, -s * 0.86, s * 0.29, -s * 0.62)
      ..lineTo(s * 0.29, -s * 0.28)
      ..close();
    canvas.drawPath(helmetPath, Paint()..color = flash ? Colors.white : const Color(0xFF4A4A6A));
    canvas.drawPath(
      helmetPath,
      Paint()
        ..color = const Color(0xFF1A1A2A)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    if (!flash) {
      // ─── Demonic horns (curved, more imposing) ───
      for (int side = -1; side <= 1; side += 2) {
        // Main horn
        canvas.drawPath(
          Path()
            ..moveTo(side * s * 0.26, -s * 0.66)
            ..cubicTo(
              side * s * 0.55,
              -s * 0.96,
              side * s * 0.46,
              -s * 1.18,
              side * s * 0.24,
              -s * 0.9,
            )
            ..lineTo(side * s * 0.26, -s * 0.66)
            ..close(),
          Paint()..color = const Color(0xFF221133),
        );
        // Horn ridge
        if (!small) {
          canvas.drawLine(
            Offset(side * s * 0.26, -s * 0.66),
            Offset(side * s * 0.36, -s * 1.0),
            Paint()
              ..color = const Color(0xFF4A3060).withValues(alpha: 0.7)
              ..strokeWidth = 1.0,
          );
        }
      }

      // ─── Visor slit eyes ───
      final vg = 0.72 + 0.28 * sin(_time * 3.2);
      for (int e = -1; e <= 1; e += 2) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(e * s * 0.1, -s * 0.5),
            width: s * 0.14,
            height: s * 0.06,
          ),
          Paint()
            ..color = const Color(0xFFFF2200).withValues(alpha: vg)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, small ? 2 : 3.5),
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(e * s * 0.1, -s * 0.5), width: s * 0.09, height: s * 0.032),
          Paint()..color = const Color(0xFFFFEE00).withValues(alpha: 0.88),
        );
      }

      // ─── Dark fire/smoke from back of helmet ───
      if (!small) {
        for (int hf = 0; hf < 3; hf++) {
          final hfw = sin(_time * 3.5 + hf * 1.1) * s * 0.06;
          canvas.drawCircle(
            Offset((-1 + hf) * s * 0.15 + hfw, -s * (0.86 + hf * 0.14)),
            s * (0.1 - hf * 0.02),
            Paint()
              ..color = const Color(0xFF440066).withValues(alpha: 0.4 - hf * 0.1)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }
      }

      // Armor center vertical ridge on helmet
      canvas.drawLine(
        Offset(0, -s * 0.28),
        Offset(0, -s * 0.72),
        Paint()
          ..color = const Color(0xFF6A6A8A)
          ..strokeWidth = small ? 0.8 : 1.5,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // THE LICH (BOSS) — colossal undead sorcerer with scythe and skulls
  // ══════════════════════════════════════════════════════════════════════
  void _renderTheLich(Canvas canvas, double s, Color color, bool flash) {
    final outerPulse = 0.7 + 0.3 * sin(_time * 1.4);
    final small = s < 20.0;

    // ─── Massive outer void halo ───
    canvas.drawCircle(
      Offset.zero,
      s * 2.1,
      Paint()
        ..color = Palette.fireDeep.withValues(alpha: 0.08 * outerPulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 1.5),
    );
    canvas.drawCircle(
      Offset.zero,
      s * 1.3,
      Paint()
        ..color = const Color(0xFF110022).withValues(alpha: 0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.5),
    );

    // ─── Dark fire pool on ground ───
    if (!flash && !small) {
      for (int gf = 0; gf < 5; gf++) {
        final gfw = sin(_time * 2.0 + gf * 0.8) * s * 0.18;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(gfw, s * (1.8 + gf * 0.12)),
            width: s * (1.8 - gf * 0.22),
            height: s * 0.14,
          ),
          Paint()
            ..color = const Color(0xFF440066).withValues(alpha: (0.22 - gf * 0.04).clamp(0, 1))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.18),
        );
      }
    }

    if (!flash) {
      // ─── Billowing cloak (5 layers) ───
      for (int layer = 0; layer < 5; layer++) {
        final lf = layer / 4.0;
        final cw = sin(_time * 1.8 + layer * 0.7) * s * (0.1 + lf * 0.08);
        final ca = (0.88 - lf * 0.3).clamp(0.0, 1.0);
        final cloakPath = Path()
          ..moveTo(-s * (0.38 - lf * 0.08), s * 0.22)
          ..cubicTo(
            -s * (0.56 + lf * 0.15),
            s * 0.65 + cw,
            -s * (0.4 + lf * 0.2),
            s * 1.38 + cw * 1.4,
            -s * (0.1 + lf * 0.18),
            s * 1.9 + cw,
          )
          ..lineTo(s * (0.1 + lf * 0.18), s * 1.9 + cw)
          ..cubicTo(
            s * (0.4 + lf * 0.2),
            s * 1.38 + cw * 1.4,
            s * (0.56 + lf * 0.15),
            s * 0.65 + cw,
            s * (0.38 - lf * 0.08),
            s * 0.22,
          )
          ..close();
        canvas.drawPath(
          cloakPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A0A2A).withValues(alpha: ca),
                const Color(0xFF0A0010).withValues(alpha: ca * 0.5),
              ],
            ).createShader(
              Rect.fromCenter(center: Offset(0, s), width: s * 2.5, height: s * 2.2),
            ),
        );
        // Cloak rune pattern (first two layers)
        if (!small && layer < 2) {
          final rp = 0.3 + 0.2 * sin(_time * 1.5 + layer * pi);
          for (int ri = 0; ri < 3; ri++) {
            canvas.drawCircle(
              Offset((-1 + ri) * s * 0.2, s * (0.8 + layer * 0.5 + ri * 0.2)),
              s * 0.045,
              Paint()
                ..color = const Color(0xFFAA44FF).withValues(alpha: rp)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
            );
          }
        }
      }

      // ─── Soul wisps escaping from cloak hem ───
      if (!small) {
        for (int w = 0; w < 4; w++) {
          final wt = (_time * 1.6 + w * 0.9) % 2.8;
          final wA = (wt < 1.0 ? wt : (2.8 - wt) / 1.8).clamp(0.0, 1.0);
          final wX = (-1.5 + w) * s * 0.4 + sin(_time * 2.0 + w) * s * 0.15;
          canvas.drawCircle(
            Offset(wX, s * (1.85 - wt * 0.8)),
            s * (0.07 + wt * 0.03),
            Paint()
              ..color = const Color(0xFF88CCFF).withValues(alpha: wA * 0.55)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
        }
      }

      // ─── Spectral scythe (right side) ───
      final sScythe = s * 0.95;
      final scytheBase = Offset(s * 0.62, -s * 0.2);
      // Scythe staff
      canvas.drawLine(
        scytheBase,
        Offset(s * 0.68, s * 1.6),
        Paint()
          ..color = const Color(0xFF2A1A3A)
          ..strokeWidth = s * 0.06
          ..strokeCap = StrokeCap.round,
      );
      // Scythe blade
      final bladePath = Path()
        ..moveTo(s * 0.64, -s * 0.24)
        ..cubicTo(
          s * 1.45,
          -s * 0.85,
          s * 1.6,
          -s * 0.38,
          s * 0.96,
          -s * 0.06,
        );
      canvas.drawPath(
        bladePath,
        Paint()
          ..color = const Color(0xFF220033).withValues(alpha: 0.5)
          ..strokeWidth = sScythe * 0.22
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, small ? 4 : 8),
      );
      canvas.drawPath(
        bladePath,
        Paint()
          ..color = const Color(0xFF6633AA)
          ..strokeWidth = sScythe * 0.07
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      // Blade glowing edge
      canvas.drawPath(
        bladePath,
        Paint()
          ..color = const Color(0xFFCC88FF).withValues(alpha: 0.7 + 0.2 * sin(_time * 2.5))
          ..strokeWidth = sScythe * 0.02
          ..style = PaintingStyle.stroke,
      );

      // ─── 3 Orbiting fire orbs ───
      for (int orb = 0; orb < 3; orb++) {
        final orbAng = _time * 1.3 + orb * pi * 2 / 3;
        final orbX = cos(orbAng) * s * 1.0;
        final orbY = sin(orbAng) * s * 0.55;
        canvas.drawCircle(
          Offset(orbX, orbY),
          s * 0.22,
          Paint()
            ..color = Palette.fireDeep.withValues(alpha: 0.5)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.16),
        );
        canvas.drawCircle(Offset(orbX, orbY), s * 0.13, Paint()..color = Palette.fireGold);
        canvas.drawCircle(Offset(orbX, orbY), s * 0.07, Paint()..color = Palette.fireWhite);
        // Orb trail
        for (int tr = 1; tr <= 6; tr++) {
          final trAng = orbAng - tr * 0.14;
          final trA = (0.42 - tr * 0.06).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(cos(trAng) * s * 1.0, sin(trAng) * s * 0.55),
            s * (0.07 - tr * 0.008).clamp(0.01, 0.1),
            Paint()
              ..color = Palette.fireMid.withValues(alpha: trA)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }

      // ─── Orbiting skulls (3 smaller, faster) ───
      if (!small) {
        for (int sk = 0; sk < 3; sk++) {
          final skAng = _time * 0.9 + sk * pi * 2 / 3 + pi / 3;
          final skX = cos(skAng) * s * 1.35;
          final skY = sin(skAng) * s * 0.65;
          canvas.drawCircle(
            Offset(skX, skY),
            s * 0.18,
            Paint()..color = const Color(0xFFD8D0A8),
          );
          canvas.drawOval(
            Rect.fromCenter(center: Offset(skX - s * 0.06, skY - s * 0.04), width: s * 0.08, height: s * 0.1),
            Paint()..color = const Color(0xFF111111),
          );
          canvas.drawOval(
            Rect.fromCenter(center: Offset(skX + s * 0.06, skY - s * 0.04), width: s * 0.08, height: s * 0.1),
            Paint()..color = const Color(0xFF111111),
          );
          canvas.drawCircle(
            Offset(skX, skY),
            s * 0.19,
            Paint()
              ..color = const Color(0xFF664400).withValues(alpha: 0.3)
              ..strokeWidth = 1.0
              ..style = PaintingStyle.stroke,
          );
        }
      }

      // ─── Energy rings ───
      for (int ring = 0; ring < 3; ring++) {
        final ringR = s * (0.62 + ring * 0.16);
        final rp = 0.5 + 0.5 * sin(_time * (2.2 + ring * 0.5) + ring);
        canvas.drawCircle(
          Offset.zero,
          ringR,
          Paint()
            ..color = Palette.fireDeep.withValues(alpha: 0.07 * rp)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.045,
        );
      }
    }

    // ─── Skull shadow ───
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, s * 0.22), width: s * 1.4, height: s * 0.28),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // ─── Skull cranium ───
    final boneColor = flash ? Colors.white : const Color(0xFFE0DBB8);
    final skullPath = Path()
      ..moveTo(-s * 0.6, s * 0.2)
      ..cubicTo(-s * 0.66, -s * 0.08, -s * 0.62, -s * 0.74, 0, -s * 0.8)
      ..cubicTo(s * 0.62, -s * 0.74, s * 0.66, -s * 0.08, s * 0.6, s * 0.2)
      ..close();
    canvas.drawPath(skullPath, Paint()..color = boneColor);

    // Cranium bone highlight (top)
    if (!flash && !small) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(s * 0.1, -s * 0.38), width: s * 0.55, height: s * 0.48),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // ─── Skull cracks ───
    if (!flash) {
      final cglow = 0.65 + 0.3 * sin(_time * 2.5);
      final crackG = Paint()
        ..color = Palette.fireDeep.withValues(alpha: cglow * 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, small ? 3 : 5.5)
        ..strokeWidth = small ? 2.5 : 4.0
        ..style = PaintingStyle.stroke;
      final crackD = Paint()
        ..color = const Color(0xFF220000)
        ..strokeWidth = small ? 1.2 : 2.0
        ..style = PaintingStyle.stroke;
      final cr1 = Path()
        ..moveTo(0, -s * 0.76)
        ..lineTo(-s * 0.12, -s * 0.52)
        ..lineTo(s * 0.08, -s * 0.3)
        ..lineTo(-s * 0.05, -s * 0.1);
      final cr2 = Path()
        ..moveTo(s * 0.28, -s * 0.6)
        ..lineTo(s * 0.18, -s * 0.38)
        ..lineTo(s * 0.24, -s * 0.2);
      final cr3 = Path()
        ..moveTo(-s * 0.3, -s * 0.52)
        ..lineTo(-s * 0.18, -s * 0.28);
      canvas.drawPath(cr1, crackG);
      canvas.drawPath(cr2, crackG..strokeWidth = small ? 2.0 : 3.0);
      canvas.drawPath(cr3, crackG..strokeWidth = small ? 1.8 : 2.5);
      canvas.drawPath(cr1, crackD);
      canvas.drawPath(cr2, crackD);
      canvas.drawPath(cr3, crackD);

      // Fire seeping from cracks
      if (!small) {
        for (int ec = 0; ec < 5; ec++) {
          final ect = (_time * 2.0 + ec * 0.55) % 2.2;
          final ecA = (ect < 1.0 ? ect : (2.2 - ect) / 1.2).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(s * (-0.04 + ec * 0.04), s * (-0.76 + ect * 0.36)),
            s * 0.028,
            Paint()
              ..color = Palette.fireMid.withValues(alpha: ecA * 0.9)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    }

    // Skull glow outline
    canvas.drawPath(
      skullPath,
      Paint()
        ..color = Palette.fireGold.withValues(alpha: 0.22 + 0.16 * sin(_time * 2.0))
        ..strokeWidth = small ? 1.8 : 3.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );
    canvas.drawPath(
      skullPath,
      Paint()
        ..color = const Color(0xFF332211)
        ..strokeWidth = small ? 1.0 : 1.8
        ..style = PaintingStyle.stroke,
    );

    // ─── Eye sockets ───
    final eyeL = Offset(-s * 0.24, -s * 0.27);
    final eyeR = Offset(s * 0.24, -s * 0.27);
    for (final eye in [eyeL, eyeR]) {
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: s * 0.32, height: s * 0.38),
        Paint()..color = const Color(0xFF080808),
      );
    }

    // ─── Eye flames (multi-layer eruptions) ───
    if (!flash) {
      final int eyeLayers = small ? 2 : 3;
      // Left: hellfire orange
      for (int l = 0; l < eyeLayers; l++) {
        final lf = l / (eyeLayers - 1.0);
        canvas.drawOval(
          Rect.fromCenter(
            center: eyeL.translate(sin(_time * 4.5 + l) * s * 0.04, -s * 0.06 * l),
            width: s * 0.32 * (1 - lf * 0.38),
            height: s * (0.38 + l * 0.22) * (1 - lf * 0.35),
          ),
          Paint()
            ..color = [Palette.fireDeep, Palette.fireMid, Palette.fireGold][l]
                .withValues(alpha: 0.55 + 0.3 * sin(_time * 4.2 + l))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, (4.5 - l * 1.2).clamp(1.0, 5.0)),
        );
      }
      // Right: spectral purple
      for (int l = 0; l < eyeLayers; l++) {
        final lf = l / (eyeLayers - 1.0);
        canvas.drawOval(
          Rect.fromCenter(
            center: eyeR.translate(sin(_time * 3.8 + l) * s * 0.04, -s * 0.06 * l),
            width: s * 0.32 * (1 - lf * 0.38),
            height: s * (0.38 + l * 0.22) * (1 - lf * 0.35),
          ),
          Paint()
            ..color = [
              const Color(0xFF7700AA),
              const Color(0xFF9922CC),
              const Color(0xFFCCAAFF),
            ][l].withValues(alpha: 0.55 + 0.3 * sin(_time * 3.5 + l + 1.1))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, (4.5 - l * 1.2).clamp(1.0, 5.0)),
        );
      }
    }

    // ─── Nasal cavity ───
    final nosePath = Path()
      ..moveTo(0, -s * 0.12)
      ..lineTo(-s * 0.11, s * 0.07)
      ..lineTo(s * 0.11, s * 0.07)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = const Color(0xFF080808));

    // ─── Floating jaw ───
    final jawDrop = s * 0.1 + sin(_time * 1.8) * s * 0.1;
    final jawY = s * 0.22 + jawDrop;
    final jawPath = Path()
      ..moveTo(-s * 0.54, jawY)
      ..lineTo(-s * 0.54, jawY + s * 0.3)
      ..cubicTo(-s * 0.32, jawY + s * 0.42, s * 0.32, jawY + s * 0.42, s * 0.54, jawY + s * 0.3)
      ..lineTo(s * 0.54, jawY)
      ..close();
    canvas.drawPath(jawPath, Paint()..color = boneColor);
    canvas.drawPath(
      jawPath,
      Paint()
        ..color = const Color(0xFF332211)
        ..strokeWidth = small ? 1.0 : 1.8
        ..style = PaintingStyle.stroke,
    );

    // ─── Boss teeth ───
    if (!flash) {
      final teethB = Paint()..color = const Color(0xFFEEEAD2);
      final tglow = Paint()
        ..color = Palette.fireGold.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      for (int t = -4; t <= 4; t++) {
        final tx = t * s * 0.1;
        final th = s * (t.abs() % 2 == 0 ? 0.26 : 0.18);
        final tp = Path()
          ..moveTo(tx - s * 0.042, jawY)
          ..lineTo(tx, jawY - th)
          ..lineTo(tx + s * 0.042, jawY)
          ..close();
        canvas.drawPath(tp, teethB);
        canvas.drawPath(tp, tglow);
      }
    }

    // ─── Crown (5 spikes + gems) ───
    if (!flash) {
      // Base band with gradient
      canvas.drawRect(
        Rect.fromCenter(center: Offset(0, -s * 0.76), width: s * 1.18, height: s * 0.18),
        Paint()
          ..shader = LinearGradient(
            colors: [Palette.fireGold, const Color(0xFFAA8800), Palette.fireGold],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromLTWH(-s * 0.59, -s * 0.76, s * 1.18, s * 0.18)),
      );
      // Crown engraving line
      canvas.drawLine(
        Offset(-s * 0.59, -s * 0.74),
        Offset(s * 0.59, -s * 0.74),
        Paint()
          ..color = const Color(0xFF664400).withValues(alpha: 0.6)
          ..strokeWidth = 0.8,
      );
      // 5 spikes
      for (int sp = 0; sp < 5; sp++) {
        final sx = (-2 + sp) * s * 0.23;
        final isCenterSpike = sp == 2;
        final sph = isCenterSpike ? s * 0.52 : s * 0.34;
        final spPath = Path()
          ..moveTo(sx - s * 0.1, -s * 0.76)
          ..lineTo(sx, -s * 0.76 - sph)
          ..lineTo(sx + s * 0.1, -s * 0.76)
          ..close();
        canvas.drawPath(
          spPath,
          Paint()
            ..color = Palette.fireGold.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawPath(spPath, Paint()..color = Palette.fireGold);
        canvas.drawPath(
          spPath,
          Paint()
            ..color = const Color(0xFF664400)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
        // Gem at spike tip
        final gemColor = const [
          Color(0xFFFF2200),
          Color(0xFF0088FF),
          Color(0xFFFFFF00),
          Color(0xFF00FF44),
          Color(0xFFAA00FF),
        ][sp];
        final gg = 0.65 + 0.35 * sin(_time * (3.0 + sp) + sp);
        canvas.drawCircle(
          Offset(sx, -s * 0.76 - sph + s * 0.07),
          s * 0.07,
          Paint()
            ..color = gemColor.withValues(alpha: gg)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(Offset(sx, -s * 0.76 - sph + s * 0.07), s * 0.045, Paint()..color = gemColor);
      }

      // ─── Shoulder mini-skulls ───
      for (int side = -1; side <= 1; side += 2) {
        final msx = side * s * 0.82;
        final msy = -s * 0.1;
        canvas.drawCircle(Offset(msx, msy), s * 0.21, Paint()..color = const Color(0xFFD0CCA8));
        for (final ex in [-s * 0.07, s * 0.07]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(msx + ex * side, msy - s * 0.02),
              width: s * 0.09,
              height: s * 0.11,
            ),
            Paint()..color = const Color(0xFF111111),
          );
        }
        final mg = 0.45 + 0.28 * sin(_time * 3.2 + side);
        canvas.drawCircle(
          Offset(msx - side * s * 0.07, msy - s * 0.02),
          s * 0.045,
          Paint()
            ..color = Palette.fireGold.withValues(alpha: mg)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // HP BAR
  // ══════════════════════════════════════════════════════════════════════
  void _renderHpBar(Canvas canvas, double s, double fraction) {
    final isBoss = data.kind == EnemyKind.boss;
    final barW = s * (isBoss ? 1.6 : 1.35);
    final barH = isBoss ? 7.0 : 4.5;
    final yOff = -(s * (isBoss ? 0.9 : 0.75)) - barH - 4.0;

    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, yOff), width: barW, height: barH),
      Paint()..color = const Color(0xBB000000),
    );

    final barColor = fraction > 0.5
        ? Color.lerp(const Color(0xFFFFCC00), const Color(0xFF44FF44), (fraction - 0.5) * 2)!
        : Color.lerp(const Color(0xFFCC2222), const Color(0xFFFFCC00), fraction * 2)!;

    if (fraction > 0) {
      canvas.drawRect(
        Rect.fromLTWH(-barW / 2, yOff - barH / 2, barW * fraction, barH),
        Paint()
          ..color = barColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, yOff), width: barW, height: barH),
      Paint()
        ..color = barColor.withValues(alpha: 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    if (isBoss) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(0, yOff), width: barW * 1.2, height: barH * 2.2),
        Paint()
          ..color = barColor.withValues(alpha: 0.18 + 0.1 * sin(_time * 3.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0),
      );
    }
  }
}
