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
  double _flashTimer = 0;
  bool isDead = false;
  double _time = 0;

  final double corridorX;
  final double corridorY;

  Enemy({
    required this.data,
    double? startDepth,
    double? corridorX,
    double? corridorY,
  }) : hp = data.maxHp,
       depth = startDepth ?? 0.0,
       corridorX = corridorX ?? (Random().nextDouble() - 0.5) * 0.6,
       corridorY = corridorY ?? (Random().nextDouble() - 0.5) * 0.3;

  bool get reachedPlayer => depth >= 1.0;

  void takeDamage(double amount) {
    hp -= amount;
    _flashTimer = 0.18;
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

    depth += data.speed * dt;
    if (_flashTimer > 0) _flashTimer -= dt;

    final w = game.size.x;
    final h = game.size.y;
    if (w <= 0 || h <= 0) return;

    final vpX = w * 0.5;
    final vpY = h * 0.38;
    final t = depth.clamp(0.0, 1.0);
    final screenX = vpX + corridorX * w * t;
    final screenY = vpY + corridorY * h * t + (h * 0.1 * t);
    position = Vector2(screenX, screenY);
  }

  @override
  void render(Canvas canvas) {
    if (isDead) return;

    final t = depth.clamp(0.05, 1.0);
    final baseSize = (data.kind == EnemyKind.boss) ? 54.0 : 32.0;
    final scaledSize = baseSize * t;
    if (scaledSize < 3.0) return;

    final isFlashing = _flashTimer > 0;
    final mainColor = isFlashing ? Colors.white : data.primaryColor;

    switch (data.kind) {
      case EnemyKind.skull:
        _renderWraithSkull(canvas, scaledSize, mainColor, isFlashing);
        break;
      case EnemyKind.eyeball:
        _renderVoidEye(canvas, scaledSize, mainColor, isFlashing);
        break;
      case EnemyKind.slime:
        _renderAcidBlob(canvas, scaledSize, mainColor, isFlashing);
        break;
      case EnemyKind.knight:
        _renderDreadKnight(canvas, scaledSize, mainColor, isFlashing);
        break;
      case EnemyKind.boss:
        _renderTheLich(canvas, scaledSize, mainColor, isFlashing);
        break;
    }

    final hpFraction = hp / data.maxHp;
    if (data.kind == EnemyKind.boss || hpFraction < 0.999) {
      _renderHpBar(canvas, scaledSize, hpFraction);
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // WRAITH SKULL
  // ══════════════════════════════════════════════════════════════════════
  void _renderWraithSkull(Canvas canvas, double s, Color color, bool flash) {
    // Outer dark aura
    canvas.drawCircle(
      Offset(0, s * 0.1),
      s * 1.1,
      Paint()
        ..color = const Color(0x44440088)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 1.0),
    );

    // Wispy smoke tendrils below skull
    if (!flash) {
      for (int i = 0; i < 4; i++) {
        final sw = sin(_time * 1.8 + i * pi / 2) * s * 0.18;
        final smokePaint = Paint()
          ..color = const Color(0x44220044)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.35);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(sw, s * (0.45 + i * 0.2)),
            width: s * (0.55 - i * 0.1),
            height: s * 0.22,
          ),
          smokePaint,
        );
      }
    }

    // Skull shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, s * 0.15),
        width: s * 1.1,
        height: s * 0.22,
      ),
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Cranium
    final boneColor = flash ? Colors.white : const Color(0xFFD8D4C0);
    final craniumPath = Path()
      ..moveTo(-s * 0.48, s * 0.1)
      ..cubicTo(-s * 0.52, -s * 0.08, -s * 0.48, -s * 0.58, 0, -s * 0.62)
      ..cubicTo(s * 0.48, -s * 0.58, s * 0.52, -s * 0.08, s * 0.48, s * 0.1)
      ..close();
    canvas.drawPath(craniumPath, Paint()..color = boneColor);

    // Cracks with glow
    if (!flash) {
      final crackGlow = 0.6 + 0.25 * sin(_time * 3.2);
      final crackGlowPaint = Paint()
        ..color = const Color(0xFFFF5500).withValues(alpha: crackGlow * 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final crackDarkPaint = Paint()
        ..color = const Color(0xFF220800)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      final c1 = Path()
        ..moveTo(-s * 0.04, -s * 0.58)
        ..lineTo(s * 0.1, -s * 0.32)
        ..lineTo(s * 0.04, -s * 0.1);
      final c2 = Path()
        ..moveTo(s * 0.22, -s * 0.45)
        ..lineTo(s * 0.14, -s * 0.2);
      canvas.drawPath(c1, crackGlowPaint);
      canvas.drawPath(c2, crackGlowPaint..strokeWidth = 2.0);
      canvas.drawPath(c1, crackDarkPaint);
      canvas.drawPath(c2, crackDarkPaint);
    }

    // Cranium outline
    canvas.drawPath(
      craniumPath,
      Paint()
        ..color = const Color(0xFF443322)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Floating jaw
    final jawFloat = sin(_time * 2.6) * s * 0.07;
    final jawY = s * 0.22 + jawFloat;
    final jawPath = Path()
      ..moveTo(-s * 0.38, jawY)
      ..lineTo(-s * 0.38, jawY + s * 0.22)
      ..cubicTo(
        -s * 0.2,
        jawY + s * 0.32,
        s * 0.2,
        jawY + s * 0.32,
        s * 0.38,
        jawY + s * 0.22,
      )
      ..lineTo(s * 0.38, jawY)
      ..cubicTo(s * 0.2, jawY - s * 0.06, -s * 0.2, jawY - s * 0.06, -s * 0.38, jawY)
      ..close();
    canvas.drawPath(jawPath, Paint()..color = boneColor);
    canvas.drawPath(
      jawPath,
      Paint()
        ..color = const Color(0xFF443322)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    // Teeth
    if (!flash) {
      final teethPaint = Paint()..color = const Color(0xFFF0ECDC);
      final teethOutline = Paint()
        ..color = const Color(0xFF443322)
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke;
      for (int i = -3; i <= 3; i++) {
        final tx = i * s * 0.09;
        final h2 = s * (i.abs() % 2 == 0 ? 0.18 : 0.13);
        final tp = Path()
          ..moveTo(tx - s * 0.038, jawY)
          ..lineTo(tx, jawY - h2)
          ..lineTo(tx + s * 0.038, jawY)
          ..close();
        canvas.drawPath(tp, teethPaint);
        canvas.drawPath(tp, teethOutline);
      }
    }

    // Eye sockets
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-s * 0.17, -s * 0.16),
        width: s * 0.22,
        height: s * 0.28,
      ),
      Paint()..color = const Color(0xFF080808),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.17, -s * 0.16),
        width: s * 0.22,
        height: s * 0.28,
      ),
      Paint()..color = const Color(0xFF080808),
    );

    // Eye flames
    if (!flash) {
      final lfb = 0.5 + 0.3 * sin(_time * 4.2);
      final rfb = 0.5 + 0.3 * sin(_time * 3.7 + 1.1);
      // Left: hellfire
      canvas.drawCircle(
        Offset(-s * 0.17, -s * 0.18),
        s * 0.09,
        Paint()
          ..color = const Color(0xFFFF5500).withValues(alpha: lfb * 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(-s * 0.17, -s * 0.2),
        s * 0.045,
        Paint()..color = const Color(0xFFFFEE00).withValues(alpha: 0.9),
      );
      // Right: spectral cyan
      canvas.drawCircle(
        Offset(s * 0.17, -s * 0.18),
        s * 0.09,
        Paint()
          ..color = const Color(0xFF00CCFF).withValues(alpha: rfb * 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(
        Offset(s * 0.17, -s * 0.2),
        s * 0.045,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9),
      );

      // Skull-top flame wisps
      for (int i = 0; i < 3; i++) {
        final fi = sin(_time * (5.0 + i * 1.8) + i * 1.1) * s * 0.08;
        canvas.drawCircle(
          Offset((-1 + i) * s * 0.22, -s * 0.62 - fi - s * 0.1),
          s * (0.13 - i * 0.02),
          Paint()
            ..color = [
              const Color(0xFFFF5500),
              const Color(0xFFFF2200),
              const Color(0xFF8800EE),
            ][i].withValues(alpha: 0.45 - i * 0.06)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // VOID EYE
  // ══════════════════════════════════════════════════════════════════════
  void _renderVoidEye(Canvas canvas, double s, Color color, bool flash) {
    // Eldritch aura
    canvas.drawCircle(
      Offset.zero,
      s * 1.05,
      Paint()
        ..color = const Color(0x44880088)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.9),
    );

    if (flash) {
      canvas.drawCircle(Offset.zero, s * 0.5, Paint()..color = Colors.white);
      return;
    }

    // Sclera
    final scleraShader = RadialGradient(
      colors: [const Color(0xFFEEEEDD), const Color(0xFFCCBBAA)],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 0.5));
    canvas.drawCircle(Offset.zero, s * 0.5, Paint()..shader = scleraShader);

    // Blood veins (branches slowly rotating)
    final veinPaint = Paint()
      ..color = const Color(0xFFCC2222).withValues(alpha: 0.45)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 8; i++) {
      final ang = i * pi / 4 + _time * 0.12;
      final branchDist = s * 0.33;
      final endDist = s * 0.44;
      final veinPath = Path()
        ..moveTo(cos(ang) * s * 0.17, sin(ang) * s * 0.17)
        ..quadraticBezierTo(
          cos(ang + 0.12) * branchDist,
          sin(ang + 0.12) * branchDist,
          cos(ang) * endDist,
          sin(ang) * endDist,
        );
      canvas.drawPath(veinPath, veinPaint);
      if (i % 2 == 0) {
        final subAng = ang + 0.18;
        canvas.drawLine(
          Offset(cos(subAng) * s * 0.28, sin(subAng) * s * 0.28),
          Offset(cos(subAng) * s * 0.43, sin(subAng) * s * 0.43),
          veinPaint..color = const Color(0xFFCC2222).withValues(alpha: 0.25),
        );
      }
    }

    // Iris (sweep gradient rotating)
    final irisShader = SweepGradient(
      colors: [
        color,
        color.withValues(alpha: 0.6),
        Palette.fireDeep,
        color,
      ],
      transform: GradientRotation(_time * 0.5),
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 0.23));
    canvas.drawCircle(Offset.zero, s * 0.23, Paint()..shader = irisShader);
    canvas.drawCircle(
      Offset.zero,
      s * 0.17,
      Paint()..color = color.withValues(alpha: 0.75),
    );

    // Rune marks on iris
    final runePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (int r = 0; r < 5; r++) {
      final ra = r * pi * 2 / 5 - _time * 0.75;
      final rx = cos(ra) * s * 0.14;
      final ry = sin(ra) * s * 0.14;
      canvas.drawLine(
        Offset(rx - s * 0.022, ry),
        Offset(rx + s * 0.022, ry),
        runePaint,
      );
      canvas.drawLine(
        Offset(rx, ry - s * 0.022),
        Offset(rx, ry + s * 0.022),
        runePaint,
      );
    }

    // Slit pupil (vertical, reptilian)
    final slitPath = Path()
      ..moveTo(0, -s * 0.12)
      ..cubicTo(-s * 0.024, -s * 0.06, -s * 0.024, s * 0.06, 0, s * 0.12)
      ..cubicTo(s * 0.024, s * 0.06, s * 0.024, -s * 0.06, 0, -s * 0.12)
      ..close();
    canvas.drawPath(slitPath, Paint()..color = const Color(0xFF000000));
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: s * 0.04, height: s * 0.1),
      Paint()
        ..color = const Color(0x88FF2200)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(-s * 0.05, -s * 0.06),
      s * 0.025,
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );

    // 3 Orbiting mini-eyes
    for (int me = 0; me < 3; me++) {
      final meAngle = me * pi * 2 / 3 + _time * 0.65;
      final meX = cos(meAngle) * s * 0.74;
      final meY = sin(meAngle) * s * 0.74;
      canvas.drawCircle(
        Offset(meX, meY),
        s * 0.12,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        Offset(meX, meY),
        s * 0.1,
        Paint()..color = const Color(0xFFE8E4CC),
      );
      canvas.drawCircle(
        Offset(meX, meY),
        s * 0.06,
        Paint()..color = color,
      );
      canvas.drawCircle(
        Offset(meX, meY),
        s * 0.03,
        Paint()..color = const Color(0xFF000000),
      );
    }

    // 4 Tentacle tendrils
    final tentaclePaint = Paint()
      ..color = const Color(0xFF330033).withValues(alpha: 0.7)
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (int t = 0; t < 4; t++) {
      final tAng = t * pi / 2 + _time * 0.28;
      final tWave = sin(_time * 3.0 + t) * 0.28;
      final tPath = Path()
        ..moveTo(cos(tAng) * s * 0.4, sin(tAng) * s * 0.4)
        ..quadraticBezierTo(
          cos(tAng + tWave) * s * 0.7,
          sin(tAng + tWave) * s * 0.7,
          cos(tAng + tWave * 2) * s * 0.95,
          sin(tAng + tWave * 2) * s * 0.95,
        );
      canvas.drawPath(tPath, tentaclePaint);
    }

    // Sclera outline
    canvas.drawCircle(
      Offset.zero,
      s * 0.5,
      Paint()
        ..color = const Color(0xFF331111)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    // Fluid drips
    for (int d = 0; d < 3; d++) {
      final drop = (sin(_time * 1.4 + d * 1.9) * 0.5 + 0.5);
      final dY = s * 0.56 + drop * s * 0.32;
      final dX = (-1 + d) * s * 0.16;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dX, dY),
          width: s * 0.08,
          height: s * 0.14 * drop,
        ),
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // ACID BLOB
  // ══════════════════════════════════════════════════════════════════════
  void _renderAcidBlob(Canvas canvas, double s, Color color, bool flash) {
    // Toxic aura
    canvas.drawCircle(
      Offset(0, s * 0.05),
      s * 0.8,
      Paint()
        ..color = const Color(0xFF00FF44).withValues(
          alpha: 0.07 + 0.03 * sin(_time * 2.8),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.7),
    );

    // Acid drips below body
    if (!flash) {
      for (int d = 0; d < 4; d++) {
        final drip = (sin(_time * 1.2 + d * 1.8) * 0.5 + 0.5);
        final dY = s * 0.5 + drip * s * 0.42;
        final dX = (-1.5 + d) * s * 0.18;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(dX, dY),
            width: s * 0.08,
            height: s * 0.18 * drip,
          ),
          Paint()
            ..color = color.withValues(alpha: 0.65)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    // Outer blob body
    final wobble = sin(_time * 3.0) * s * 0.04;
    final wobble2 = cos(_time * 5.1) * s * 0.03;
    final blobPath = Path()
      ..moveTo(0, -s * 0.5 + wobble)
      ..cubicTo(
        s * 0.36 + wobble2,
        -s * 0.55,
        s * 0.56 + wobble,
        -s * 0.2,
        s * 0.5,
        s * 0.14 + wobble2,
      )
      ..cubicTo(s * 0.44, s * 0.5, -s * 0.44, s * 0.5, -s * 0.5, s * 0.14 + wobble)
      ..cubicTo(
        -s * 0.56 + wobble2,
        -s * 0.2,
        -s * 0.36,
        -s * 0.55 + wobble,
        0,
        -s * 0.5 + wobble,
      )
      ..close();

    canvas.drawPath(
      blobPath,
      Paint()..color = flash ? Colors.white : color.withValues(alpha: 0.72),
    );

    if (!flash) {
      // Inner acid core (radial gradient)
      final coreShader = RadialGradient(
        colors: [
          const Color(0xFFDDFF00).withValues(alpha: 0.9),
          color.withValues(alpha: 0.6),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(
        Rect.fromCircle(center: Offset(0, wobble), radius: s * 0.32),
      );
      canvas.drawCircle(Offset(0, wobble), s * 0.32, Paint()..shader = coreShader);

      // Trapped skull silhouette inside
      final skullPaint = Paint()..color = const Color(0xFF334433).withValues(alpha: 0.45);
      canvas.drawCircle(Offset(s * 0.04, wobble - s * 0.04), s * 0.15, skullPaint);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-s * 0.05 + s * 0.04, wobble - s * 0.07),
          width: s * 0.06,
          height: s * 0.08,
        ),
        Paint()..color = const Color(0xFF001100).withValues(alpha: 0.55),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(s * 0.07 + s * 0.04, wobble - s * 0.07),
          width: s * 0.06,
          height: s * 0.08,
        ),
        Paint()..color = const Color(0xFF001100).withValues(alpha: 0.55),
      );

      // Surface bubbles
      for (int b = 0; b < 7; b++) {
        final bAng = b * pi * 2 / 7 + _time * 0.55;
        final bDist = s * 0.38;
        final bSize = s * (0.038 + 0.018 * sin(_time * 4.0 + b));
        canvas.drawCircle(
          Offset(cos(bAng) * bDist, sin(bAng) * bDist),
          bSize,
          Paint()..color = const Color(0xFF88FF88).withValues(alpha: 0.45),
        );
      }

      // Corruption arc overlays
      for (int a = 0; a < 3; a++) {
        final arcAng = _time * 2.2 + a * pi * 2 / 3;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: s * (0.38 + a * 0.1)),
          arcAng,
          pi * 0.65,
          false,
          Paint()
            ..color = const Color(0xFFAAFF00).withValues(alpha: 0.28)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    // Blob outline
    if (!flash) {
      canvas.drawPath(
        blobPath,
        Paint()
          ..color = const Color(0xFF226622)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // DREAD KNIGHT
  // ══════════════════════════════════════════════════════════════════════
  void _renderDreadKnight(Canvas canvas, double s, Color color, bool flash) {
    // Dark aura
    canvas.drawCircle(
      Offset(0, s * 0.1),
      s * 0.75,
      Paint()
        ..color = const Color(0x33221133)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.65),
    );

    // Ground spectral smoke
    if (!flash) {
      for (int f = 0; f < 3; f++) {
        final fx = (-1 + f) * s * 0.25;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(fx, s * 0.56),
            width: s * 0.22,
            height: s * 0.1,
          ),
          Paint()
            ..color = const Color(0x44551155)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }

    // Animated torn cape (5 strips)
    if (!flash) {
      for (int strip = 0; strip < 5; strip++) {
        final sf = strip / 4.0;
        final capeWave = sin(_time * 2.4 + strip * 0.45) * s * (0.07 + sf * 0.05);
        final capeAlpha = 0.9 - sf * 0.38;
        final capePath = Path()
          ..moveTo(-s * 0.28, -s * 0.12)
          ..cubicTo(
            -s * 0.33 + sf * s * 0.1,
            s * 0.28 + capeWave,
            -s * 0.22 + sf * s * 0.14,
            s * 0.54 + capeWave * 1.3,
            -s * 0.12 + sf * s * 0.18,
            s * 0.74 + capeWave,
          )
          ..lineTo(-s * 0.07 + sf * s * 0.24, s * 0.74 + capeWave)
          ..cubicTo(
            -s * 0.18 + sf * s * 0.18,
            s * 0.48 + capeWave * 1.1,
            -s * 0.28 + sf * s * 0.13,
            s * 0.26 + capeWave * 0.9,
            -s * 0.23,
            -s * 0.1,
          )
          ..close();
        canvas.drawPath(
          capePath,
          Paint()..color = const Color(0xFF1A0A2A).withValues(alpha: capeAlpha),
        );
      }
    }

    final armorColor = flash ? Colors.white : color;

    // Legs
    for (int leg = -1; leg <= 1; leg += 2) {
      final legX = leg * s * 0.15;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(legX, s * 0.44),
          width: s * 0.22,
          height: s * 0.52,
        ),
        Paint()..color = armorColor,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(legX, s * 0.44),
          width: s * 0.22,
          height: s * 0.52,
        ),
        Paint()
          ..color = const Color(0xFF1A1A2A)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      // Knee cap
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(legX, s * 0.24),
          width: s * 0.22,
          height: s * 0.13,
        ),
        Paint()..color = const Color(0xFF4A4A6A),
      );
    }

    // Torso / chest plate
    final torsoRect = Rect.fromCenter(
      center: Offset(0, s * 0.04),
      width: s * 0.66,
      height: s * 0.46,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(s * 0.04)),
      Paint()..color = armorColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(s * 0.04)),
      Paint()
        ..color = const Color(0xFF1A1A2A)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Chest rune glow
    if (!flash) {
      final runeGlow = 0.5 + 0.3 * sin(_time * 2.1);
      canvas.drawCircle(
        Offset(0, s * 0.03),
        s * 0.1,
        Paint()
          ..color = const Color(0xFFFF4400).withValues(alpha: runeGlow * 0.65)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      final rl = Paint()
        ..color = const Color(0xFFFF6600).withValues(alpha: runeGlow * 0.8)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(-s * 0.055, s * 0.18), Offset(-s * 0.04, s * 0.09), rl);
      canvas.drawLine(Offset(s * 0.055, s * 0.18), Offset(s * 0.04, s * 0.09), rl);
      canvas.drawLine(Offset(-s * 0.055, s * 0.18), Offset(s * 0.055, s * 0.18), rl);
    }

    // Shoulder pauldrons
    for (int side = -1; side <= 1; side += 2) {
      final px = side * s * 0.39;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(px, -s * 0.12),
          width: s * 0.3,
          height: s * 0.22,
        ),
        Paint()..color = const Color(0xFF555577),
      );
      // Spike on pauldron
      canvas.drawPath(
        Path()
          ..moveTo(px, -s * 0.22)
          ..lineTo(px - side * s * 0.06, -s * 0.44)
          ..lineTo(px + side * s * 0.06, -s * 0.22)
          ..close(),
        Paint()..color = const Color(0xFF443366),
      );
    }

    // Helmet
    final helmetPath = Path()
      ..moveTo(-s * 0.28, -s * 0.28)
      ..lineTo(-s * 0.28, -s * 0.6)
      ..cubicTo(-s * 0.28, -s * 0.84, s * 0.28, -s * 0.84, s * 0.28, -s * 0.6)
      ..lineTo(s * 0.28, -s * 0.28)
      ..close();
    canvas.drawPath(helmetPath, Paint()..color = flash ? Colors.white : const Color(0xFF4A4A6A));
    canvas.drawPath(
      helmetPath,
      Paint()
        ..color = const Color(0xFF1A1A2A)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    if (!flash) {
      // Demonic horns
      for (int side = -1; side <= 1; side += 2) {
        canvas.drawPath(
          Path()
            ..moveTo(side * s * 0.25, -s * 0.65)
            ..cubicTo(
              side * s * 0.5,
              -s * 0.92,
              side * s * 0.42,
              -s * 1.12,
              side * s * 0.22,
              -s * 0.87,
            )
            ..lineTo(side * s * 0.25, -s * 0.65)
            ..close(),
          Paint()..color = const Color(0xFF221133),
        );
      }

      // Visor slit eyes (two red glowing slits)
      final vg = 0.7 + 0.28 * sin(_time * 3.0);
      for (int e = -1; e <= 1; e += 2) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(e * s * 0.09, -s * 0.5),
            width: s * 0.12,
            height: s * 0.055,
          ),
          Paint()
            ..color = const Color(0xFFFF2200).withValues(alpha: vg)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(e * s * 0.09, -s * 0.5),
            width: s * 0.08,
            height: s * 0.03,
          ),
          Paint()..color = const Color(0xFFFFEE00).withValues(alpha: 0.85),
        );
      }

      // Armor center ridge
      canvas.drawLine(
        Offset(0, -s * 0.28),
        Offset(0, -s * 0.7),
        Paint()
          ..color = const Color(0xFF6A6A8A)
          ..strokeWidth = 1.5,
      );

      // Armor joint smoke
      for (int j = 0; j < 3; j++) {
        final jx = (-1 + j) * s * 0.28;
        final jy = (-0.5 + j * 0.55) * s * 0.3;
        canvas.drawCircle(
          Offset(jx, jy),
          s * 0.11,
          Paint()
            ..color = const Color(0x22441144)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // THE LICH (BOSS)
  // ══════════════════════════════════════════════════════════════════════
  void _renderTheLich(Canvas canvas, double s, Color color, bool flash) {
    final outerPulse = 0.7 + 0.3 * sin(_time * 1.5);

    // Massive outer void
    canvas.drawCircle(
      Offset.zero,
      s * 1.9,
      Paint()
        ..color = Palette.fireDeep.withValues(alpha: 0.07 * outerPulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 1.4),
    );
    canvas.drawCircle(
      Offset.zero,
      s * 1.2,
      Paint()
        ..color = const Color(0xFF110022).withValues(alpha: 0.13)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.45),
    );

    // Billowing cloak
    if (!flash) {
      for (int layer = 0; layer < 5; layer++) {
        final lf = layer / 4.0;
        final cw = sin(_time * 1.8 + layer * 0.7) * s * (0.1 + lf * 0.08);
        final ca = (0.85 - lf * 0.3).clamp(0.0, 1.0);
        final cloakPath = Path()
          ..moveTo(-s * (0.38 - lf * 0.08), s * 0.22)
          ..cubicTo(
            -s * (0.54 + lf * 0.14),
            s * 0.62 + cw,
            -s * (0.38 + lf * 0.18),
            s * 1.32 + cw * 1.4,
            -s * (0.1 + lf * 0.18),
            s * 1.85 + cw,
          )
          ..lineTo(s * (0.1 + lf * 0.18), s * 1.85 + cw)
          ..cubicTo(
            s * (0.38 + lf * 0.18),
            s * 1.32 + cw * 1.4,
            s * (0.54 + lf * 0.14),
            s * 0.62 + cw,
            s * (0.38 - lf * 0.08),
            s * 0.22,
          )
          ..close();
        canvas.drawPath(
          cloakPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A0A2A).withValues(alpha: ca),
                const Color(0xFF0A0010).withValues(alpha: ca * 0.55),
              ],
            ).createShader(
              Rect.fromCenter(center: Offset(0, s), width: s * 2.5, height: s * 2.2),
            ),
        );
      }

      // 3 Orbiting fire orbs
      for (int orb = 0; orb < 3; orb++) {
        final orbAng = _time * 1.2 + orb * pi * 2 / 3;
        final orbX = cos(orbAng) * s * 0.95;
        final orbY = sin(orbAng) * s * 0.52;
        canvas.drawCircle(
          Offset(orbX, orbY),
          s * 0.2,
          Paint()
            ..color = Palette.fireDeep.withValues(alpha: 0.45)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.14),
        );
        canvas.drawCircle(Offset(orbX, orbY), s * 0.12, Paint()..color = Palette.fireGold);
        canvas.drawCircle(Offset(orbX, orbY), s * 0.06, Paint()..color = Palette.fireWhite);
        for (int tr = 1; tr <= 5; tr++) {
          final trAng = orbAng - tr * 0.14;
          final trAlpha = (0.38 - tr * 0.06).clamp(0.0, 1.0);
          canvas.drawCircle(
            Offset(cos(trAng) * s * 0.95, sin(trAng) * s * 0.52),
            s * (0.06 - tr * 0.009).clamp(0.01, 0.1),
            Paint()
              ..color = Palette.fireMid.withValues(alpha: trAlpha)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }

      // Energy rings
      for (int ring = 0; ring < 3; ring++) {
        final ringR = s * (0.58 + ring * 0.14);
        final rp = 0.5 + 0.5 * sin(_time * (2.0 + ring * 0.5) + ring);
        canvas.drawCircle(
          Offset.zero,
          ringR,
          Paint()
            ..color = Palette.fireDeep.withValues(alpha: 0.06 * rp)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.04,
        );
      }
    }

    // Skull shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, s * 0.2),
        width: s * 1.35,
        height: s * 0.26,
      ),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Skull cranium
    final boneColor = flash ? Colors.white : const Color(0xFFE0DBB8);
    final skullPath = Path()
      ..moveTo(-s * 0.58, s * 0.18)
      ..cubicTo(-s * 0.64, -s * 0.08, -s * 0.6, -s * 0.72, 0, -s * 0.78)
      ..cubicTo(s * 0.6, -s * 0.72, s * 0.64, -s * 0.08, s * 0.58, s * 0.18)
      ..close();
    canvas.drawPath(skullPath, Paint()..color = boneColor);

    // Skull cracks
    if (!flash) {
      final cglow = 0.6 + 0.25 * sin(_time * 2.5);
      final crackG = Paint()
        ..color = Palette.fireDeep.withValues(alpha: cglow * 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;
      final crackD = Paint()
        ..color = const Color(0xFF220000)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      final cr1 = Path()
        ..moveTo(0, -s * 0.74)
        ..lineTo(-s * 0.1, -s * 0.52)
        ..lineTo(s * 0.07, -s * 0.3)
        ..lineTo(-s * 0.04, -s * 0.1);
      final cr2 = Path()
        ..moveTo(s * 0.26, -s * 0.58)
        ..lineTo(s * 0.16, -s * 0.36)
        ..lineTo(s * 0.22, -s * 0.2);
      canvas.drawPath(cr1, crackG);
      canvas.drawPath(cr2, crackG..strokeWidth = 2.2);
      canvas.drawPath(cr1, crackD);
      canvas.drawPath(cr2, crackD..strokeWidth = 1.3);
    }

    // Skull glow outline
    canvas.drawPath(
      skullPath,
      Paint()
        ..color = Palette.fireGold.withValues(alpha: 0.2 + 0.15 * sin(_time * 2.0))
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      skullPath,
      Paint()
        ..color = const Color(0xFF332211)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Eye sockets
    final eyeL = Offset(-s * 0.23, -s * 0.26);
    final eyeR = Offset(s * 0.23, -s * 0.26);
    for (final eye in [eyeL, eyeR]) {
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: s * 0.28, height: s * 0.35),
        Paint()..color = const Color(0xFF080808),
      );
    }

    // Eye flames
    if (!flash) {
      // Left eye: hellfire
      for (int l = 0; l < 3; l++) {
        final lf = l / 2.0;
        canvas.drawOval(
          Rect.fromCenter(
            center: eyeL.translate(0, -s * 0.03 * l),
            width: s * 0.28 * (1 - lf * 0.4),
            height: s * 0.35 * (1 - lf * 0.5),
          ),
          Paint()
            ..color = [
              Palette.fireDeep,
              Palette.fireMid,
              Palette.fireGold,
            ][l].withValues(alpha: 0.5 + 0.3 * sin(_time * 4.0 + l))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 - l * 1.0),
        );
      }
      // Right eye: spectral purple
      for (int l = 0; l < 3; l++) {
        final lf = l / 2.0;
        canvas.drawOval(
          Rect.fromCenter(
            center: eyeR.translate(0, -s * 0.03 * l),
            width: s * 0.28 * (1 - lf * 0.4),
            height: s * 0.35 * (1 - lf * 0.5),
          ),
          Paint()
            ..color = [
              const Color(0xFF8800CC),
              const Color(0xFFAA22FF),
              const Color(0xFFCCAAFF),
            ][l].withValues(alpha: 0.5 + 0.3 * sin(_time * 3.5 + l + 1.1))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 - l * 1.0),
        );
      }
    }

    // Floating jaw
    final jawDrop = s * 0.1 + sin(_time * 1.8) * s * 0.09;
    final jawY = s * 0.22 + jawDrop;
    final jawPath = Path()
      ..moveTo(-s * 0.52, jawY)
      ..lineTo(-s * 0.52, jawY + s * 0.28)
      ..cubicTo(
        -s * 0.3,
        jawY + s * 0.38,
        s * 0.3,
        jawY + s * 0.38,
        s * 0.52,
        jawY + s * 0.28,
      )
      ..lineTo(s * 0.52, jawY)
      ..close();
    canvas.drawPath(jawPath, Paint()..color = boneColor);
    canvas.drawPath(
      jawPath,
      Paint()
        ..color = const Color(0xFF332211)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Boss teeth
    if (!flash) {
      final teethB = Paint()..color = const Color(0xFFEEEAD2);
      final tglow = Paint()
        ..color = Palette.fireGold.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      for (int t = -4; t <= 4; t++) {
        final tx = t * s * 0.1;
        final th = s * (t.abs() % 2 == 0 ? 0.24 : 0.17);
        final tp = Path()
          ..moveTo(tx - s * 0.04, jawY)
          ..lineTo(tx, jawY - th)
          ..lineTo(tx + s * 0.04, jawY)
          ..close();
        canvas.drawPath(tp, teethB);
        canvas.drawPath(tp, tglow);
      }
    }

    // Crown
    if (!flash) {
      // Base band
      canvas.drawRect(
        Rect.fromCenter(center: Offset(0, -s * 0.75), width: s * 1.12, height: s * 0.16),
        Paint()
          ..shader = LinearGradient(
            colors: [Palette.fireGold, const Color(0xFFAA8800), Palette.fireGold],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromLTWH(-s * 0.56, -s * 0.75, s * 1.12, s * 0.16),
          ),
      );
      // 5 spikes
      for (int sp = 0; sp < 5; sp++) {
        final sx = (-2 + sp) * s * 0.22;
        final sph = sp == 2 ? s * 0.48 : s * 0.32;
        final spPath = Path()
          ..moveTo(sx - s * 0.1, -s * 0.74)
          ..lineTo(sx, -s * 0.74 - sph)
          ..lineTo(sx + s * 0.1, -s * 0.74)
          ..close();
        canvas.drawPath(
          spPath,
          Paint()
            ..color = Palette.fireGold.withValues(alpha: 0.45)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(spPath, Paint()..color = Palette.fireGold);
        canvas.drawPath(
          spPath,
          Paint()
            ..color = const Color(0xFF664400)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
        // Gem
        final gemColor = [
          const Color(0xFFFF2200),
          const Color(0xFF0088FF),
          const Color(0xFFFFFF00),
          const Color(0xFF00FF44),
          const Color(0xFFAA00FF),
        ][sp];
        final gg = 0.6 + 0.4 * sin(_time * (3.0 + sp) + sp);
        canvas.drawCircle(
          Offset(sx, -s * 0.74 - sph + s * 0.07),
          s * 0.06,
          Paint()
            ..color = gemColor.withValues(alpha: gg)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(
          Offset(sx, -s * 0.74 - sph + s * 0.07),
          s * 0.04,
          Paint()..color = gemColor,
        );
      }

      // Shoulder mini-skulls
      for (int side = -1; side <= 1; side += 2) {
        final msx = side * s * 0.78;
        final msy = -s * 0.1;
        canvas.drawCircle(
          Offset(msx, msy),
          s * 0.19,
          Paint()..color = const Color(0xFFD0CCA8),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(msx - side * s * 0.06, msy - s * 0.02),
            width: s * 0.08,
            height: s * 0.1,
          ),
          Paint()..color = const Color(0xFF111111),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(msx + side * s * 0.06, msy - s * 0.02),
            width: s * 0.08,
            height: s * 0.1,
          ),
          Paint()..color = const Color(0xFF111111),
        );
        final mg = 0.4 + 0.28 * sin(_time * 3.0 + side);
        canvas.drawCircle(
          Offset(msx - side * s * 0.06, msy - s * 0.02),
          s * 0.04,
          Paint()
            ..color = Palette.fireGold.withValues(alpha: mg)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // HP BAR
  // ══════════════════════════════════════════════════════════════════════
  void _renderHpBar(Canvas canvas, double s, double fraction) {
    final isBoss = data.kind == EnemyKind.boss;
    final barW = s * (isBoss ? 1.5 : 1.3);
    final barH = isBoss ? 6.0 : 4.0;
    final yOff = -(s * (isBoss ? 0.88 : 0.72)) - barH - 4.0;

    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, yOff), width: barW, height: barH),
      Paint()..color = const Color(0xBB000000),
    );

    final barColor = fraction > 0.5
        ? Color.lerp(
            const Color(0xFFFFCC00),
            const Color(0xFF44FF44),
            (fraction - 0.5) * 2,
          )!
        : Color.lerp(
            const Color(0xFFCC2222),
            const Color(0xFFFFCC00),
            fraction * 2,
          )!;

    if (fraction > 0) {
      canvas.drawRect(
        Rect.fromLTWH(-barW / 2, yOff - barH / 2, barW * fraction, barH),
        Paint()
          ..color = barColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, yOff), width: barW, height: barH),
      Paint()
        ..color = barColor.withValues(alpha: 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    if (isBoss) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, yOff),
          width: barW * 1.2,
          height: barH * 2.2,
        ),
        Paint()
          ..color = barColor.withValues(alpha: 0.18 + 0.1 * sin(_time * 3.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0),
      );
    }
  }
}
