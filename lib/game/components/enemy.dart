import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/enemy_type.dart';
import '../palette.dart';

/// An enemy that spawns deep in the corridor and drifts toward the player.
/// Depth ranges from 0.0 (far, vanishing point) to 1.0 (reached the player).
/// Visual size scales with depth to create the illusion of approach.
class Enemy extends PositionComponent with HasGameReference {
  final EnemyData data;
  double hp;
  double depth; // 0.0 = far, 1.0 = reached player
  double _flashTimer = 0; // White flash on damage
  bool isDead = false;
  double _time = 0;

  // Position in the corridor (normalized -0.5 to 0.5 horizontal, plus vertical jitter)
  final double corridorX;
  final double corridorY;

  Enemy({
    required this.data,
    double? startDepth,
    double? corridorX,
    double? corridorY,
  })  : hp = data.maxHp,
        depth = startDepth ?? 0.0,
        corridorX = corridorX ?? (Random().nextDouble() - 0.5) * 0.6,
        corridorY = corridorY ?? (Random().nextDouble() - 0.5) * 0.3;

  bool get reachedPlayer => depth >= 1.0;

  void takeDamage(double amount) {
    hp -= amount;
    _flashTimer = 0.15; // Flash white for 150ms
    if (hp <= 0) {
      hp = 0;
      isDead = true;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    if (isDead) return;

    // Advance toward the player
    depth += data.speed * dt;

    // Update flash timer
    if (_flashTimer > 0) _flashTimer -= dt;

    // Update screen position based on depth
    final w = game.size.x;
    final h = game.size.y;
    if (w <= 0 || h <= 0) return;

    // Vanishing point (center of corridor)
    final vpX = w * 0.5;
    final vpY = h * 0.38;

    // Interpolate from vanishing point to screen edges based on depth
    final t = depth.clamp(0.0, 1.0);
    final screenX = vpX + corridorX * w * t;
    final screenY = vpY + corridorY * h * t + (h * 0.1 * t); // Drift slightly down

    position = Vector2(screenX, screenY);
  }

  @override
  void render(Canvas canvas) {
    if (isDead) return;

    final t = depth.clamp(0.05, 1.0);
    final baseSize = (data.kind == EnemyKind.boss) ? 50.0 : 28.0;
    final scaledSize = baseSize * t;

    // Skip rendering if too small
    if (scaledSize < 3.0) return;

    final isFlashing = _flashTimer > 0;
    final mainColor = isFlashing ? Colors.white : data.primaryColor;

    switch (data.kind) {
      case EnemyKind.skull:
        _renderSkull(canvas, scaledSize, mainColor);
        break;
      case EnemyKind.eyeball:
        _renderEyeball(canvas, scaledSize, mainColor);
        break;
      case EnemyKind.slime:
        _renderSlime(canvas, scaledSize, mainColor);
        break;
      case EnemyKind.knight:
        _renderKnight(canvas, scaledSize, mainColor);
        break;
      case EnemyKind.boss:
        _renderBoss(canvas, scaledSize, mainColor);
        break;
    }

    // Ember trail behind enemy
    _renderTrail(canvas, scaledSize);
  }

  void _renderSkull(Canvas canvas, double s, Color color) {
    // Head
    final fill = Paint()..color = color;
    final outline = Paint()
      ..color = data.outlineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset.zero, s * 0.5, fill);
    canvas.drawCircle(Offset.zero, s * 0.5, outline);

    // Eye sockets
    final eyePaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawOval(Rect.fromCenter(center: Offset(-s * 0.15, -s * 0.08), width: s * 0.2, height: s * 0.25), eyePaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.15, -s * 0.08), width: s * 0.2, height: s * 0.25), eyePaint);

    // Ember glow in eyes
    final emberPaint = Paint()
      ..color = Palette.fireGold.withValues(alpha: 0.5 + 0.3 * sin(_time * 5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(-s * 0.15, -s * 0.08), s * 0.06, emberPaint);
    canvas.drawCircle(Offset(s * 0.15, -s * 0.08), s * 0.06, emberPaint);

    // Teeth
    final teethPaint = Paint()..color = const Color(0xFFEEEEDD);
    for (int i = -2; i <= 2; i++) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset(i * s * 0.1, s * 0.3), width: s * 0.07, height: s * 0.12),
        teethPaint,
      );
    }
  }

  void _renderEyeball(Canvas canvas, double s, Color color) {
    // White of the eye
    final whitePaint = Paint()..color = const Color(0xFFEEEEDD);
    canvas.drawCircle(Offset.zero, s * 0.45, whitePaint);

    // Veins
    final veinPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 5; i++) {
      final angle = i * pi * 2 / 5 + _time * 0.3;
      canvas.drawLine(
        Offset(cos(angle) * s * 0.15, sin(angle) * s * 0.15),
        Offset(cos(angle) * s * 0.4, sin(angle) * s * 0.4),
        veinPaint,
      );
    }

    // Iris
    final irisPaint = Paint()..color = color;
    canvas.drawCircle(Offset.zero, s * 0.22, irisPaint);

    // Pupil
    final pupilPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawCircle(Offset.zero, s * 0.12, pupilPaint);

    // Pupil highlight
    final highlightPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(-s * 0.05, -s * 0.05), s * 0.04, highlightPaint);

    // Outline
    final outline = Paint()
      ..color = data.outlineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, s * 0.45, outline);
  }

  void _renderSlime(Canvas canvas, double s, Color color) {
    // Blobby body with wobble
    final wobble = sin(_time * 4) * s * 0.05;
    final bodyRect = Rect.fromCenter(
      center: Offset(0, wobble),
      width: s * 1.0 + wobble,
      height: s * 0.8 - wobble,
    );

    final fill = Paint()..color = color;
    canvas.drawOval(bodyRect, fill);

    // Darker shade on bottom
    final shadowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawOval(bodyRect.translate(0, s * 0.1), shadowPaint);

    // Eyes
    final eyeWhite = Paint()..color = Colors.white;
    final pupil = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(-s * 0.15, -s * 0.05), s * 0.1, eyeWhite);
    canvas.drawCircle(Offset(s * 0.15, -s * 0.05), s * 0.1, eyeWhite);
    canvas.drawCircle(Offset(-s * 0.13, -s * 0.03), s * 0.05, pupil);
    canvas.drawCircle(Offset(s * 0.17, -s * 0.03), s * 0.05, pupil);

    // Outline
    final outline = Paint()
      ..color = data.outlineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawOval(bodyRect, outline);
  }

  void _renderKnight(Canvas canvas, double s, Color color) {
    // Body — square/angular armor
    final bodyRect = Rect.fromCenter(center: Offset.zero, width: s * 0.8, height: s * 1.0);
    final fill = Paint()..color = color;
    canvas.drawRect(bodyRect, fill);

    // Helmet
    final helmetRect = Rect.fromCenter(center: Offset(0, -s * 0.35), width: s * 0.7, height: s * 0.4);
    final helmetPaint = Paint()..color = const Color(0xFF666688);
    canvas.drawRect(helmetRect, helmetPaint);

    // Visor slit (menacing eyes)
    final visorPaint = Paint()..color = const Color(0xFFFF4444);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, -s * 0.35), width: s * 0.5, height: s * 0.06),
      visorPaint,
    );

    // Shield icon on body
    final shieldPaint = Paint()..color = const Color(0xFF555577);
    final shieldPath = Path()
      ..moveTo(0, -s * 0.1)
      ..lineTo(-s * 0.15, s * 0.0)
      ..lineTo(-s * 0.12, s * 0.15)
      ..lineTo(0, s * 0.2)
      ..lineTo(s * 0.12, s * 0.15)
      ..lineTo(s * 0.15, s * 0.0)
      ..close();
    canvas.drawPath(shieldPath, shieldPaint);

    // Outline
    final outline = Paint()
      ..color = data.outlineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(bodyRect, outline);
    canvas.drawRect(helmetRect, outline);
  }

  void _renderBoss(Canvas canvas, double s, Color color) {
    // Larger skull with crown and flames
    _renderSkull(canvas, s, color);

    // Crown
    final crownPaint = Paint()..color = Palette.fireGold;
    final crownPath = Path()
      ..moveTo(-s * 0.4, -s * 0.4)
      ..lineTo(-s * 0.3, -s * 0.65)
      ..lineTo(-s * 0.15, -s * 0.5)
      ..lineTo(0, -s * 0.7)
      ..lineTo(s * 0.15, -s * 0.5)
      ..lineTo(s * 0.3, -s * 0.65)
      ..lineTo(s * 0.4, -s * 0.4)
      ..close();
    canvas.drawPath(crownPath, crownPaint);

    final crownOutline = Paint()
      ..color = data.outlineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(crownPath, crownOutline);

    // Boss flame aura
    final auraPaint = Paint()
      ..color = Palette.fireDeep.withValues(alpha: 0.15 + 0.1 * sin(_time * 3))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.3);
    canvas.drawCircle(Offset.zero, s * 0.7, auraPaint);
  }

  void _renderTrail(Canvas canvas, double s) {
    // Small ember particles trailing behind
    final trailPaint = Paint()
      ..color = Palette.fireGold.withValues(alpha: 0.2 + 0.1 * sin(_time * 6))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final trailSize = s * 0.15;

    for (int i = 0; i < 3; i++) {
      final offset = Offset(
        sin(_time * 3 + i * 2) * s * 0.2,
        s * 0.4 + i * s * 0.15,
      );
      canvas.drawCircle(offset, trailSize * (1.0 - i * 0.2), trailPaint);
    }
  }
}
