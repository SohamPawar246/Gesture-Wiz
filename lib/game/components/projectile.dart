import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/spell.dart';
import '../palette.dart';
import 'enemy.dart';

/// A projectile that flies toward a target enemy and damages on contact.
/// Now works with GameAction (ActionType) instead of the old Spell combos.
class Projectile extends PositionComponent with HasGameReference {
  final GameAction action;
  final Enemy? target;
  final void Function(Enemy enemy, GameAction action)? onHit;

  double _life = 0;
  final double _speed = 600.0;
  bool _hasHit = false;
  double _time = 0;

  Projectile({
    required Vector2 startPosition,
    required this.action,
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

    switch (action.type) {
      case ActionType.attack:
        _moveToTarget(dt);
        break;
      case ActionType.push:
        // Force push expands outward
        _life += dt; // Extra speed for expansion
        if (_life > 1.0) removeFromParent();
        break;
      case ActionType.shield:
        // Shield is sustained — handled elsewhere, this is just visual
        if (_life > 0.5) removeFromParent();
        break;
      case ActionType.grab:
        // No projectile for grab
        removeFromParent();
        break;
      case ActionType.ultimate:
        // Overwatch pulse radiates outward
        if (_life > 1.5) removeFromParent();
        break;
    }
  }

  void _moveToTarget(double dt) {
    if (target != null && !target!.isDead) {
      final dir = target!.position - position;
      final dist = dir.length;

      if (dist < 60.0) {
        _hasHit = true;
        onHit?.call(target!, action);
        removeFromParent();
        return;
      }

      dir.normalize();
      position += dir * _speed * dt;
    } else {
      // No target — fly straight ahead (up screen toward vanishing point)
      position.y -= _speed * dt;
      if (position.y < -50) removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    switch (action.type) {
      case ActionType.attack:
        _renderAttackProjectile(canvas);
        break;
      case ActionType.push:
        _renderForcePush(canvas);
        break;
      case ActionType.shield:
        _renderShieldWard(canvas);
        break;
      case ActionType.grab:
        break; // No visual
      case ActionType.ultimate:
        _renderOverwatchPulse(canvas);
        break;
    }
  }

  void _renderAttackProjectile(Canvas canvas) {
    final flicker = 0.75 + 0.25 * sin(_time * 12);

    // Outer halo
    final haloPaint = Paint()
      ..color = action.effectColor.withValues(alpha: 0.18 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(Offset.zero, 28, haloPaint);

    // Mid flame body
    final midPaint = Paint()
      ..color = Palette.fireMid.withValues(alpha: 0.55 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset.zero, 16 * flicker, midPaint);

    // Bright core
    final corePaint = Paint()
      ..color = action.effectColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset.zero, 10, corePaint);

    // White-hot nucleus
    final whitePaint = Paint()..color = Palette.fireWhite;
    canvas.drawCircle(Offset.zero, 4.5, whitePaint);

    // Comet tail (offset behind the projectile, drawn as blur streaks)
    for (int i = 1; i <= 5; i++) {
      final tailAlpha = (0.3 - i * 0.05) * flicker;
      final tailPaint = Paint()
        ..color = Palette.fireGold.withValues(alpha: tailAlpha.clamp(0, 1))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 + i * 2.0);
      canvas.drawCircle(
        Offset(0, i * 10.0),
        (10 - i * 1.5).clamp(2, 12),
        tailPaint,
      );
    }
  }

  void _renderForcePush(Canvas canvas) {
    final expand = (_life / 1.0).clamp(0.0, 1.0);
    final alpha = (1.0 - expand).clamp(0.0, 1.0);
    final radius = 30 + expand * 150;

    // Expanding ring
    final ringPaint = Paint()
      ..color = action.effectColor.withValues(alpha: alpha * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0 * (1 - expand * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset.zero, radius, ringPaint);

    // Inner distortion
    final innerPaint = Paint()
      ..color = action.effectColor.withValues(alpha: alpha * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(Offset.zero, radius * 0.6, innerPaint);
  }

  void _renderShieldWard(Canvas canvas) {
    final alpha = (1.0 - _life / 0.5).clamp(0.0, 1.0);

    // Hexagonal ward glow
    final wardPaint = Paint()
      ..color = action.effectColor.withValues(alpha: alpha * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset.zero, 50, wardPaint);

    // Ward outline
    final outlinePaint = Paint()
      ..color = action.effectColor.withValues(alpha: alpha * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw hexagon
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3 - pi / 6;
      final x = cos(angle) * 40;
      final y = sin(angle) * 40;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, outlinePaint);
  }

  void _renderOverwatchPulse(Canvas canvas) {
    final expand = (_life / 1.5).clamp(0.0, 1.0);
    final alpha = (1.0 - expand).clamp(0.0, 1.0);
    final w = game.size.x;
    final radius = expand * w * 0.8;

    // Massive expanding ring
    final ringPaint = Paint()
      ..color = action.effectColor.withValues(alpha: alpha * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15 * (1 - expand)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset.zero, radius, ringPaint);

    // Inner fire
    final firePaint = Paint()
      ..color = Palette.fireGold.withValues(alpha: alpha * 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(Offset.zero, radius * 0.6, firePaint);

    // Eye symbol at center
    if (alpha > 0.3) {
      final eyePaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      // Simple eye shape
      final eyePath = Path();
      eyePath.moveTo(-30, 0);
      eyePath.quadraticBezierTo(0, -20, 30, 0);
      eyePath.quadraticBezierTo(0, 20, -30, 0);
      canvas.drawPath(eyePath, eyePaint);

      // Pupil
      canvas.drawCircle(
        Offset.zero,
        6,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }
}
