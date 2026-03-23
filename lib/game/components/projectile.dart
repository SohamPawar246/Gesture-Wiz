import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../models/spell.dart';
import '../palette.dart';
import 'enemy.dart';

/// Cyberpunk-styled projectile that flies toward targets.
/// Each action type has a unique digital/neon visual effect.
class Projectile extends PositionComponent with HasGameReference {
  final GameAction action;
  final Enemy? target;
  final void Function(Enemy enemy, GameAction action)? onHit;
  final double speedMultiplier;

  double _life = 0;
  double get _speed => 600.0 * speedMultiplier;
  bool _hasHit = false;
  double _time = 0;

  Projectile({
    required Vector2 startPosition,
    required this.action,
    this.target,
    this.onHit,
    this.speedMultiplier = 1.0,
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
        _life += dt;
        if (_life > 1.0) removeFromParent();
        break;
      case ActionType.shield:
        if (_life > 0.5) removeFromParent();
        break;
      case ActionType.grab:
        removeFromParent();
        break;
      case ActionType.ultimate:
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
      position.y -= _speed * dt;
      if (position.y < -50) removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    switch (action.type) {
      case ActionType.attack:
        _renderDataSpike(canvas);
        break;
      case ActionType.push:
        _renderEmpBlast(canvas);
        break;
      case ActionType.shield:
        _renderFirewall(canvas);
        break;
      case ActionType.grab:
        break;
      case ActionType.ultimate:
        _renderZeroDay(canvas);
        break;
    }
  }

  /// DATA SPIKE — Electric cyan bolt with trailing code fragments
  void _renderDataSpike(Canvas canvas) {
    final flicker = 0.75 + 0.25 * sin(_time * 15);

    // Outer halo
    canvas.drawCircle(
      Offset.zero,
      30,
      Paint()
        ..color = Palette.neonCyan.withValues(alpha: 0.18 * flicker)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // Mid energy body
    canvas.drawCircle(
      Offset.zero,
      18 * flicker,
      Paint()
        ..color = action.effectColor.withValues(alpha: 0.5 * flicker)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Hexagonal core
    final hexPath = _createHexPath(Offset.zero, 12);
    canvas.drawPath(
      hexPath,
      Paint()
        ..color = action.effectColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      hexPath,
      Paint()
        ..color = Palette.dataWhite.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // White-hot center
    canvas.drawCircle(Offset.zero, 5, Paint()..color = Palette.dataWhite);

    // Data trail behind
    for (int i = 1; i <= 5; i++) {
      final tailAlpha = (0.35 - i * 0.06) * flicker;
      final offset = Offset(0, i * 12.0);

      // Trail segments (rectangular data bits)
      canvas.drawRect(
        Rect.fromCenter(center: offset, width: (8 - i).toDouble(), height: 4),
        Paint()
          ..color = Palette.neonCyan.withValues(alpha: tailAlpha.clamp(0, 1))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 + i),
      );
    }
  }

  /// EMP BLAST — Expanding electromagnetic pulse ring
  void _renderEmpBlast(Canvas canvas) {
    final expand = (_life / 1.0).clamp(0.0, 1.0);
    final alpha = (1.0 - expand).clamp(0.0, 1.0);
    final radius = 40 + expand * 140;

    // Outer distortion ring
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = Palette.empPulse.withValues(alpha: alpha * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12.0 * (1 - expand * 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Mid ring
    canvas.drawCircle(
      Offset.zero,
      radius * 0.8,
      Paint()
        ..color = Palette.neonCyan.withValues(alpha: alpha * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0,
    );

    // Inner hex pattern
    if (alpha > 0.3) {
      final innerHex = _createHexPath(Offset.zero, radius * 0.5);
      canvas.drawPath(
        innerHex,
        Paint()
          ..color = action.effectColor.withValues(alpha: alpha * 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      );
    }

    // Scan lines radiating outward
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4 + expand * pi * 0.5;
      canvas.drawLine(
        Offset(cos(angle) * radius * 0.3, sin(angle) * radius * 0.3),
        Offset(cos(angle) * radius, sin(angle) * radius),
        Paint()
          ..color = Palette.dataWhite.withValues(alpha: alpha * 0.4)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// FIREWALL — Hexagonal honeycomb shield pattern
  void _renderFirewall(Canvas canvas) {
    final alpha = (1.0 - _life / 0.5).clamp(0.0, 1.0);
    final pulse = 0.8 + 0.2 * sin(_time * 10);

    // Outer glow
    canvas.drawCircle(
      Offset.zero,
      55,
      Paint()
        ..color = Palette.dataGreen.withValues(alpha: alpha * 0.3 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
    );

    // Main hexagon
    final mainHex = _createHexPath(Offset.zero, 45);
    canvas.drawPath(
      mainHex,
      Paint()
        ..color = action.effectColor.withValues(alpha: alpha * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Hex outline
    canvas.drawPath(
      mainHex,
      Paint()
        ..color = Palette.dataGreen.withValues(alpha: alpha * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    // Inner honeycomb pattern
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3;
      final hx = cos(angle) * 22;
      final hy = sin(angle) * 22;
      final innerHex = _createHexPath(Offset(hx, hy), 12);
      canvas.drawPath(
        innerHex,
        Paint()
          ..color = Palette.dataGreen.withValues(alpha: alpha * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Center symbol
    canvas.drawCircle(
      Offset.zero,
      8,
      Paint()..color = Palette.dataWhite.withValues(alpha: alpha * 0.9),
    );
  }

  /// ZERO DAY — Massive screen-wide digital storm
  void _renderZeroDay(Canvas canvas) {
    final expand = (_life / 1.5).clamp(0.0, 1.0);
    final alpha = (1.0 - expand).clamp(0.0, 1.0);
    final w = game.size.x;
    final radius = expand * w * 0.85;

    // Massive expanding ring
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = Palette.alertRed.withValues(alpha: alpha * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18 * (1 - expand * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Secondary ring
    canvas.drawCircle(
      Offset.zero,
      radius * 0.8,
      Paint()
        ..color = Palette.neonMagenta.withValues(alpha: alpha * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Inner fire
    canvas.drawCircle(
      Offset.zero,
      radius * 0.5,
      Paint()
        ..color = Palette.alertRed.withValues(alpha: alpha * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
    );

    // Eye symbol at center (when visible)
    if (alpha > 0.4) {
      // Eye outline
      final eyePath = Path()
        ..moveTo(-35, 0)
        ..quadraticBezierTo(0, -22, 35, 0)
        ..quadraticBezierTo(0, 22, -35, 0);

      canvas.drawPath(
        eyePath,
        Paint()
          ..color = Palette.dataWhite.withValues(alpha: alpha * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );

      // Pupil
      canvas.drawCircle(
        Offset.zero,
        8,
        Paint()..color = Palette.alertRed.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        Offset.zero,
        4,
        Paint()..color = Palette.dataWhite.withValues(alpha: alpha * 0.8),
      );
    }

    // Glitch scan lines
    for (int i = 0; i < 6; i++) {
      final lineY = (sin(_time * 8 + i) * 0.5) * radius;
      canvas.drawLine(
        Offset(-radius, lineY),
        Offset(radius, lineY),
        Paint()
          ..color = Palette.dataWhite.withValues(alpha: alpha * 0.2)
          ..strokeWidth = 2.0,
      );
    }
  }

  Path _createHexPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3 - pi / 6;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}
