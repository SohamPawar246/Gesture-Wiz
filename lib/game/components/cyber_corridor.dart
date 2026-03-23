import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// Cyberpunk surveillance corridor — the primary gameplay environment.
/// A neon-lit digital corridor with grid floors, holographic walls,
/// surveillance systems, and atmospheric particle effects.
class CyberCorridor extends PositionComponent with HasGameReference {
  final List<_DataParticle> _particles = [];
  final List<_DataStream> _dataStreams = [];
  final List<_ScanBeam> _scanBeams = [];
  final Random _rng = Random();
  double _time = 0;

  // Parallax from head tracking
  double parallaxX = 0.5;
  double parallaxY = 0.5;

  // Dynamic state
  double alertLevel = 0.0; // 0-1, affects color intensity
  bool isInCombat = false;

  @override
  Future<void> onLoad() async {
    // Initialize particles
    for (int i = 0; i < 45; i++) {
      _particles.add(_DataParticle.random(_rng));
    }
    // Initialize data streams (vertical falling code)
    for (int i = 0; i < 8; i++) {
      _dataStreams.add(_DataStream.random(_rng));
    }
    // Initialize scan beams
    for (int i = 0; i < 3; i++) {
      _scanBeams.add(_ScanBeam.random(_rng, i));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    // Update particles
    for (final p in _particles) {
      p.update(dt, _time);
      if (p.alpha <= 0 || p.y < -0.1 || p.y > 1.1) {
        p.reset(_rng);
      }
    }

    // Update data streams
    for (final ds in _dataStreams) {
      ds.update(dt);
      if (ds.y > 1.3) ds.reset(_rng);
    }

    // Update scan beams
    for (final sb in _scanBeams) {
      sb.update(dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    if (w <= 0 || h <= 0) return;

    final px = (parallaxX - 0.5) * 120.0;
    final py = (parallaxY - 0.5) * 60.0;

    // Vanishing point
    final vpX = w * 0.5 + px;
    final vpY = h * 0.38 + py;

    // Corridor proportions
    final innerW = w * 0.32;
    final innerH = h * 0.22;
    final innerLeft = vpX - innerW / 2;
    final innerRight = vpX + innerW / 2;
    final innerTop = vpY - innerH / 2;
    final innerBottom = vpY + innerH / 2;

    // Alert color shift
    final baseColor = Color.lerp(
      Palette.neonCyan,
      Palette.alertRed,
      alertLevel * 0.6,
    )!;

    // ══════════════════════════════════════════════════════════════════════
    // 1. DEEP VOID BACKGROUND
    // ══════════════════════════════════════════════════════════════════════
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF020208), Color(0xFF040410), Color(0xFF080818)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // ══════════════════════════════════════════════════════════════════════
    // 2. FLOOR GRID (Perspective grid with glowing lines)
    // ══════════════════════════════════════════════════════════════════════
    _renderFloorGrid(
      canvas,
      w,
      h,
      vpX,
      vpY,
      innerLeft,
      innerRight,
      innerBottom,
      baseColor,
    );

    // ══════════════════════════════════════════════════════════════════════
    // 3. CORRIDOR WALLS (Holographic panels with data)
    // ══════════════════════════════════════════════════════════════════════
    _renderCorridorWalls(
      canvas,
      w,
      h,
      innerLeft,
      innerRight,
      innerTop,
      innerBottom,
      baseColor,
    );

    // ══════════════════════════════════════════════════════════════════════
    // 4. CEILING (Dark with strip lights)
    // ══════════════════════════════════════════════════════════════════════
    _renderCeiling(canvas, w, h, innerLeft, innerRight, innerTop, baseColor);

    // ══════════════════════════════════════════════════════════════════════
    // 5. BACK WALL — THE SURVEILLANCE EYE
    // ══════════════════════════════════════════════════════════════════════
    _renderSurveillanceEye(
      canvas,
      vpX,
      vpY,
      innerW,
      innerH,
      innerLeft,
      innerRight,
      innerTop,
      innerBottom,
      baseColor,
    );

    // ══════════════════════════════════════════════════════════════════════
    // 6. NEON STRIP LIGHTS (Along corridor edges)
    // ══════════════════════════════════════════════════════════════════════
    _renderNeonStrips(
      canvas,
      w,
      h,
      innerLeft,
      innerRight,
      innerTop,
      innerBottom,
      baseColor,
    );

    // ══════════════════════════════════════════════════════════════════════
    // 7. DATA STREAMS (Falling code columns)
    // ══════════════════════════════════════════════════════════════════════
    _renderDataStreams(canvas, w, h);

    // ══════════════════════════════════════════════════════════════════════
    // 8. SCAN BEAMS (Horizontal sweeping surveillance)
    // ══════════════════════════════════════════════════════════════════════
    _renderScanBeams(canvas, w, h, baseColor);

    // ══════════════════════════════════════════════════════════════════════
    // 9. FLOATING PARTICLES (Digital debris)
    // ══════════════════════════════════════════════════════════════════════
    _renderParticles(canvas, w, h);

    // ══════════════════════════════════════════════════════════════════════
    // 10. VIGNETTE & ATMOSPHERIC OVERLAY
    // ══════════════════════════════════════════════════════════════════════
    _renderAtmosphere(canvas, w, h, baseColor);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FLOOR GRID
  // ─────────────────────────────────────────────────────────────────────────
  void _renderFloorGrid(
    Canvas canvas,
    double w,
    double h,
    double vpX,
    double vpY,
    double innerLeft,
    double innerRight,
    double innerBottom,
    Color baseColor,
  ) {
    // Floor polygon
    final floor = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(innerRight, innerBottom)
      ..lineTo(innerLeft, innerBottom)
      ..close();

    // Dark floor base
    canvas.drawPath(floor, Paint()..color = const Color(0xFF080812));

    // Grid line color with pulse
    final gridAlpha = 0.15 + 0.05 * sin(_time * 2);
    final gridPaint = Paint()
      ..color = baseColor.withValues(alpha: gridAlpha)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Perspective horizontal lines
    for (int i = 1; i <= 12; i++) {
      final t = i / 13.0;
      final y = innerBottom + (h - innerBottom) * t;
      final leftX = innerLeft - (innerLeft) * t;
      final rightX = innerRight + (w - innerRight) * t;
      canvas.drawLine(Offset(leftX, y), Offset(rightX, y), gridPaint);
    }

    // Perspective vertical lines (converging to VP)
    for (int i = 0; i <= 10; i++) {
      final t = i / 10.0;
      final bottomX = w * t;
      final topX = innerLeft + (innerRight - innerLeft) * t;
      canvas.drawLine(Offset(bottomX, h), Offset(topX, innerBottom), gridPaint);
    }

    // Animated pulse line moving toward player
    final pulseT = (_time * 0.3) % 1.0;
    final pulseY = innerBottom + (h - innerBottom) * pulseT;
    final pulseLeftX = innerLeft - innerLeft * pulseT;
    final pulseRightX = innerRight + (w - innerRight) * pulseT;
    final pulseAlpha = (1.0 - pulseT) * 0.6;
    canvas.drawLine(
      Offset(pulseLeftX, pulseY),
      Offset(pulseRightX, pulseY),
      Paint()
        ..color = baseColor.withValues(alpha: pulseAlpha)
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Floor glow at bottom edge
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.85, w, h * 0.15),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [baseColor.withValues(alpha: 0.08), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, h * 0.85, w, h * 0.15)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CORRIDOR WALLS
  // ─────────────────────────────────────────────────────────────────────────
  void _renderCorridorWalls(
    Canvas canvas,
    double w,
    double h,
    double innerLeft,
    double innerRight,
    double innerTop,
    double innerBottom,
    Color baseColor,
  ) {
    // Left wall
    final leftWall = Path()
      ..moveTo(0, 0)
      ..lineTo(innerLeft, innerTop)
      ..lineTo(innerLeft, innerBottom)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      leftWall,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [const Color(0xFF0C0C18), const Color(0xFF060610)],
        ).createShader(Rect.fromLTWH(0, 0, innerLeft, h)),
    );

    // Right wall
    final rightWall = Path()
      ..moveTo(w, 0)
      ..lineTo(innerRight, innerTop)
      ..lineTo(innerRight, innerBottom)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      rightWall,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [const Color(0xFF0C0C18), const Color(0xFF060610)],
        ).createShader(Rect.fromLTWH(innerRight, 0, w - innerRight, h)),
    );

    // Holographic panel segments on walls
    _renderWallPanels(
      canvas,
      w,
      h,
      innerLeft,
      innerRight,
      innerTop,
      innerBottom,
      baseColor,
      true,
    );
    _renderWallPanels(
      canvas,
      w,
      h,
      innerLeft,
      innerRight,
      innerTop,
      innerBottom,
      baseColor,
      false,
    );
  }

