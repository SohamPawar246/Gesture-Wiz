import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// Atmospheric dungeon corridor with perspective depth, torch-lit walls,
/// rolling fog, stone archway, and floating embers.
class DungeonBackground extends PositionComponent with HasGameReference {
  final List<_Ember> _embers = [];
  final List<_FogPuff> _fog = [];
  final Random _rng = Random();
  double _time = 0;

  // Face-tracking driven parallax
  double parallaxX = 0.5;
  double parallaxY = 0.5;

  @override
  Future<void> onLoad() async {
    for (int i = 0; i < 38; i++) {
      _embers.add(
        _Ember(
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          speed: 0.008 + _rng.nextDouble() * 0.025,
          size: 1.0 + _rng.nextDouble() * 3.5,
          phase: _rng.nextDouble() * pi * 2,
          brightness: 0.3 + _rng.nextDouble() * 0.7,
        ),
      );
    }
    for (int i = 0; i < 8; i++) {
      _fog.add(
        _FogPuff(
          x: _rng.nextDouble(),
          y: 0.3 + _rng.nextDouble() * 0.4,
          radius: 40 + _rng.nextDouble() * 80,
          speed: 0.003 + _rng.nextDouble() * 0.006,
          phase: _rng.nextDouble() * pi * 2,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    for (final ember in _embers) {
      ember.y -= ember.speed * dt;
      ember.sway = sin(_time * 2.0 + ember.phase) * 0.006;
      ember.x += ember.sway * dt;
      ember.x = ember.x.clamp(0.0, 1.0);
      if (ember.y < -0.05) {
        ember.y = 1.05;
        ember.x = _rng.nextDouble();
      }
    }

    for (final fog in _fog) {
      fog.x += fog.speed * dt;
      if (fog.x > 1.2) fog.x = -0.2;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    if (w <= 0 || h <= 0) return;

    final px = (parallaxX - 0.5) * 180.0;
    final py = (parallaxY - 0.5) * 90.0;

    // Vanishing point
    final vpX = w * 0.5 + px;
    final vpY = h * 0.37 + py;

    // Corridor proportions
    final innerW = w * 0.34;
    final innerH = h * 0.24;
    final innerLeft = vpX - innerW / 2;
    final innerRight = vpX + innerW / 2;
    final innerTop = vpY - innerH / 2;
    final innerBottom = vpY + innerH / 2;

    // ══════════════════════════════════════════════════════
    // 1. FULL BACKGROUND
    // ══════════════════════════════════════════════════════
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF040A0A), Color(0xFF080F0F), Color(0xFF0F0808)],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // ══════════════════════════════════════════════════════
    // 2. CORRIDOR WALLS
    // ══════════════════════════════════════════════════════

    // --- Left wall ---
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
          colors: [const Color(0xFF1A2828), const Color(0xFF0A1414)],
        ).createShader(Rect.fromLTWH(0, 0, innerLeft, h)),
    );

    // --- Right wall ---
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
          colors: [const Color(0xFF1A2828), const Color(0xFF0A1414)],
        ).createShader(Rect.fromLTWH(innerRight, 0, w - innerRight, h)),
    );

    // --- Ceiling ---
    final ceiling = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(innerRight, innerTop)
      ..lineTo(innerLeft, innerTop)
      ..close();
    canvas.drawPath(ceiling, Paint()..color = const Color(0xFF060C0C));

    // --- Floor ---
    final floor = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(innerRight, innerBottom)
      ..lineTo(innerLeft, innerBottom)
      ..close();
    canvas.drawPath(
      floor,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [const Color(0xFF1E1410), const Color(0xFF0A0C0C)],
        ).createShader(Rect.fromLTWH(0, innerBottom, w, h - innerBottom)),
    );

    // --- Back wall ---
    final backWall = Rect.fromLTRB(
      innerLeft,
      innerTop,
      innerRight,
      innerBottom,
    );
    canvas.drawRect(backWall, Paint()..color = const Color(0xFF030606));

    // ══════════════════════════════════════════════════════
    // 3. STONE TEXTURE LINES
    // ══════════════════════════════════════════════════════
    final stonePaint = Paint()
      ..color = const Color(0x1A446666)
      ..strokeWidth = 1.0;

    // Left wall horizontal brick lines
    for (int i = 1; i <= 10; i++) {
      final t = i / 11.0;
      final yScreen = h * t;
      final xEdge = innerLeft * t;
      canvas.drawLine(
        Offset(0, yScreen),
        Offset(xEdge, innerTop + (innerBottom - innerTop) * t),
        stonePaint,
      );
    }
    // Left wall vertical brick joints
    for (int i = 1; i <= 4; i++) {
      final t = i / 5.0;
      canvas.drawLine(
        Offset(innerLeft * t, 0),
        Offset(innerLeft * t * 0.3, h),
        stonePaint..color = const Color(0x0F446666),
      );
    }

    // Right wall horizontal brick lines
    for (int i = 1; i <= 10; i++) {
      final t = i / 11.0;
      final yScreen = h * t;
      final xEdge = innerRight + (w - innerRight) * (1 - t);
      canvas.drawLine(
        Offset(w, yScreen),
        Offset(xEdge, innerTop + (innerBottom - innerTop) * t),
        stonePaint..color = const Color(0x1A446666),
      );
    }

    // Floor perspective lines
    final floorLinePaint = Paint()
      ..color = const Color(0x12556644)
      ..strokeWidth = 1.0;
    for (int i = 1; i <= 6; i++) {
      final t = i / 7.0;
      canvas.drawLine(
        Offset(w * t, h),
        Offset(innerLeft + (innerRight - innerLeft) * t, innerBottom),
        floorLinePaint,
      );
    }

    // ══════════════════════════════════════════════════════
    // 4. PILLARS at the near side of the corridor
    // ══════════════════════════════════════════════════════
    _renderPillar(canvas, Offset(0, 0), Offset(w * 0.06, h), h, true);
    _renderPillar(canvas, Offset(w * 0.94, 0), Offset(w, h), h, false);

    // ══════════════════════════════════════════════════════
    // 5. ARCHWAY (stone arch at the near entrance)
    // ══════════════════════════════════════════════════════
    _renderArchway(canvas, w, h, innerLeft, innerRight, innerTop, innerBottom);

    // ══════════════════════════════════════════════════════
    // 6. WALL TORCHES
    // ══════════════════════════════════════════════════════
    // Left torch — on the left wall at ~40% down
    final leftTorchX = w * 0.14 + px * 0.3;
    final leftTorchY = h * 0.42;
    _renderTorch(canvas, Offset(leftTorchX, leftTorchY));

    // Right torch — mirrored
    final rightTorchX = w * 0.86 + px * 0.3;
    final rightTorchY = h * 0.42;
    _renderTorch(canvas, Offset(rightTorchX, rightTorchY));

    // Extra mid-depth torches (smaller)
    final leftMidTorchX = innerLeft + (w * 0.26 - innerLeft) * 0.5;
    final rightMidTorchX = innerRight + (w * 0.74 - innerRight) * 0.5;
    final midTorchY = h * 0.44;
    _renderTorch(canvas, Offset(leftMidTorchX, midTorchY), scale: 0.6);
    _renderTorch(canvas, Offset(rightMidTorchX, midTorchY), scale: 0.6);

    // ══════════════════════════════════════════════════════
    // 7. AMBIENT CORRIDOR END GLOW
    // ══════════════════════════════════════════════════════
    final ambientPulse = 0.12 + 0.04 * sin(_time * 1.5);
    final ambientGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Palette.fireDeep.withValues(alpha: ambientPulse),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(vpX, vpY), radius: innerW * 0.9),
          );
    canvas.drawRect(backWall.inflate(innerW * 0.35), ambientGlow);

    // ══════════════════════════════════════════════════════
    // 8. FOG / HAZE at the corridor mid-section
    // ══════════════════════════════════════════════════════
    for (final fog in _fog) {
      final fogAlpha = 0.025 + 0.012 * sin(_time * 0.8 + fog.phase);
      final fogPaint = Paint()
        ..color = const Color(0xFF446688).withValues(alpha: fogAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, fog.radius * 0.6);
      canvas.drawCircle(Offset(fog.x * w, fog.y * h), fog.radius, fogPaint);
    }

    // ══════════════════════════════════════════════════════
    // 9. FLOATING EMBERS
    // ══════════════════════════════════════════════════════
    for (final ember in _embers) {
      final ex = ember.x * w;
      final ey = ember.y * h;
      final alpha =
          (0.2 + 0.5 * sin(_time * 2.5 + ember.phase)) * ember.brightness;
      final sz = ember.size * (0.6 + 0.4 * sin(_time * 1.8 + ember.phase));

      final glowPaint = Paint()
        ..color = Palette.fireGold.withValues(
          alpha: (alpha * 0.3).clamp(0.0, 1.0),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
      canvas.drawCircle(Offset(ex, ey), sz * 2.8, glowPaint);

      final corePaint = Paint()
        ..color = Palette.fireBright.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(ex, ey), sz, corePaint);
    }

    // ══════════════════════════════════════════════════════
    // 10. DEEP VIGNETTE
    // ══════════════════════════════════════════════════════
    final vignettePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [Colors.transparent, const Color(0xBB000000)],
            stops: const [0.45, 1.0],
          ).createShader(
            Rect.fromCenter(
              center: Offset(w / 2, h / 2),
              width: w * 1.3,
              height: h * 1.3,
            ),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vignettePaint);

    // ══════════════════════════════════════════════════════
    // 11. FLOOR LAVA CRACKS
    // ══════════════════════════════════════════════════════
    _renderFloorCracks(canvas, w, h, vpX, vpY, innerLeft, innerRight, innerBottom);

    // ══════════════════════════════════════════════════════
    // 12. BACK WALL DEATH GATE
    // ══════════════════════════════════════════════════════
    _renderDeathGate(canvas, vpX, vpY, innerLeft, innerRight, innerTop, innerBottom);

    // ══════════════════════════════════════════════════════
    // 13. HANGING CHAINS
    // ══════════════════════════════════════════════════════
    _renderChains(canvas, w, h, innerLeft, innerRight, innerTop);

    // ══════════════════════════════════════════════════════
    // 14. WALL RUNE SIGILS
    // ══════════════════════════════════════════════════════
    _renderWallRunes(canvas, w, h, innerLeft, innerRight, innerTop, innerBottom);

    // Bottom edge fire glow
    final bottomFireGlow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [const Color(0x66CC3300), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.28), bottomFireGlow);
  }

  // ── Floor Lava Cracks ─────────────────────────────────────────────
  void _renderFloorCracks(
    Canvas canvas,
    double w,
    double h,
    double vpX,
    double vpY,
    double innerLeft,
    double innerRight,
    double innerBottom,
  ) {
    // Lava glow from cracks — emits from floor lines
    final lavaGlow = 0.18 + 0.08 * sin(_time * 2.3);

    // Main central crack — runs from near camera base to vanishing point
    final crackGlowPaint = Paint()
      ..color = const Color(0xFFFF4400).withValues(alpha: lavaGlow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final centralCrack = Path()
      ..moveTo(vpX, innerBottom)
      ..lineTo(vpX + sin(_time * 0.4) * w * 0.02, h * 0.65)
      ..lineTo(vpX - w * 0.03, h * 0.78)
      ..lineTo(vpX + w * 0.01, h);
    canvas.drawPath(centralCrack, crackGlowPaint);

    // Thin dark crack on top
    canvas.drawPath(
      centralCrack,
      Paint()
        ..color = const Color(0xFF220800)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Left side crack
    final leftCrack = Path()
      ..moveTo(vpX - w * 0.05, innerBottom)
      ..lineTo(vpX - w * 0.08, h * 0.7)
      ..lineTo(vpX - w * 0.04, h * 0.85)
      ..lineTo(vpX - w * 0.1, h);
    canvas.drawPath(
      leftCrack,
      Paint()
        ..color = const Color(0xFFFF3300).withValues(alpha: lavaGlow * 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      leftCrack,
      Paint()
        ..color = const Color(0xFF220800)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    // Right side crack
    final rightCrack = Path()
      ..moveTo(vpX + w * 0.05, innerBottom)
      ..lineTo(vpX + w * 0.09, h * 0.72)
      ..lineTo(vpX + w * 0.05, h * 0.86)
      ..lineTo(vpX + w * 0.12, h);
    canvas.drawPath(
      rightCrack,
      Paint()
        ..color = const Color(0xFFFF3300).withValues(alpha: lavaGlow * 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      rightCrack,
      Paint()
        ..color = const Color(0xFF220800)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    // Lava hot-spot pools at intersection nodes
    for (int n = 0; n < 3; n++) {
      final nx = vpX + (-0.5 + n * 0.5) * w * 0.08;
      final ny = h * (0.7 + n * 0.1);
      canvas.drawCircle(
        Offset(nx, ny),
        4.0 + 2.0 * sin(_time * 3 + n),
        Paint()
          ..color = const Color(0xFFFF6600).withValues(
            alpha: 0.35 + 0.15 * sin(_time * 4 + n),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  // ── Death Gate (back wall portal) ────────────────────────────────
  void _renderDeathGate(
    Canvas canvas,
    double vpX,
    double vpY,
    double innerLeft,
    double innerRight,
    double innerTop,
    double innerBottom,
  ) {
    final gateW = (innerRight - innerLeft) * 0.6;
    final gateH = (innerBottom - innerTop) * 0.85;
    final gateCX = vpX;
    final gateCY = vpY + (innerBottom - innerTop) * 0.07;

    // Gate outer glow (pulsing deep red/purple)
    final gatePulse = 0.5 + 0.3 * sin(_time * 1.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(gateCX, gateCY),
        width: gateW * 1.4,
        height: gateH * 1.2,
      ),
      Paint()
        ..color = const Color(0xFF440011).withValues(alpha: gatePulse * 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, gateW * 0.25),
    );

    // Gate arch shape
    final archLeft = gateCX - gateW / 2;
    final archTop = gateCY - gateH / 2;
    final archPath = Path()
      ..moveTo(archLeft, gateCY + gateH / 2)
      ..lineTo(archLeft, gateCY)
      ..cubicTo(
        archLeft,
        gateCY - gateH * 0.55,
        gateCX - gateW * 0.12,
        gateCY - gateH / 2,
        gateCX,
        gateCY - gateH / 2,
      )
      ..cubicTo(
        gateCX + gateW * 0.12,
        gateCY - gateH / 2,
        gateCX + gateW / 2,
        gateCY - gateH * 0.55,
        gateCX + gateW / 2,
        gateCY,
      )
      ..lineTo(gateCX + gateW / 2, gateCY + gateH / 2)
      ..close();

    // Gate dark void interior
    canvas.drawPath(
      archPath,
      Paint()..color = const Color(0xFF080008),
    );

    // Gate interior swirling darkness
    for (int ring = 0; ring < 4; ring++) {
      final rf = ring / 3.0;
      final rPulse = 0.4 + 0.3 * sin(_time * (1.5 + ring * 0.3) + ring);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(gateCX, gateCY + gateH * 0.1),
          width: gateW * (0.55 - rf * 0.12),
          height: gateH * (0.75 - rf * 0.15),
        ),
        Paint()
          ..color = const Color(0xFF660022).withValues(alpha: rPulse * 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0),
      );
    }

    // Red-purple flame edge on the arch
    canvas.drawPath(
      archPath,
      Paint()
        ..color = const Color(0xFFAA0044).withValues(
          alpha: 0.55 + 0.2 * sin(_time * 2.2),
        )
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      archPath,
      Paint()
        ..color = const Color(0xFF660022)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Rune symbols on gate lintel
    final runeY = archTop - gateH * 0.0 + gateH * 0.02;
    final runeAlpha = 0.4 + 0.2 * sin(_time * 1.5);
    for (int r = -2; r <= 2; r++) {
      final rx = gateCX + r * gateW * 0.2;
      _drawRune(
        canvas,
        rx,
        runeY + gateH * 0.05,
        gateW * 0.06,
        r.abs() % 2 == 0 ? 0 : 1,
        runeAlpha,
      );
    }

    // Gate skull emblem in center
    final skullCX = gateCX;
    final skullCY = gateCY;
    final sr = gateW * 0.14;
    // skull outline glow
    canvas.drawCircle(
      Offset(skullCX, skullCY),
      sr * 0.9,
      Paint()
        ..color = const Color(0xFF880022).withValues(
          alpha: 0.25 + 0.15 * sin(_time * 2.5),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sr * 0.4),
    );
    // skull head
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(skullCX, skullCY - sr * 0.1),
        width: sr * 1.4,
        height: sr * 1.3,
      ),
      Paint()..color = const Color(0x55CCCC88),
    );
    // skull eyes
    for (int se = -1; se <= 1; se += 2) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(skullCX + se * sr * 0.28, skullCY - sr * 0.18),
          width: sr * 0.28,
          height: sr * 0.35,
        ),
        Paint()
          ..color = const Color(0xFFFF0000).withValues(
            alpha: 0.4 + 0.3 * sin(_time * 3.5),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  // ── Hanging Chains ────────────────────────────────────────────────
  void _renderChains(
    Canvas canvas,
    double w,
    double h,
    double innerLeft,
    double innerRight,
    double innerTop,
  ) {
    // Chains hang from near-ceiling at both sides
    final chainPositions = [
      Offset(w * 0.22, 0),
      Offset(w * 0.38, 0),
      Offset(w * 0.62, 0),
      Offset(w * 0.78, 0),
    ];

    for (final chainStart in chainPositions) {
      final chainLength = h * (0.28 + 0.1 * sin(chainStart.dx));
      final chainPaint = Paint()
        ..color = const Color(0xFF4A4040)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.butt
        ..style = PaintingStyle.stroke;
      final chainHighlight = Paint()
        ..color = const Color(0xFF6A5850).withValues(alpha: 0.5)
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke;

      // Draw chain as linked ovals (every 8 px a link)
      final linkH = 7.0;
      final linkW = 4.0;
      final numLinks = (chainLength / linkH).floor();
      for (int lk = 0; lk < numLinks; lk++) {
        final ly = chainStart.dy + lk * linkH;
        // Alternating horizontal / vertical links
        if (lk % 2 == 0) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(chainStart.dx, ly + linkH / 2),
              width: linkW * 1.6,
              height: linkH * 0.9,
            ),
            chainPaint,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(chainStart.dx, ly + linkH / 2),
              width: linkW * 1.6,
              height: linkH * 0.9,
            ),
            chainHighlight,
          );
        } else {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(chainStart.dx, ly + linkH / 2),
              width: linkW * 0.9,
              height: linkH * 1.4,
            ),
            chainPaint,
          );
        }
      }

      // Slight glow from torch light on nearest chains
      if (chainStart.dx < w * 0.3 || chainStart.dx > w * 0.7) {
        canvas.drawLine(
          chainStart,
          Offset(chainStart.dx, chainLength),
          Paint()
            ..color = const Color(0x22FF8800)
            ..strokeWidth = 3.0
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }
  }

  // ── Wall Rune Sigils ──────────────────────────────────────────────
  void _renderWallRunes(
    Canvas canvas,
    double w,
    double h,
    double innerLeft,
    double innerRight,
    double innerTop,
    double innerBottom,
  ) {
    // Left wall runes (3 sigils at varying heights)
    final leftWallX = w * 0.07;
    final rightWallX = w * 0.93;
    final runeYPositions = [h * 0.22, h * 0.44, h * 0.66];

    for (int ri = 0; ri < runeYPositions.length; ri++) {
      final ry = runeYPositions[ri];
      final runeAlpha = 0.18 + 0.1 * sin(_time * (1.2 + ri * 0.3) + ri * 1.5);
      _drawRune(canvas, leftWallX, ry, 14.0, ri, runeAlpha);
      _drawRune(canvas, rightWallX, ry, 14.0, (ri + 1) % 3, runeAlpha);
    }

    // Corridor depth runes (on the walls at mid-depth)
    final midDepthX1 = innerLeft + (w * 0.22 - innerLeft) * 0.6;
    final midDepthX2 = innerRight + (w * 0.78 - innerRight) * 0.4;
    for (int ri = 0; ri < 2; ri++) {
      final ry = h * (0.32 + ri * 0.18);
      final alpha = 0.1 + 0.06 * sin(_time * 1.8 + ri * 2.0);
      _drawRune(canvas, midDepthX1, ry, 9.0, ri, alpha);
      _drawRune(canvas, midDepthX2, ry, 9.0, (ri + 2) % 3, alpha);
    }
  }

  // ── Rune symbol helper ─────────────────────────────────────────────
  void _drawRune(
    Canvas canvas,
    double cx,
    double cy,
    double size,
    int type,
    double alpha,
  ) {
    final runeGlow = Paint()
      ..color = const Color(0xFFAA2244).withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.6)
      ..strokeWidth = size * 0.18
      ..style = PaintingStyle.stroke;
    final runeLine = Paint()
      ..color = const Color(0xFFCC3355).withValues(alpha: alpha * 1.4)
      ..strokeWidth = size * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(cx, cy), size * 0.65, runeGlow);

    switch (type % 3) {
      case 0:
        // Elder Futhark-inspired rune (upward strokes)
        canvas.drawLine(Offset(cx, cy - size), Offset(cx, cy + size), runeLine);
        canvas.drawLine(Offset(cx, cy - size), Offset(cx + size * 0.5, cy), runeLine);
        canvas.drawLine(Offset(cx, cy), Offset(cx + size * 0.5, cy + size), runeLine);
        break;
      case 1:
        // Crossed diamond rune
        canvas.drawLine(Offset(cx, cy - size * 0.9), Offset(cx + size * 0.65, cy), runeLine);
        canvas.drawLine(Offset(cx + size * 0.65, cy), Offset(cx, cy + size * 0.9), runeLine);
        canvas.drawLine(Offset(cx, cy + size * 0.9), Offset(cx - size * 0.65, cy), runeLine);
        canvas.drawLine(Offset(cx - size * 0.65, cy), Offset(cx, cy - size * 0.9), runeLine);
        canvas.drawLine(
          Offset(cx - size * 0.5, cy - size * 0.5),
          Offset(cx + size * 0.5, cy + size * 0.5),
          runeLine,
        );
        break;
      case 2:
        // Triple-bar sigil
        canvas.drawLine(Offset(cx - size * 0.6, cy - size * 0.5), Offset(cx + size * 0.6, cy - size * 0.5), runeLine);
        canvas.drawLine(Offset(cx - size * 0.6, cy), Offset(cx + size * 0.6, cy), runeLine);
        canvas.drawLine(Offset(cx - size * 0.6, cy + size * 0.5), Offset(cx + size * 0.6, cy + size * 0.5), runeLine);
        canvas.drawLine(Offset(cx, cy - size * 0.9), Offset(cx, cy + size * 0.9), runeLine);
        break;
    }
  }

  // ── Wall Pillar ────────────────────────────────────────────────
  void _renderPillar(
    Canvas canvas,
    Offset topLeft,
    Offset bottomRight,
    double h,
    bool isLeft,
  ) {
    final pillarRect = Rect.fromPoints(topLeft, bottomRight);
    final gradColors = isLeft
        ? [const Color(0xFF1C2A2A), const Color(0xFF0D1818)]
        : [const Color(0xFF0D1818), const Color(0xFF1C2A2A)];

    canvas.drawRect(
      pillarRect,
      Paint()
        ..shader = LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: gradColors,
        ).createShader(pillarRect),
    );

    // Pillar edge highlight
    final edgePaint = Paint()
      ..color = const Color(0x22446666)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(pillarRect, edgePaint);
  }

  // ── Stone Archway ─────────────────────────────────────────────
  void _renderArchway(
    Canvas canvas,
    double w,
    double h,
    double innerLeft,
    double innerRight,
    double innerTop,
    double innerBottom,
  ) {
    const archColor = Color(0xFF1E2C2C);
    const archEdge = Color(0xFF2A4040);

    final archW = w * 0.15;

    // Left arch column
    final leftArch = Rect.fromLTRB(0, -2, archW, h + 2);
    canvas.drawRect(leftArch, Paint()..color = archColor);
    canvas.drawLine(
      Offset(archW, 0),
      Offset(archW, h),
      Paint()
        ..color = archEdge
        ..strokeWidth = 2.0,
    );

    // Right arch column
    final rightArch = Rect.fromLTRB(w - archW, -2, w + 2, h + 2);
    canvas.drawRect(rightArch, Paint()..color = archColor);
    canvas.drawLine(
      Offset(w - archW, 0),
      Offset(w - archW, h),
      Paint()
        ..color = archEdge
        ..strokeWidth = 2.0,
    );

    // Top lintel
    final topLintel = Rect.fromLTRB(archW, 0, w - archW, h * 0.04);
    canvas.drawRect(topLintel, Paint()..color = archColor);
    canvas.drawLine(
      Offset(archW, h * 0.04),
      Offset(w - archW, h * 0.04),
      Paint()
        ..color = archEdge
        ..strokeWidth = 2.0,
    );

    // Stone blocks on arch columns (decorative)
    final blockPaint = Paint()
      ..color = const Color(0x15446666)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (int i = 0; i < 12; i++) {
      final y = h * i / 12.0;
      canvas.drawLine(Offset(0, y), Offset(archW, y), blockPaint);
      canvas.drawLine(Offset(w - archW, y), Offset(w, y), blockPaint);
    }
  }

  // ── Wall Torch ────────────────────────────────────────────────
  void _renderTorch(Canvas canvas, Offset pos, {double scale = 1.0}) {
    final flicker = 0.65 + 0.35 * sin(_time * 8.5 + pos.dx);
    final flicker2 = 0.60 + 0.40 * sin(_time * 11.0 + pos.dy);

    // Torch bracket (metal sconce)
    final bracketPaint = Paint()
      ..color = const Color(0xFF3A3028)
      ..strokeWidth = 3.0 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      pos.translate(0, 0),
      pos.translate(0, 12 * scale),
      bracketPaint,
    );
    // Torch head (the burning cup)
    final cupPaint = Paint()..color = const Color(0xFF5A4030);
    canvas.drawRect(
      Rect.fromCenter(center: pos, width: 10 * scale, height: 7 * scale),
      cupPaint,
    );

    // Wide outer light splash on wall
    final wallLight = Paint()
      ..color = Palette.fireMid.withValues(alpha: 0.08 * flicker * scale)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 60.0 * scale);
    canvas.drawCircle(pos, 80.0 * scale, wallLight);

    // Mid flame glow
    final midGlow = Paint()
      ..color = Palette.fireDeep.withValues(alpha: 0.35 * flicker)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14.0 * scale);
    canvas.drawCircle(
      pos.translate(0, -8 * scale * flicker),
      16.0 * scale * flicker,
      midGlow,
    );

    // Bright flame core
    final flamePaint = Paint()
      ..color = Palette.fireGold.withValues(alpha: 0.75 * flicker)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5.0 * scale);
    canvas.drawCircle(
      pos.translate(0, -10 * scale * flicker),
      9.0 * scale * flicker,
      flamePaint,
    );

    // White-hot nucleus
    final nucleusPaint = Paint()
      ..color = Palette.fireWhite.withValues(alpha: 0.9);
    canvas.drawCircle(
      pos.translate(0, -9 * scale * flicker),
      3.5 * scale,
      nucleusPaint,
    );

    // Flame wisp (sways side to side)
    final sway = sin(_time * 9.0 + pos.dx) * 4.0 * scale;
    final wispPath = Path();
    wispPath.moveTo(pos.dx - 4 * scale, pos.dy - 5 * scale);
    wispPath.quadraticBezierTo(
      pos.dx + sway,
      pos.dy - 14 * scale * flicker,
      pos.dx + 4 * scale,
      pos.dy - 5 * scale,
    );
    final wispPaint = Paint()
      ..color = Palette.fireBright.withValues(alpha: 0.35 * flicker2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawPath(wispPath, wispPaint);

    // Torch ceiling "cast" mark — light stain above torch
    final ceilLight = Paint()
      ..color = Palette.fireMid.withValues(alpha: 0.06 * flicker)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * scale);
    canvas.drawOval(
      Rect.fromCenter(
        center: pos.translate(0, -30 * scale),
        width: 40 * scale,
        height: 16 * scale,
      ),
      ceilLight,
    );
  }
}

// ── Ember particle ────────────────────────────────────────────
class _Ember {
  double x, y;
  final double speed;
  final double size;
  final double phase;
  final double brightness;
  double sway = 0;

  _Ember({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.phase,
    required this.brightness,
  });
}

// ── Fog puff ──────────────────────────────────────────────────
class _FogPuff {
  double x, y;
  final double radius;
  final double speed;
  final double phase;

  _FogPuff({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
  });
}
