import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

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
            game.spawnEnemyByType(
              EnemyKind.skull,
              startDepth: depth - 0.1,
              corridorX: corridorX - 0.2,
            );
            game.spawnEnemyByType(
              EnemyKind.skull,
              startDepth: depth - 0.1,
              corridorX: corridorX + 0.2,
            );
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
              if (_bossLaserChargeTimer >= 2.0) {
                // 2s charge
                isBossChargingLaser = false;
                _bossLaserChargeTimer = 0;
                // Fire Laser
                if (!game.isShieldActive) {
                  game.playerStats.takeDamage(
                    data.damage * 1.5,
                  ); // Very heavy damage
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
              game.add(
                ToxicPuddle(position: position.clone() + Vector2(100, 50)),
              );
              game.add(
                ToxicPuddle(position: position.clone() + Vector2(-100, 50)),
              );
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
        Rect.fromCenter(
          center: Offset.zero,
          width: scaledSize * 3,
          height: scaledSize * 3,
        ),
        Paint()
          ..colorFilter = const ColorFilter.mode(
            Color(0xFF030505),
            BlendMode.srcATop,
          ),
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
  // DRONE — Surveillance drone with propellers and scanning eye
  // (Replaces Wraith Skull - fast, basic enemy)
  // ══════════════════════════════════════════════════════════════════════
  void _renderWraithSkull(Canvas canvas, double s, Color color, bool flash) {
    final small = s < 14.0;

    // Propeller rotation effect
    final propAngle = _time * 15.0;

    // Outer scanning field
    if (!flash && !small) {
      canvas.drawCircle(
        Offset.zero,
        s * 1.2,
        Paint()
          ..color = Palette.neonCyan.withValues(
            alpha: 0.08 + 0.04 * sin(_time * 2.5),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.8),
      );
    }

    // Main body - hexagonal drone body
    final bodyPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = propAngle * 0.0 + i * pi / 3 - pi / 6;
      final x = cos(angle) * s * 0.45;
      final y = sin(angle) * s * 0.45;
      if (i == 0) {
        bodyPath.moveTo(x, y);
      } else {
        bodyPath.lineTo(x, y);
      }
    }
    bodyPath.close();

    // Body shadow
    canvas.save();
    canvas.translate(s * 0.05, s * 0.1);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();

    // Body fill
    canvas.drawPath(
      bodyPath,
      Paint()..color = flash ? Palette.dataWhite : const Color(0xFF1A1A28),
    );

    // Body edge glow
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = (flash ? Palette.dataWhite : Palette.neonCyan).withValues(
          alpha: 0.6,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Propellers (4 small rotors at corners)
    if (!small) {
      for (int i = 0; i < 4; i++) {
        final angle = i * pi / 2 + pi / 4;
        final px = cos(angle) * s * 0.55;
        final py = sin(angle) * s * 0.55;

        // Propeller blur effect
        canvas.drawCircle(
          Offset(px, py),
          s * 0.18,
          Paint()
            ..color = Palette.neonCyan.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );

        // Propeller blades
        final bladeAngle1 = propAngle + i * pi / 2;
        final bladeAngle2 = bladeAngle1 + pi;
        canvas.drawLine(
          Offset(
            px + cos(bladeAngle1) * s * 0.12,
            py + sin(bladeAngle1) * s * 0.12,
          ),
          Offset(
            px + cos(bladeAngle2) * s * 0.12,
            py + sin(bladeAngle2) * s * 0.12,
          ),
          Paint()
            ..color = Palette.dataWhite.withValues(alpha: 0.4)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Central scanning eye
    final eyePulse = 0.7 + 0.3 * sin(_time * 4.0);

    // Eye glow
    canvas.drawCircle(
      Offset.zero,
      s * 0.25,
      Paint()
        ..color = (flash ? Palette.alertRed : Palette.alertRed).withValues(
          alpha: 0.4 * eyePulse,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.15),
    );

    // Eye outer ring
    canvas.drawCircle(
      Offset.zero,
      s * 0.22,
      Paint()
        ..color = const Color(0xFF2A2A3A)
        ..style = PaintingStyle.fill,
    );

    // Eye inner (lens)
    canvas.drawCircle(
      Offset.zero,
      s * 0.14,
      Paint()..color = flash ? Palette.dataWhite : Palette.alertRed,
    );

    // Pupil highlight
    canvas.drawCircle(
      Offset(-s * 0.04, -s * 0.04),
      s * 0.04,
      Paint()..color = Palette.dataWhite.withValues(alpha: 0.7),
    );

    // Scanning beam (when not flashing)
    if (!flash && !small) {
      final scanY = sin(_time * 3.0) * s * 0.3;
      canvas.drawLine(
        Offset(-s * 0.4, s * 0.35 + scanY),
        Offset(s * 0.4, s * 0.35 + scanY),
        Paint()
          ..color = Palette.alertRed.withValues(alpha: 0.3)
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Status LED lights
    if (!small) {
      final ledColors = [
        Palette.dataGreen,
        Palette.alertAmber,
        Palette.neonCyan,
      ];
      for (int i = 0; i < 3; i++) {
        final ledX = (i - 1) * s * 0.12;
        final ledY = s * 0.35;
        final ledOn = (((_time * 2).floor() + i) % 3) == 0;
        canvas.drawCircle(
          Offset(ledX, ledY),
          s * 0.03,
          Paint()..color = ledColors[i].withValues(alpha: ledOn ? 0.9 : 0.2),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // SENTINEL — Scanning surveillance orb with multiple lenses
  // (Replaces Void Eye - stops and charges laser attack)
  // ══════════════════════════════════════════════════════════════════════
  void _renderVoidEye(Canvas canvas, double s, Color color, bool flash) {
    final small = s < 14.0;

    // Shield ring rotation
    final shieldAngle = _time * 1.5;

    // Outer scanning field glow
    if (!flash) {
      canvas.drawCircle(
        Offset.zero,
        s * 1.3,
        Paint()
          ..color = Palette.neonMagenta.withValues(
            alpha: 0.08 + 0.04 * sin(_time * 2.5),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.8),
      );
    }

    // Rotating shield ring
    if (!small) {
      final ringPaint = Paint()
        ..color = Palette.neonMagenta.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.save();
      canvas.rotate(shieldAngle);
      for (int i = 0; i < 8; i++) {
        final angle = i * pi / 4;
        final arcStart = angle - pi / 12;
        final arcEnd = angle + pi / 12;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: s * 0.7),
          arcStart,
          arcEnd - arcStart,
          false,
          ringPaint,
        );
      }
      canvas.restore();
    }

    // Main orb body
    final orbGradient = RadialGradient(
      colors: [
        const Color(0xFF2A2A3A),
        const Color(0xFF1A1A28),
        const Color(0xFF0A0A14),
      ],
      stops: const [0.0, 0.6, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 0.52));

    canvas.drawCircle(Offset.zero, s * 0.52, Paint()..shader = orbGradient);

    // Orb edge glow
    canvas.drawCircle(
      Offset.zero,
      s * 0.52,
      Paint()
        ..color = (flash ? Palette.dataWhite : Palette.neonMagenta).withValues(
          alpha: 0.5,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Charging laser attack
    if (isEyeballCharging) {
      final chargeRatio = (_eyeballChargeTimer / 1.5).clamp(0.0, 1.0);

      // "TARGET ACQUIRED" pulsing
      canvas.drawCircle(
        Offset.zero,
        s * 0.7,
        Paint()
          ..color = Palette.alertRed.withValues(
            alpha: 0.5 * chargeRatio * (0.5 + 0.5 * sin(_time * 10)),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );

      // Targeting laser
      final laserPaint = Paint()
        ..color = Palette.alertRed.withValues(alpha: 0.7 * chargeRatio)
        ..strokeWidth = s * 0.06 * chargeRatio
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawLine(Offset.zero, Offset(0, s * 60), laserPaint);

      // Intense glow
      canvas.drawCircle(
        Offset.zero,
        s * 0.4 * chargeRatio,
        Paint()
          ..color = Palette.alertRed.withValues(alpha: 0.6 * chargeRatio)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.25),
      );
    }

    // Multiple scanning lenses (3 around the main eye)
    if (!small && !flash) {
      for (int i = 0; i < 3; i++) {
        final lensAngle = i * pi * 2 / 3 + _time * 0.5;
        final lx = cos(lensAngle) * s * 0.32;
        final ly = sin(lensAngle) * s * 0.32;

        // Lens housing
        canvas.drawCircle(
          Offset(lx, ly),
          s * 0.12,
          Paint()..color = const Color(0xFF1A1A28),
        );
        // Lens glass
        canvas.drawCircle(
          Offset(lx, ly),
          s * 0.08,
          Paint()..color = Palette.neonCyan.withValues(alpha: 0.6),
        );
        // Lens highlight
        canvas.drawCircle(
          Offset(lx - s * 0.02, ly - s * 0.02),
          s * 0.025,
          Paint()..color = Palette.dataWhite.withValues(alpha: 0.6),
        );
      }
    }

    // Central main eye
    final mainEyeColor = flash
        ? Palette.dataWhite
        : (isEyeballCharging ? Palette.alertRed : Palette.neonMagenta);

    // Eye socket
    canvas.drawCircle(
      Offset.zero,
      s * 0.28,
      Paint()..color = const Color(0xFF0A0A14),
    );

    // Iris
    canvas.drawCircle(
      Offset.zero,
      s * 0.22,
      Paint()..color = mainEyeColor.withValues(alpha: 0.8),
    );

    // Pupil
    canvas.drawCircle(
      Offset.zero,
      s * 0.12,
      Paint()..color = const Color(0xFF080810),
    );

    // Pupil glow
    final pupilGlow = 0.5 + 0.5 * sin(_time * 3);
    canvas.drawCircle(
      Offset.zero,
      s * 0.08,
      Paint()
        ..color = mainEyeColor.withValues(alpha: 0.6 * pupilGlow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Specular highlight
    canvas.drawCircle(
      Offset(-s * 0.08, -s * 0.08),
      s * 0.04,
      Paint()..color = Palette.dataWhite.withValues(alpha: 0.7),
    );

    // Data streams emanating from orb
    if (!small && !flash) {
      for (int d = 0; d < 4; d++) {
        final streamAngle = d * pi / 2 + _time * 0.3;
        final streamLen = s * 0.8 + sin(_time * 2 + d) * s * 0.1;

        canvas.drawLine(
          Offset(cos(streamAngle) * s * 0.55, sin(streamAngle) * s * 0.55),
          Offset(cos(streamAngle) * streamLen, sin(streamAngle) * streamLen),
          Paint()
            ..color = Palette.neonMagenta.withValues(alpha: 0.3)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // "SCANNING" indicator text equivalent (visual marker)
    if (!flash && !small) {
      final scanPulse = 0.5 + 0.5 * sin(_time * 4);
      canvas.drawCircle(
        Offset(0, s * 0.65),
        s * 0.04,
        Paint()..color = Palette.dataGreen.withValues(alpha: 0.8 * scanPulse),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // GLITCH — Corrupted data entity with pixelated, unstable form
  // (Replaces Acid Blob - drops corruption zones)
  // ══════════════════════════════════════════════════════════════════════
  void _renderAcidBlob(Canvas canvas, double s, Color color, bool flash) {
    final small = s < 14.0;

    // Corruption ground zone
    if (!flash && !small) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, s * 0.7),
          width: s * 1.3,
          height: s * 0.22,
        ),
        Paint()
          ..color = Palette.dataPurple.withValues(
            alpha: 0.18 + 0.06 * sin(_time * 2.0),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.3),
      );
    }

    // Glitch distortion field
    canvas.drawCircle(
      Offset(sin(_time * 8) * s * 0.05, cos(_time * 6) * s * 0.05),
      s * 0.88,
      Paint()
        ..color = Palette.dataPurple.withValues(
          alpha: 0.1 + 0.04 * sin(_time * 2.8),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.72),
    );

    // Core glitch body - pixelated appearance
    final glitchOffset = Offset(
      sin(_time * 10) * s * 0.04,
      cos(_time * 12) * s * 0.03,
    );

    if (flash) {
      canvas.drawRect(
        Rect.fromCenter(center: glitchOffset, width: s * 0.8, height: s * 0.8),
        Paint()..color = Palette.dataWhite,
      );
      return;
    }

    // Draw pixelated blocks that form the glitch body
    final rng = Random((_time * 2).floor());
    final blockSize = s * 0.12;
    for (int x = -3; x <= 3; x++) {
      for (int y = -3; y <= 3; y++) {
        final dist = sqrt(x * x + y * y.toDouble());
        if (dist > 3.5) continue;
        if (rng.nextDouble() > 0.7 - dist * 0.1) continue;

        final blockAlpha = (0.8 - dist * 0.15).clamp(0.2, 0.9);
        final jitterX = sin(_time * 15 + x * y) * s * 0.02;
        final jitterY = cos(_time * 12 + x + y) * s * 0.02;

        canvas.drawRect(
          Rect.fromCenter(
            center:
                Offset(x * blockSize + jitterX, y * blockSize + jitterY) +
                glitchOffset,
            width: blockSize * 0.9,
            height: blockSize * 0.9,
          ),
          Paint()..color = Palette.dataPurple.withValues(alpha: blockAlpha),
        );
      }
    }

    // Chromatic aberration effect - offset copies
    if (!small) {
      for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
          final dist = sqrt(x * x + y * y.toDouble());
          if (dist > 2.5 || rng.nextDouble() > 0.5) continue;

          // Red shifted
          canvas.drawRect(
            Rect.fromCenter(
              center:
                  Offset(x * blockSize - s * 0.03, y * blockSize) +
                  glitchOffset,
              width: blockSize * 0.7,
              height: blockSize * 0.7,
            ),
            Paint()..color = Palette.glitchRed.withValues(alpha: 0.3),
          );
          // Blue shifted
          canvas.drawRect(
            Rect.fromCenter(
              center:
                  Offset(x * blockSize + s * 0.03, y * blockSize) +
                  glitchOffset,
              width: blockSize * 0.7,
              height: blockSize * 0.7,
            ),
            Paint()..color = Palette.glitchBlue.withValues(alpha: 0.3),
          );
        }
      }
    }

    // Central corruption eye
    final eyePulse = 0.6 + 0.4 * sin(_time * 5);
    canvas.drawCircle(
      glitchOffset,
      s * 0.2,
      Paint()
        ..color = Palette.corruption.withValues(alpha: 0.5 * eyePulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      glitchOffset,
      s * 0.12,
      Paint()..color = Palette.corruption,
    );
    canvas.drawCircle(
      glitchOffset,
      s * 0.06,
      Paint()..color = Palette.dataWhite.withValues(alpha: 0.8),
    );

    // Glitch scan lines passing through
    if (!small) {
      for (int i = 0; i < 3; i++) {
        final lineY = (((_time * 3 + i * 0.5) % 1.0) - 0.5) * s * 1.2;
        canvas.drawLine(
          Offset(-s * 0.6, lineY + glitchOffset.dy),
          Offset(s * 0.6, lineY + glitchOffset.dy),
          Paint()
            ..color = Palette.dataWhite.withValues(alpha: 0.4)
            ..strokeWidth = 1.5,
        );
      }
    }

    // Floating data fragments
    if (!small) {
      for (int f = 0; f < 6; f++) {
        final fAngle = f * pi / 3 + _time * 0.8;
        final fDist = s * 0.55 + sin(_time * 3 + f) * s * 0.1;
        final fx = cos(fAngle) * fDist + glitchOffset.dx;
        final fy = sin(fAngle) * fDist + glitchOffset.dy;

        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(fx, fy),
            width: s * 0.1,
            height: s * 0.06,
          ),
          Paint()
            ..color = Palette.neonCyan.withValues(
              alpha: 0.5 + 0.3 * sin(_time * 4 + f),
            ),
        );
      }
    }

    // "ERROR" visual indicator
    if (!small) {
      final errorPulse = ((_time * 3) % 1.0 < 0.1) ? 1.0 : 0.0;
      if (errorPulse > 0) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(0, -s * 0.7),
            width: s * 0.8,
            height: s * 0.15,
          ),
          Paint()..color = Palette.alertRed.withValues(alpha: 0.6),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ENFORCER — Riot control mech with energy shield
  // (Replaces Dread Knight - charges with shield raised)
  // ══════════════════════════════════════════════════════════════════════
  void _renderDreadKnight(Canvas canvas, double s, Color color, bool flash) {
    final small = s < 14.0;

    // Danger aura
    canvas.drawCircle(
      Offset(0, s * 0.1),
      s * 0.85,
      Paint()
        ..color = Palette.alertRed.withValues(alpha: 0.2 + 0.1 * sin(_time * 2))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.65),
    );

    // Charge effect - motion blur behind
    if (isKnightCharging) {
      for (int i = 1; i <= 4; i++) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(0, -s * i * 0.5),
            width: s * 0.8,
            height: s * 1.2,
          ),
          Paint()
            ..color = Palette.alertRed.withValues(alpha: 0.25 / i)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.4),
        );
      }
      // "BREACH IMMINENT" warning bands
      for (int i = 0; i < 2; i++) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(0, s * 0.8 + i * s * 0.15),
            width: s * 1.5,
            height: s * 0.05,
          ),
          Paint()
            ..color = Palette.alertRed.withValues(
              alpha: 0.6 * (1 - (_time * 3 % 1.0)),
            ),
        );
      }
    }

    // Main body - angular mech chassis
    final bodyPath = Path()
      ..moveTo(0, -s * 0.6) // Top point
      ..lineTo(s * 0.4, -s * 0.3) // Top right
      ..lineTo(s * 0.45, s * 0.35) // Bottom right
      ..lineTo(s * 0.2, s * 0.55) // Lower right
      ..lineTo(-s * 0.2, s * 0.55) // Lower left
      ..lineTo(-s * 0.45, s * 0.35) // Bottom left
      ..lineTo(-s * 0.4, -s * 0.3) // Top left
      ..close();

    // Body shadow
    canvas.save();
    canvas.translate(s * 0.03, s * 0.05);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();

    // Body fill
    canvas.drawPath(
      bodyPath,
      Paint()..color = flash ? Palette.dataWhite : const Color(0xFF1A1A28),
    );

    // Body edge
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = (flash ? Palette.dataWhite : Palette.alertAmber).withValues(
          alpha: 0.6,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Energy shield (hexagonal, in front when charging)
    if (!flash) {
      final shieldGlow = isKnightCharging ? 0.8 : 0.3;
      final shieldPath = Path();
      for (int i = 0; i < 6; i++) {
        final angle = i * pi / 3 - pi / 2;
        final x = cos(angle) * s * 0.55;
        final y = sin(angle) * s * 0.45;
        if (i == 0) {
          shieldPath.moveTo(x, y - s * 0.1);
        } else {
          shieldPath.lineTo(x, y - s * 0.1);
        }
      }
      shieldPath.close();

      // Shield glow
      canvas.drawPath(
        shieldPath,
        Paint()
          ..color = Palette.neonCyan.withValues(alpha: shieldGlow * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.15),
      );

      // Shield surface
      canvas.drawPath(
        shieldPath,
        Paint()..color = Palette.neonCyan.withValues(alpha: shieldGlow * 0.15),
      );

      // Shield edge
      canvas.drawPath(
        shieldPath,
        Paint()
          ..color = Palette.neonCyan.withValues(alpha: shieldGlow)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      // Hex pattern on shield
      if (!small) {
        for (int hx = -1; hx <= 1; hx++) {
          for (int hy = -1; hy <= 0; hy++) {
            final hcx = hx * s * 0.22 + (hy % 2) * s * 0.11;
            final hcy = hy * s * 0.2 - s * 0.1;
            final hexPath = Path();
            for (int i = 0; i < 6; i++) {
              final angle = i * pi / 3;
              final x = hcx + cos(angle) * s * 0.08;
              final y = hcy + sin(angle) * s * 0.08;
              if (i == 0)
                hexPath.moveTo(x, y);
              else
                hexPath.lineTo(x, y);
            }
            hexPath.close();
            canvas.drawPath(
              hexPath,
              Paint()
                ..color = Palette.neonCyan.withValues(alpha: shieldGlow * 0.4)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
          }
        }
      }
    }

    // Visor (red glowing slit)
    final visorPulse = 0.7 + 0.3 * sin(_time * 4);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, -s * 0.35),
        width: s * 0.5,
        height: s * 0.08,
      ),
      Paint()
        ..color = Palette.alertRed.withValues(alpha: 0.4 * visorPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, -s * 0.35),
        width: s * 0.45,
        height: s * 0.05,
      ),
      Paint()..color = flash ? Palette.dataWhite : Palette.alertRed,
    );

    // Shoulder warning lights
    if (!small) {
      final lightOn = ((_time * 3).floor() % 2) == 0;
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(
          Offset(side * s * 0.35, -s * 0.2),
          s * 0.05,
          Paint()
            ..color = (isKnightCharging ? Palette.alertRed : Palette.alertAmber)
                .withValues(alpha: lightOn ? 0.9 : 0.3),
        );
      }
    }

    // Leg struts
    if (!small && !flash) {
      for (final side in [-1.0, 1.0]) {
        canvas.drawLine(
          Offset(side * s * 0.25, s * 0.5),
          Offset(side * s * 0.3, s * 0.75),
          Paint()
            ..color = const Color(0xFF2A2A3A)
            ..strokeWidth = s * 0.08
            ..strokeCap = StrokeCap.round,
        );
        // Foot pad
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(side * s * 0.3, s * 0.78),
            width: s * 0.15,
            height: s * 0.05,
          ),
          Paint()..color = const Color(0xFF1A1A28),
        );
      }
    }

    // Status text indicator
    if (isKnightCharging && !small) {
      _drawCenteredText(
        canvas,
        'BREACH',
        Offset(0, -s * 0.8),
        Palette.alertRed.withValues(alpha: 0.8 * (0.5 + 0.5 * sin(_time * 8))),
      );
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 8.0,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // OVERSEER (BOSS) — Massive surveillance command unit
  // (Replaces The Lich - multi-phase boss with laser and summons)
  // ══════════════════════════════════════════════════════════════════════
  void _renderTheLich(Canvas canvas, double s, Color color, bool flash) {
    final outerPulse = 0.7 + 0.3 * sin(_time * 1.4);
    final small = s < 20.0;
    final hpPercent = hp / data.maxHp;
    final isPhase2 = hpPercent <= 0.5;

    // Massive outer void halo
    canvas.drawCircle(
      Offset.zero,
      s * 2.0,
      Paint()
        ..color = (isPhase2 ? Palette.alertRed : Palette.neonCyan).withValues(
          alpha: 0.1 * outerPulse,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 1.5),
    );

    // Rotating surveillance ring
    final ringAngle = _time * 0.5;
    if (!flash) {
      canvas.save();
      canvas.rotate(ringAngle);
      for (int i = 0; i < 12; i++) {
        final segAngle = i * pi / 6;
        final segColor = (i % 3 == 0) ? Palette.alertAmber : Palette.neonCyan;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: s * 1.2),
          segAngle,
          pi / 8,
          false,
          Paint()
            ..color = segColor.withValues(alpha: 0.4 * outerPulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.04,
        );
      }
      canvas.restore();
    }

    // Main head structure - large angular shape
    final headPath = Path()
      ..moveTo(0, -s * 0.7)
      ..lineTo(s * 0.6, -s * 0.3)
      ..lineTo(s * 0.7, s * 0.2)
      ..lineTo(s * 0.5, s * 0.6)
      ..lineTo(-s * 0.5, s * 0.6)
      ..lineTo(-s * 0.7, s * 0.2)
      ..lineTo(-s * 0.6, -s * 0.3)
      ..close();

    // Head shadow
    canvas.save();
    canvas.translate(s * 0.04, s * 0.06);
    canvas.drawPath(
      headPath,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.1),
    );
    canvas.restore();

    // Head fill
    canvas.drawPath(
      headPath,
      Paint()..color = flash ? Palette.dataWhite : const Color(0xFF1A1A28),
    );

    // Tech panel lines on head
    if (!flash && !small) {
      final panelPaint = Paint()
        ..color = Palette.neonCyan.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(-s * 0.5, -s * 0.1),
        Offset(s * 0.5, -s * 0.1),
        panelPaint,
      );
      canvas.drawLine(
        Offset(-s * 0.4, s * 0.2),
        Offset(s * 0.4, s * 0.2),
        panelPaint,
      );
      canvas.drawLine(Offset(0, -s * 0.65), Offset(0, s * 0.55), panelPaint);
    }

    // Head edge glow
    final edgeColor = isPhase2 ? Palette.alertRed : Palette.neonCyan;
    canvas.drawPath(
      headPath,
      Paint()
        ..color = (flash ? Palette.dataWhite : edgeColor).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // === MAIN SURVEILLANCE EYE ===
    final mainEyeRadius = s * 0.35;
    final eyeColor = isPhase2 ? Palette.alertRed : Palette.neonMagenta;

    // Eye glow
    canvas.drawCircle(
      Offset(0, -s * 0.15),
      mainEyeRadius * 1.5,
      Paint()
        ..color = eyeColor.withValues(alpha: 0.3 * outerPulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.2),
    );

    // Eye socket
    canvas.drawCircle(
      Offset(0, -s * 0.15),
      mainEyeRadius,
      Paint()..color = const Color(0xFF080810),
    );

    // Iris ring
    canvas.drawCircle(
      Offset(0, -s * 0.15),
      mainEyeRadius * 0.85,
      Paint()
        ..color = eyeColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05,
    );

    // Inner iris
    canvas.drawCircle(
      Offset(0, -s * 0.15),
      mainEyeRadius * 0.6,
      Paint()..color = eyeColor.withValues(alpha: 0.6),
    );

    // Pupil
    canvas.drawCircle(
      Offset(0, -s * 0.15),
      mainEyeRadius * 0.35,
      Paint()..color = const Color(0xFF000008),
    );

    // Pupil core glow
    final pupilPulse = 0.5 + 0.5 * sin(_time * 4);
    canvas.drawCircle(
      Offset(0, -s * 0.15),
      mainEyeRadius * 0.2,
      Paint()
        ..color = eyeColor.withValues(alpha: 0.8 * pupilPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(0, -s * 0.15),
      mainEyeRadius * 0.1,
      Paint()..color = Palette.dataWhite.withValues(alpha: 0.9),
    );

    // Specular
    canvas.drawCircle(
      Offset(-mainEyeRadius * 0.3, -s * 0.15 - mainEyeRadius * 0.3),
      mainEyeRadius * 0.12,
      Paint()..color = Palette.dataWhite.withValues(alpha: 0.6),
    );

    // === LASER CHARGING ===
    if (isBossChargingLaser) {
      final chargeRatio = (_bossLaserChargeTimer / 2.0).clamp(0.0, 1.0);

      // Charging rings
      for (int i = 0; i < 3; i++) {
        final ringSize = mainEyeRadius * (1.5 + chargeRatio * i * 0.5);
        canvas.drawCircle(
          Offset(0, -s * 0.15),
          ringSize,
          Paint()
            ..color = Palette.alertRed.withValues(
              alpha: 0.4 * chargeRatio * (0.5 + 0.5 * sin(_time * 12 + i)),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.0,
        );
      }

      // Charging beam
      canvas.drawLine(
        Offset(0, -s * 0.15),
        Offset(0, s * 50),
        Paint()
          ..color = Palette.alertRed.withValues(alpha: 0.6 * chargeRatio)
          ..strokeWidth = s * 0.1 * chargeRatio
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      // "PURGE PROTOCOL" indicator
      if (!small) {
        final textPulse = 0.5 + 0.5 * sin(_time * 10);
        _drawBossText(
          canvas,
          'PURGE',
          Offset(0, -s * 0.9),
          Palette.alertRed.withValues(alpha: 0.9 * textPulse),
          s * 0.15,
        );
      }
    }

    // === SECONDARY EYES (on sides) ===
    if (!small && !flash) {
      for (final side in [-1.0, 1.0]) {
        final sideEyeX = side * s * 0.45;
        final sideEyeY = s * 0.25;
        final sideEyeR = s * 0.12;

        // Socket
        canvas.drawCircle(
          Offset(sideEyeX, sideEyeY),
          sideEyeR,
          Paint()..color = const Color(0xFF080810),
        );
        // Iris
        canvas.drawCircle(
          Offset(sideEyeX, sideEyeY),
          sideEyeR * 0.7,
          Paint()..color = eyeColor.withValues(alpha: 0.7),
        );
        // Pupil
        canvas.drawCircle(
          Offset(sideEyeX, sideEyeY),
          sideEyeR * 0.35,
          Paint()..color = const Color(0xFF000008),
        );
      }
    }

    // === DATA STREAMS from head ===
    if (!flash && !small) {
      for (int i = 0; i < 6; i++) {
        final streamAngle = i * pi / 3 + _time * 0.3;
        final streamLen = s * 1.0 + sin(_time * 2 + i) * s * 0.2;
        final startR = s * 0.75;

        canvas.drawLine(
          Offset(cos(streamAngle) * startR, sin(streamAngle) * startR),
          Offset(cos(streamAngle) * streamLen, sin(streamAngle) * streamLen),
          Paint()
            ..color = Palette.neonCyan.withValues(alpha: 0.25)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // === PHASE INDICATORS ===
    if (!flash && isPhase2) {
      // Phase 2 warning stripes
      for (int i = 0; i < 4; i++) {
        final stripeY = s * 0.65 + i * s * 0.08;
        canvas.drawLine(
          Offset(-s * 0.6, stripeY),
          Offset(s * 0.6, stripeY),
          Paint()
            ..color = Palette.alertRed.withValues(
              alpha: 0.3 * ((_time * 4 + i) % 1.0 < 0.5 ? 1.0 : 0.3),
            )
            ..strokeWidth = s * 0.02,
        );
      }
    }

    // === STATUS INDICATOR ===
    if (!small) {
      final statusText = isPhase2 ? 'LOCKDOWN' : 'OBSERVING';
      final statusColor = isPhase2 ? Palette.alertRed : Palette.dataGreen;
      _drawBossText(
        canvas,
        statusText,
        Offset(0, s * 0.85),
        statusColor.withValues(alpha: 0.7),
        s * 0.08,
      );
    }
  }

  void _drawBossText(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double fontSize,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          letterSpacing: 3.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // HP BAR — Cyberpunk-styled health indicator
  // ══════════════════════════════════════════════════════════════════════
  void _renderHpBar(Canvas canvas, double s, double fraction) {
    final isBoss = data.kind == EnemyKind.boss;
    final barW = s * (isBoss ? 1.6 : 1.35);
    final barH = isBoss ? 7.0 : 4.5;
    final yOff = -(s * (isBoss ? 0.9 : 0.75)) - barH - 4.0;

    // Background
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, yOff), width: barW, height: barH),
      Paint()..color = const Color(0xCC000008),
    );

    // Health color - cyan when healthy, red when low
    final barColor = fraction > 0.5
        ? Color.lerp(
            Palette.alertAmber,
            Palette.dataGreen,
            (fraction - 0.5) * 2,
          )!
        : Color.lerp(Palette.alertRed, Palette.alertAmber, fraction * 2)!;

    if (fraction > 0) {
      // Health fill
      canvas.drawRect(
        Rect.fromLTWH(-barW / 2, yOff - barH / 2, barW * fraction, barH),
        Paint()..color = barColor,
      );

      // Health glow
      canvas.drawRect(
        Rect.fromLTWH(-barW / 2, yOff - barH / 2, barW * fraction, barH),
        Paint()
          ..color = barColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Border
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, yOff), width: barW, height: barH),
      Paint()
        ..color = barColor.withValues(alpha: 0.6)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // Boss gets extra warning glow
    if (isBoss) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, yOff),
          width: barW * 1.15,
          height: barH * 2.0,
        ),
        Paint()
          ..color = barColor.withValues(alpha: 0.15 + 0.08 * sin(_time * 3.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0),
      );
    }
  }
}
