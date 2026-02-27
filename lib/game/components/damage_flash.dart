import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// Full-screen red flash overlay when the player takes damage.
/// Fades out over ~200ms.
class DamageFlash extends PositionComponent with HasGameReference {
  double _alpha = 0;

  void trigger() {
    _alpha = 0.5; // Start at 50% opacity red
  }

  @override
  void update(double dt) {
    if (_alpha > 0) {
      _alpha -= dt * 4.0; // Fade out in ~250ms
      if (_alpha < 0) _alpha = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_alpha <= 0) return;
    final w = game.size.x;
    final h = game.size.y;

    final paint = Paint()
      ..color = Palette.impactRed.withValues(alpha: _alpha);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    // Vignette-style red edges (stronger at edges)
    final edgePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Palette.impactRed.withValues(alpha: _alpha * 0.8),
        ],
        stops: const [0.3, 1.0],
      ).createShader(Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: w,
        height: h,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), edgePaint);
  }
}
