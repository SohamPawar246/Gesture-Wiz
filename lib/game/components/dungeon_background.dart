import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// Procedurally drawn dungeon corridor background in the Jon Wick style.
/// Dark teal stone walls with perspective depth, floor tiles, and floating ember particles.
class DungeonBackground extends PositionComponent with HasGameReference {
  final List<_Ember> _embers = [];
  final Random _rng = Random();
  double _time = 0;

  // Optional parallax offset driven by hand position (0-1 normalized)
  double parallaxX = 0.5;
  double parallaxY = 0.5;

  @override
  Future<void> onLoad() async {
    // Pre-generate floating ember particles
    for (int i = 0; i < 30; i++) {
      _embers.add(_Ember(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        speed: 0.01 + _rng.nextDouble() * 0.03,
        size: 1.0 + _rng.nextDouble() * 3.0,
        phase: _rng.nextDouble() * pi * 2,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    // Animate embers — float upward and sway
    for (final ember in _embers) {
      ember.y -= ember.speed * dt;
      if (ember.y < -0.05) {
        ember.y = 1.05;
        ember.x = _rng.nextDouble();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    if (w <= 0 || h <= 0) return;

    // Parallax offset (subtle, ±20px based on hand position)
    final px = (parallaxX - 0.5) * 40.0;
    final py = (parallaxY - 0.5) * 20.0;

    // ==========================================================
    // 1. SKY / CEILING GRADIENT
    // ==========================================================
    final skyGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Palette.bgDark,
          Palette.bgDeep,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.3));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.3), skyGradient);

    // ==========================================================
    // 2. CORRIDOR WALLS (perspective trapezoid)
    // ==========================================================
    // Vanishing point at center-ish, shifted by parallax
    final vpX = w * 0.5 + px;
    final vpY = h * 0.38 + py;

    // Corridor opening dimensions (inner rectangle at vanishing point depth)
    final innerW = w * 0.35;
    final innerH = h * 0.25;
    final innerLeft = vpX - innerW / 2;
    final innerRight = vpX + innerW / 2;
    final innerTop = vpY - innerH / 2;
    final innerBottom = vpY + innerH / 2;

    // --- Left wall ---
    final leftWall = Path()
      ..moveTo(0, 0)
      ..lineTo(innerLeft, innerTop)
      ..lineTo(innerLeft, innerBottom)
      ..lineTo(0, h)
      ..close();

    final leftWallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Palette.bgMid,
          Palette.bgDark,
        ],
      ).createShader(Rect.fromLTWH(0, 0, innerLeft, h));
    canvas.drawPath(leftWall, leftWallPaint);

    // --- Right wall ---
    final rightWall = Path()
      ..moveTo(w, 0)
      ..lineTo(innerRight, innerTop)
      ..lineTo(innerRight, innerBottom)
      ..lineTo(w, h)
      ..close();

    final rightWallPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [
          Palette.bgMid,
          Palette.bgDark,
        ],
      ).createShader(Rect.fromLTWH(innerRight, 0, w - innerRight, h));
    canvas.drawPath(rightWall, rightWallPaint);

    // --- Ceiling ---
    final ceiling = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(innerRight, innerTop)
      ..lineTo(innerLeft, innerTop)
      ..close();

    final ceilingPaint = Paint()..color = Palette.bgDeep;
    canvas.drawPath(ceiling, ceilingPaint);

    // --- Floor ---
    final floor = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(innerRight, innerBottom)
      ..lineTo(innerLeft, innerBottom)
      ..close();

    final floorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Palette.bgMid.withValues(alpha: 0.8),
          Palette.bgDark,
        ],
      ).createShader(Rect.fromLTWH(0, innerBottom, w, h - innerBottom));
    canvas.drawPath(floor, floorPaint);

    // --- Back wall (the dark end of the corridor) ---
    final backWall = Rect.fromLTRB(innerLeft, innerTop, innerRight, innerBottom);
    final backPaint = Paint()..color = Palette.bgDeep;
    canvas.drawRect(backWall, backPaint);

    // ==========================================================
    // 3. WALL DETAILS (stone lines / bricks)
    // ==========================================================
    final linePaint = Paint()
      ..color = Palette.bgHighlight.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    // Horizontal stone lines on left wall
    for (int i = 1; i <= 8; i++) {
      final t = i / 9.0;
      final y = h * t;
      final xEdge = innerLeft * t;
      canvas.drawLine(
        Offset(0, y),
        Offset(xEdge, innerTop + (innerBottom - innerTop) * t),
        linePaint,
      );
    }

    // Horizontal stone lines on right wall
    for (int i = 1; i <= 8; i++) {
      final t = i / 9.0;
      final y = h * t;
      final xEdge = innerRight + (w - innerRight) * (1 - t);
      canvas.drawLine(
        Offset(w, y),
        Offset(xEdge, innerTop + (innerBottom - innerTop) * t),
        linePaint,
      );
    }

    // Floor perspective lines
    final floorLinePaint = Paint()
      ..color = Palette.bgHighlight.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;
    
    for (int i = 1; i <= 5; i++) {
      final t = i / 6.0;
      // Lines from vanishing point outward
      final bottomX = w * t;
      final topX = innerLeft + (innerRight - innerLeft) * t;
      canvas.drawLine(
        Offset(bottomX, h),
        Offset(topX, innerBottom),
        floorLinePaint,
      );
    }

    // ==========================================================
    // 4. AMBIENT LIGHT (warm glow at corridor end)
    // ==========================================================
    final ambientGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Palette.fireDeep.withValues(alpha: 0.15 + 0.05 * sin(_time * 2.0)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(vpX, vpY),
        radius: innerW * 0.8,
      ));
    canvas.drawRect(backWall.inflate(innerW * 0.3), ambientGlow);

    // ==========================================================
    // 5. FLOATING EMBERS
    // ==========================================================
    for (final ember in _embers) {
      final ex = ember.x * w;
      final ey = ember.y * h;
      final alpha = (0.3 + 0.4 * sin(_time * 3.0 + ember.phase)).clamp(0.0, 1.0);
      final size = ember.size * (0.6 + 0.4 * sin(_time * 2.0 + ember.phase));

      // Outer glow
      final glowPaint = Paint()
        ..color = Palette.fireGold.withValues(alpha: alpha * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawCircle(Offset(ex, ey), size * 2.5, glowPaint);

      // Core
      final corePaint = Paint()
        ..color = Palette.fireBright.withValues(alpha: alpha);
      canvas.drawCircle(Offset(ex, ey), size, corePaint);
    }

    // ==========================================================
    // 6. EDGE DARKENING (simple vignette)
    // ==========================================================
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Palette.bgDeep.withValues(alpha: 0.5),
        ],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: w * 1.2,
        height: h * 1.2,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vignettePaint);
  }
}

/// Internal floating ember particle data
class _Ember {
  double x;
  double y;
  final double speed;
  final double size;
  final double phase;

  _Ember({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.phase,
  });
}
