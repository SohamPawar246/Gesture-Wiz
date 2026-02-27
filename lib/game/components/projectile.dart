import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/spell.dart';
import '../palette.dart';
import 'enemy.dart';

/// A spell projectile that flies toward a target enemy and damages on contact.
/// Behavior varies by SpellType.
class Projectile extends PositionComponent with HasGameReference {
  final Spell spell;
  final Enemy? target;
  final void Function(Enemy enemy, Spell spell)? onHit;
  
  double _life = 0;
  final double _speed = 600.0;
  bool _hasHit = false;
  double _time = 0;

  Projectile({
    required Vector2 startPosition,
    required this.spell,
    this.target,
    this.onHit,
  }) : super(position: startPosition.clone(), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    _time += dt;

    if (_hasHit || _life > 3.0) {
      removeFromParent();
      return;
    }

    switch (spell.type) {
      case SpellType.attack:
        _moveToTarget(dt);
        break;
      case SpellType.defense:
        // Defense expands outward as a shield — handled in render
        _life += dt; // Extra speed for shield expansion
        if (_life > 1.5) removeFromParent();
        break;
      case SpellType.heal:
        // Heal is instant — just visual
        if (_life > 1.0) removeFromParent();
        break;
      case SpellType.ultimate:
        // Ultimate radiates outward hitting everything
        if (_life > 1.5) removeFromParent();
        break;
    }
  }

  void _moveToTarget(double dt) {
    if (target != null && !target!.isDead) {
      final dir = target!.position - position;
      final dist = dir.length;
      
      if (dist < 25.0) {
        // Hit!
        _hasHit = true;
        onHit?.call(target!, spell);
        removeFromParent();
        return;
      }

      dir.normalize();
      position += dir * _speed * dt;
    } else {
      // No target — fly straight ahead (up the screen)
      position.y -= _speed * dt;
      if (position.y < -50) removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    switch (spell.type) {
      case SpellType.attack:
        _renderAttackProjectile(canvas);
        break;
      case SpellType.defense:
        _renderShieldWall(canvas);
        break;
      case SpellType.heal:
        _renderHealEffect(canvas);
        break;
      case SpellType.ultimate:
        _renderUltimateBlast(canvas);
        break;
    }
  }

  void _renderAttackProjectile(Canvas canvas) {
    final flicker = 0.8 + 0.2 * sin(_time * 10);

    // Outer glow
    final glowPaint = Paint()
      ..color = spell.effectColor.withValues(alpha: 0.3 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset.zero, 20, glowPaint);

    // Core
    final corePaint = Paint()..color = spell.effectColor;
    canvas.drawCircle(Offset.zero, 8, corePaint);

    // White-hot center
    final whitePaint = Paint()..color = Palette.fireWhite;
    canvas.drawCircle(Offset.zero, 3, whitePaint);
  }

  void _renderShieldWall(Canvas canvas) {
    final expand = (_life / 1.5).clamp(0.0, 1.0);
    final alpha = (1.0 - expand).clamp(0.0, 1.0);
    final radius = 80 + expand * 200;

    // Shield arc
    final shieldPaint = Paint()
      ..color = spell.effectColor.withValues(alpha: alpha * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      -pi * 0.7, pi * 1.4, false, shieldPaint,
    );

    // Inner glow
    final innerPaint = Paint()
      ..color = spell.effectColor.withValues(alpha: alpha * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset.zero, radius * 0.8, innerPaint);
  }

  void _renderHealEffect(Canvas canvas) {
    final alpha = (1.0 - _life / 1.0).clamp(0.0, 1.0);
    final expand = _life * 2;

    // Rising green sparkles
    for (int i = 0; i < 8; i++) {
      final angle = i * pi * 2 / 8 + _time * 2;
      final r = 20.0 + expand * 30;
      final x = cos(angle) * r;
      final y = sin(angle) * r - expand * 40;

      final sparkPaint = Paint()
        ..color = spell.effectColor.withValues(alpha: alpha * 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), 4, sparkPaint);
    }

    // Center + cross
    final crossPaint = Paint()
      ..color = spell.effectColor.withValues(alpha: alpha)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, -12), Offset(0, 12), crossPaint);
    canvas.drawLine(Offset(-12, 0), Offset(12, 0), crossPaint);
  }

  void _renderUltimateBlast(Canvas canvas) {
    final expand = (_life / 1.5).clamp(0.0, 1.0);
    final alpha = (1.0 - expand).clamp(0.0, 1.0);
    final w = game.size.x;
    final radius = expand * w * 0.8;

    // Massive expanding ring
    final ringPaint = Paint()
      ..color = spell.effectColor.withValues(alpha: alpha * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15 * (1 - expand)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset.zero, radius, ringPaint);

    // Inner fire
    final firePaint = Paint()
      ..color = Palette.fireGold.withValues(alpha: alpha * 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(Offset.zero, radius * 0.6, firePaint);
  }
}
