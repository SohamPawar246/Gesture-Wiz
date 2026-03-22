import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fpv_game.dart';
import '../palette.dart';

class ToxicPuddle extends PositionComponent with HasGameReference<FpvGame> {
  final double radius;
  double _life = 0;
  final double maxLife = 4.0;
  
  // Track if player is currently touching it to apply DoT
  bool _playerTouching = false;
  double _damageTicker = 0;

  ToxicPuddle({
    required Vector2 position,
    this.radius = 40.0,
  }) : super(position: position, size: Vector2.all(radius * 2), anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life >= maxLife) {
      removeFromParent();
      return;
    }

    // Check intersection with player's cursor
    final gameCursor = game.currentCursorPosition; // We'll add this to FpvGame
    _playerTouching = false;
    
    if (gameCursor != null) {
      final dist = (gameCursor - position).length;
      if (dist < radius) {
        _playerTouching = true;
      }
    }

    if (_playerTouching) {
      _damageTicker += dt;
      if (_damageTicker >= 0.2) { // Deal 1 damage every 0.2 seconds (5 DPS)
        _damageTicker = 0;
        game.playerStats.takeDamage(1.0);
        game.triggerScreenShake(2.0); // We'll expose screen shake or trigger damage flash
      }
    } else {
      _damageTicker = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    // Fade in and out
    double alpha = 1.0;
    if (_life < 0.5) alpha = _life / 0.5;
    if (_life > maxLife - 0.5) alpha = (maxLife - _life) / 0.5;
    alpha = alpha.clamp(0.0, 1.0);

    // Pulsing effect
    final pulse = 1.0 + 0.1 * sin(_life * 8);
    final currentRadius = radius * pulse * (0.5 + 0.5 * alpha);

    // Outer glow
    final glowPaint = Paint()
      ..color = const Color(0xFF44CC44).withValues(alpha: 0.3 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), currentRadius * 1.2, glowPaint);

    // Inner caustic puddle
    final puddlePaint = Paint()
      ..color = const Color(0xFF228822).withValues(alpha: 0.7 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), currentRadius, puddlePaint);

    // If player touching, add aggressive acidic bubbles/highlight
    if (_playerTouching) {
      final angryPaint = Paint()
        ..color = const Color(0xFFAAFF44).withValues(alpha: 0.8 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), currentRadius * 0.8, angryPaint);
    }
  }
}