  void _renderWallPanels(
    Canvas canvas,
    double w,
    double h,
    double innerLeft,
    double innerRight,
    double innerTop,
    double innerBottom,
    Color baseColor,
    bool isLeft,
  ) {
    final panelCount = 4;
    final panelAlpha = 0.06 + 0.02 * sin(_time * 1.5);

    for (int i = 0; i < panelCount; i++) {
      final t1 = i / panelCount;
      final t2 = (i + 0.9) / panelCount;

      if (isLeft) {
        final x1 = innerLeft * (1 - t1);
        final x2 = innerLeft * (1 - t2);
        final y1t = h * t1;
        final y1b = h * t2;
        final y2t = innerTop + (innerBottom - innerTop) * t1;
        final y2b = innerTop + (innerBottom - innerTop) * t2;

        final panelPath = Path()
          ..moveTo(x1, y1t)
          ..lineTo(innerLeft, y2t)
          ..lineTo(innerLeft, y2b)
          ..lineTo(x2, y1b)
          ..close();

        // Panel fill
        canvas.drawPath(
          panelPath,
          Paint()..color = baseColor.withValues(alpha: panelAlpha),
        );

        // Panel border
        canvas.drawPath(
          panelPath,
          Paint()
            ..color = baseColor.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      } else {
        final x1 = innerRight + (w - innerRight) * t1;
        final x2 = innerRight + (w - innerRight) * t2;
        final y1t = h * t1;
        final y1b = h * t2;
        final y2t = innerTop + (innerBottom - innerTop) * t1;
        final y2b = innerTop + (innerBottom - innerTop) * t2;

        final panelPath = Path()
          ..moveTo(x1, y1t)
          ..lineTo(innerRight, y2t)
          ..lineTo(innerRight, y2b)
          ..lineTo(x2, y1b)
          ..close();

        canvas.drawPath(
          panelPath,
          Paint()..color = baseColor.withValues(alpha: panelAlpha),
        );

        canvas.drawPath(
          panelPath,
          Paint()
            ..color = baseColor.withValues(alpha: 0.15)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5,
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CEILING
  // ─────────────────────────────────────────────────────────────────────────
  void _renderCeiling(
    Canvas canvas,
    double w,
    double h,
    double innerLeft,
    double innerRight,
    double innerTop,
    Color baseColor,
  ) {
    final ceiling = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(innerRight, innerTop)
      ..lineTo(innerLeft, innerTop)
      ..close();

    canvas.drawPath(ceiling, Paint()..color = const Color(0xFF040408));

    // Ceiling strip lights
    final stripY = innerTop * 0.5;
    final stripPulse = 0.6 + 0.4 * sin(_time * 3);

    // Central strip
    canvas.drawLine(
      Offset(w * 0.3, stripY * 1.5),
      Offset(w * 0.7, stripY * 1.5),
      Paint()
        ..color = baseColor.withValues(alpha: 0.4 * stripPulse)
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawLine(
      Offset(w * 0.3, stripY * 1.5),
      Offset(w * 0.7, stripY * 1.5),
      Paint()
        ..color = baseColor.withValues(alpha: 0.8)
        ..strokeWidth = 1.5,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SURVEILLANCE EYE (Back wall focal point)
  // ─────────────────────────────────────────────────────────────────────────
  void _renderSurveillanceEye(
    Canvas canvas,
    double vpX,
    double vpY,
    double innerW,
    double innerH,
    double innerLeft,
    double innerRight,
    double innerTop,
    double innerBottom,
    Color baseColor,
  ) {
    // Back wall
    final backWall = Rect.fromLTRB(
      innerLeft,
      innerTop,
      innerRight,
      innerBottom,
    );
    canvas.drawRect(backWall, Paint()..color = const Color(0xFF030306));

    // Eye dimensions
    final eyeRadius = innerW * 0.35;
    final eyeCenter = Offset(vpX, vpY);

    // Outer glow rings (pulsing)
    for (int ring = 3; ring >= 0; ring--) {
      final ringRadius = eyeRadius * (1.0 + ring * 0.25);
      final ringAlpha =
          (0.08 - ring * 0.015) * (0.7 + 0.3 * sin(_time * 2 + ring));
      canvas.drawCircle(
        eyeCenter,
        ringRadius,
        Paint()
          ..color = baseColor.withValues(alpha: ringAlpha.clamp(0, 1))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15.0 + ring * 5),
      );
    }

    // Eye socket (dark void)
    canvas.drawOval(
      Rect.fromCenter(
        center: eyeCenter,
        width: eyeRadius * 2.2,
        height: eyeRadius * 1.6,
      ),
      Paint()..color = const Color(0xFF000004),
    );

    // Eye iris with scanning effect
    final scanAngle = _time * 0.5;
    final irisRadius = eyeRadius * 0.8;

    // Iris rings
    for (int i = 3; i >= 0; i--) {
      final r = irisRadius * (0.5 + i * 0.15);
      final alpha = 0.3 - i * 0.05;
      canvas.drawCircle(
        eyeCenter,
        r,
        Paint()
          ..color = baseColor.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Pupil (dark center)
    canvas.drawCircle(
      eyeCenter,
      irisRadius * 0.35,
      Paint()..color = const Color(0xFF000008),
    );

    // Pupil core glow
    final pupilPulse = 0.6 + 0.4 * sin(_time * 4);
    canvas.drawCircle(
      eyeCenter,
      irisRadius * 0.15,
      Paint()
        ..color = baseColor.withValues(alpha: pupilPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      eyeCenter,
      irisRadius * 0.08,
      Paint()..color = Palette.dataWhite.withValues(alpha: 0.9),
    );

    // Scanning lines rotating around iris
    for (int i = 0; i < 4; i++) {
      final angle = scanAngle + i * pi / 2;
      final startR = irisRadius * 0.4;
      final endR = irisRadius * 0.9;
      canvas.drawLine(
        eyeCenter + Offset(cos(angle) * startR, sin(angle) * startR),
        eyeCenter + Offset(cos(angle) * endR, sin(angle) * endR),
        Paint()
          ..color = baseColor.withValues(alpha: 0.4)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    // "WATCHING" text below eye
    final textPulse = 0.5 + 0.5 * sin(_time * 2);
    _drawCenteredText(
      canvas,
      'WATCHING',
      Offset(vpX, innerBottom - innerH * 0.08),
      baseColor.withValues(alpha: 0.4 * textPulse),
      fontSize: 8.0,
    );
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    double fontSize = 10.0,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
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

  // ─────────────────────────────────────────────────────────────────────────
  // NEON STRIPS
  // ─────────────────────────────────────────────────────────────────────────
  void _renderNeonStrips(
    Canvas canvas,
    double w,
    double h,
    double innerLeft,
    double innerRight,
    double innerTop,
    double innerBottom,
    Color baseColor,
  ) {
    final stripPulse = 0.7 + 0.3 * sin(_time * 4);

    // Floor edge strips (pink accent)
    final floorStripColor = Palette.neonPink;

    // Left floor edge
    canvas.drawLine(
      Offset(0, h),
      Offset(innerLeft, innerBottom),
      Paint()
        ..color = floorStripColor.withValues(alpha: 0.5 * stripPulse)
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawLine(
      Offset(0, h),
      Offset(innerLeft, innerBottom),
      Paint()
        ..color = floorStripColor.withValues(alpha: 0.9)
        ..strokeWidth = 1.5,
    );

    // Right floor edge
    canvas.drawLine(
      Offset(w, h),
      Offset(innerRight, innerBottom),
      Paint()
        ..color = floorStripColor.withValues(alpha: 0.5 * stripPulse)
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawLine(
      Offset(w, h),
      Offset(innerRight, innerBottom),
      Paint()
        ..color = floorStripColor.withValues(alpha: 0.9)
        ..strokeWidth = 1.5,
    );

    // Wall vertical strips (cyan)
    final cyanPulse = 0.6 + 0.4 * sin(_time * 3 + 1);

    // Left wall strip
    canvas.drawLine(
      Offset(innerLeft, innerTop),
      Offset(innerLeft, innerBottom),
      Paint()
        ..color = baseColor.withValues(alpha: 0.4 * cyanPulse)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Right wall strip
    canvas.drawLine(
      Offset(innerRight, innerTop),
      Offset(innerRight, innerBottom),
      Paint()
        ..color = baseColor.withValues(alpha: 0.4 * cyanPulse)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATA STREAMS (Falling code)
  // ─────────────────────────────────────────────────────────────────────────
  void _renderDataStreams(Canvas canvas, double w, double h) {
    for (final ds in _dataStreams) {
      final x = ds.x * w;
      final y = ds.y * h;
      final length = ds.length * h;

      // Draw vertical line with gradient
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          ds.color.withValues(alpha: 0.6),
          ds.color.withValues(alpha: 0.1),
        ],
      );

      canvas.drawLine(
        Offset(x, y - length),
        Offset(x, y),
        Paint()
          ..shader = gradient.createShader(
            Rect.fromLTWH(x - 1, y - length, 2, length),
          )
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );

      // Bright head
      canvas.drawCircle(
        Offset(x, y),
        2,
        Paint()
          ..color = Palette.dataWhite.withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCAN BEAMS
  // ─────────────────────────────────────────────────────────────────────────
  void _renderScanBeams(Canvas canvas, double w, double h, Color baseColor) {
    for (final sb in _scanBeams) {
      final y = sb.y * h;
      final alpha = sb.alpha * 0.08;

      // Horizontal scan line
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              baseColor.withValues(alpha: alpha * 2),
              baseColor.withValues(alpha: alpha * 3),
              baseColor.withValues(alpha: alpha * 2),
              Colors.transparent,
            ],
            stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
          ).createShader(Rect.fromLTWH(0, y - 20, w, 40))
          ..strokeWidth = 2,
      );

      // Scan band glow
      canvas.drawRect(
        Rect.fromLTWH(0, y - 15, w, 30),
        Paint()
          ..color = baseColor.withValues(alpha: alpha * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FLOATING PARTICLES
  // ─────────────────────────────────────────────────────────────────────────
  void _renderParticles(Canvas canvas, double w, double h) {
    for (final p in _particles) {
      if (p.alpha <= 0) continue;

      final x = p.x * w;
      final y = p.y * h;

      // Particle glow
      canvas.drawCircle(
        Offset(x, y),
        p.size * 2,
        Paint()
          ..color = p.color.withValues(alpha: p.alpha * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Particle core
      canvas.drawCircle(
        Offset(x, y),
        p.size,
        Paint()..color = p.color.withValues(alpha: p.alpha),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ATMOSPHERE
  // ─────────────────────────────────────────────────────────────────────────
  void _renderAtmosphere(Canvas canvas, double w, double h, Color baseColor) {
    // Vignette
    final vignetteColor = Color.lerp(
      Palette.vignetteCool,
      Palette.vignetteWarm,
      alertLevel,
    )!;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.transparent,
                Colors.transparent,
                vignetteColor.withValues(alpha: 0.5),
                vignetteColor.withValues(alpha: 0.85),
              ],
              stops: const [0.0, 0.4, 0.75, 1.0],
            ).createShader(
              Rect.fromCenter(
                center: Offset(w / 2, h / 2),
                width: w * 1.2,
                height: h * 1.2,
              ),
            ),
    );

    // Subtle ambient glow from bottom
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.7, w, h * 0.3),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [baseColor.withValues(alpha: 0.06), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, h * 0.7, w, h * 0.3)),
    );

    // Top ambient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.15),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Palette.neonPink.withValues(alpha: 0.03),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.15)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA PARTICLE
// ═══════════════════════════════════════════════════════════════════════════
class _DataParticle {
  double x, y, vx, vy, size, alpha, phase;
  Color color;

  _DataParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.phase,
    required this.color,
  });

  static const List<Color> _colors = [
    Palette.neonCyan,
    Palette.neonPink,
    Palette.dataGreen,
    Palette.dataPurple,
  ];

  factory _DataParticle.random(Random rng) {
    return _DataParticle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      vx: (rng.nextDouble() - 0.5) * 0.01,
      vy: -(0.005 + rng.nextDouble() * 0.02),
      size: 1.0 + rng.nextDouble() * 2.5,
      alpha: 0.2 + rng.nextDouble() * 0.6,
      phase: rng.nextDouble() * pi * 2,
      color: _colors[rng.nextInt(_colors.length)],
    );
  }

  void reset(Random rng) {
    x = rng.nextDouble();
    y = 1.05 + rng.nextDouble() * 0.1;
    vx = (rng.nextDouble() - 0.5) * 0.01;
    vy = -(0.005 + rng.nextDouble() * 0.02);
    size = 1.0 + rng.nextDouble() * 2.5;
    alpha = 0.2 + rng.nextDouble() * 0.6;
    color = _colors[rng.nextInt(_colors.length)];
  }

  void update(double dt, double time) {
    x += vx * dt * 60 + sin(phase + time * 2) * 0.001;
    y += vy * dt * 60;
    alpha -= dt * 0.2;
    size -= dt * 0.3;
    phase += dt * 2;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA STREAM (Falling code column)
// ═══════════════════════════════════════════════════════════════════════════
class _DataStream {
  double x, y, speed, length;
  Color color;

  _DataStream({
    required this.x,
    required this.y,
    required this.speed,
    required this.length,
    required this.color,
  });

  static const List<Color> _colors = [
    Palette.neonCyan,
    Palette.dataGreen,
    Palette.neonPink,
  ];

  factory _DataStream.random(Random rng) {
    return _DataStream(
      x: rng.nextDouble(),
      y: -rng.nextDouble() * 0.5,
      speed: 0.2 + rng.nextDouble() * 0.4,
      length: 0.1 + rng.nextDouble() * 0.2,
      color: _colors[rng.nextInt(_colors.length)],
    );
  }

  void reset(Random rng) {
    x = rng.nextDouble();
    y = -0.1 - rng.nextDouble() * 0.3;
    speed = 0.2 + rng.nextDouble() * 0.4;
    length = 0.1 + rng.nextDouble() * 0.2;
    color = _colors[rng.nextInt(_colors.length)];
  }

  void update(double dt) {
    y += speed * dt;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SCAN BEAM (Horizontal sweeping line)
// ═══════════════════════════════════════════════════════════════════════════
class _ScanBeam {
  double y, speed, alpha;
  bool goingDown;

  _ScanBeam({
    required this.y,
    required this.speed,
    required this.alpha,
    required this.goingDown,
  });

  factory _ScanBeam.random(Random rng, int index) {
    return _ScanBeam(
      y: 0.2 + index * 0.3 + rng.nextDouble() * 0.1,
      speed: 0.1 + rng.nextDouble() * 0.15,
      alpha: 0.5 + rng.nextDouble() * 0.5,
      goingDown: rng.nextBool(),
    );
  }

  void update(double dt) {
    if (goingDown) {
      y += speed * dt;
      if (y > 0.9) goingDown = false;
    } else {
      y -= speed * dt;
      if (y < 0.1) goingDown = true;
    }
    // Slight alpha variation
    alpha = 0.4 + 0.3 * sin(y * 10);
  }
}
