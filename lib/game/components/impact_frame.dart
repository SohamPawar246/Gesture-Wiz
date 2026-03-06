import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A 1-2 frame anime-style black-and-white inverted flash for massive hits.
class ImpactFrame extends PositionComponent with HasGameReference {
  double _lifeTime = 0;
  final double duration = 0.08; // ~5 frames at 60fps

  @override
  void update(double dt) {
    super.update(dt);
    _lifeTime += dt;
    if (_lifeTime >= duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = game.size.x;
    final h = game.size.y;
    if (w <= 0 || h <= 0) return;

    // Phase 1 (First half): Pure inverse BW
    // Phase 2 (Second half): Speed lines or harsh black overlay
    final progress = _lifeTime / duration;

    if (progress < 0.5) {
      // Harsh inverted color or pure white/black flash
      final paint = Paint()
        ..color = progress < 0.25 ? Colors.white : Colors.black
        ..blendMode = BlendMode.difference; // Inverts colors behind it
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);
    } else {
      // Draw anime speed lines rushing towards the center
      final center = Offset(w / 2, h / 2);
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke;
      
      final numLines = 30;
      final rng = Random();
      for (int i = 0; i < numLines; i++) {
        final angle = (i / numLines) * 2 * pi + rng.nextDouble() * 0.1;
        final innerRadius = rng.nextDouble() * 100 + 50;
        final outerRadius = max(w, h);
        
        final start = center + Offset(cos(angle) * innerRadius, sin(angle) * innerRadius);
        final end = center + Offset(cos(angle) * outerRadius, sin(angle) * outerRadius);
        canvas.drawLine(start, end, paint);
      }
    }
  }
}
