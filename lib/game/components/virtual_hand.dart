import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../systems/hand_tracking/landmark_model.dart';
import '../../systems/hand_tracking/coordinate_mapper.dart';
import '../../systems/gesture/gesture_type.dart';
import '../palette.dart';

/// Renders the player's tracked hand as a realistic human-ish hand
/// with a subtle magical fire overlay.
class VirtualHand extends PositionComponent {
  final Map<int, CircleComponent> _jointComponents = {};

  Color? activeGlowColor;
  double gestureConfidence = 0.0;
  GestureType activeGestureType = GestureType.none;
  bool _isTracked = false;
  final List<Offset> _trailPoints = [];
  final int _maxTrailLen = 14;

  double _flameTime = 0;

  // Finger bone chains
  static const List<List<int>> _fingerChains = [
    [1, 2, 3, 4], // Thumb
    [5, 6, 7, 8], // Index
    [9, 10, 11, 12], // Middle
    [13, 14, 15, 16], // Ring
    [17, 18, 19, 20], // Pinky
  ];

  static const List<int> _palmIndices = [0, 1, 5, 9, 13, 17];
  static const List<List<int>> _knuckleBridge = [
    [5, 9],
    [9, 13],
    [13, 17],
  ];
  static const List<int> _fingertips = [4, 8, 12, 16, 20];
  static const List<double> _segmentWidths = [13.0, 11.0, 9.0, 7.0];

  // ── Skin tone palette ─────────────────────────────────────────────────
  static const Color _skinBase  = Color(0xFFD4A574);
  static const Color _skinLight = Color(0xFFEDD5B0);
  static const Color _skinShadow = Color(0xFF9A6038);
  static const Color _skinMid   = Color(0xFFC28A58);
  static const Color _nailColor = Color(0xFFEEDCC8);
  static const Color _nailLine  = Color(0xFFB89070);

  // Ember particles (fire magic floating off palm)
  final List<_EmberParticle> _embers = [];
  final Random _rng = Random();

  VirtualHand() {
    for (int i = 0; i < 21; i++) {
      final joint = CircleComponent(
        radius: 1.0,
        paint: Paint()..color = Colors.transparent,
        anchor: Anchor.center,
      );
      _jointComponents[i] = joint;
      add(joint);
    }
    for (int i = 0; i < 8; i++) {
      _embers.add(_EmberParticle.random(_rng));
    }
  }

  void updateLandmarks(
    List<Landmark> landmarks,
    CoordinateMapper mapper, {
    double dt = 0.0,
  }) {
    _flameTime += dt;

    if (landmarks.length != 21) {
      _isTracked = false;
      return;
    }
    _isTracked = true;

    for (int i = 0; i < 21; i++) {
      final targetScreenPosition = mapper.mapLandmarkToScreen(landmarks[i]);
      if (dt > 0 && _jointComponents[i]!.position != Vector2.zero()) {
        _jointComponents[i]!.position.lerp(
          targetScreenPosition,
          (dt * 45.0).clamp(0.0, 1.0),
        );
      } else {
        _jointComponents[i]!.position = targetScreenPosition;
      }
    }
  }

  Offset _pos(int i) => _jointComponents[i]!.position.toOffset();

  double _flicker(int seed) =>
      0.65 + 0.35 * sin(_flameTime * (5.5 + seed * 0.8) + seed * 1.7);

  @override
  void update(double dt) {
    super.update(dt);

    if (_isTracked && _jointComponents[8] != null) {
      final currentPos = _pos(8);
      if (_trailPoints.isEmpty ||
          (_trailPoints.last - currentPos).distance > 3.5) {
        _trailPoints.add(currentPos);
        if (_trailPoints.length > _maxTrailLen) _trailPoints.removeAt(0);
      }
    } else {
      if (_trailPoints.isNotEmpty) _trailPoints.removeAt(0);
    }

    for (final e in _embers) {
      e.update(dt);
      if (e.life <= 0 && _isTracked) {
        e.respawn(_rng, _palmCenterOffset());
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // ══════════════════════════════════════════════════════════════
    // LAYER 0: MAGIC MOTION TRAIL (index fingertip)
    // ══════════════════════════════════════════════════════════════
    if (_trailPoints.length > 1) {
      final trailColor = activeGlowColor ?? Palette.fireGold;
      for (int i = 0; i < _trailPoints.length - 1; i++) {
        final progress = i / (_trailPoints.length - 1);
        canvas.drawLine(
          _trailPoints[i],
          _trailPoints[i + 1],
          Paint()
            ..color = trailColor.withValues(alpha: progress * 0.45)
            ..strokeWidth = progress * 12.0 + 1.0
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0),
        );
      }
    }

    if (!_isTracked) return;

    final accent = activeGlowColor ?? Palette.fireDeep;

    // ══════════════════════════════════════════════════════════════
    // LAYER 1: VERY SOFT OUTER MAGIC AURA
    // ══════════════════════════════════════════════════════════════
    final palmCenter = _palmCenterOffset();
    final auraPulse = 0.8 + 0.2 * sin(_flameTime * 2.2);
    canvas.drawCircle(
      palmCenter,
      75.0,
      Paint()
        ..color = accent.withValues(alpha: 0.04 * auraPulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 38.0 * auraPulse),
    );

    // ══════════════════════════════════════════════════════════════
    // LAYER 2: SKIN PALM
    // ══════════════════════════════════════════════════════════════
    _renderSkinPalm(canvas, accent);

    // ══════════════════════════════════════════════════════════════
    // LAYER 3: KNUCKLE BRIDGES
    // ══════════════════════════════════════════════════════════════
    for (final bridge in _knuckleBridge) {
      _renderSkinSegment(
          canvas, _pos(bridge[0]), _pos(bridge[1]), 11.0, 11.0, accent);
    }

    // ══════════════════════════════════════════════════════════════
    // LAYER 4: FINGER BONES
    // ══════════════════════════════════════════════════════════════
    for (final chain in _fingerChains) {
      for (int j = 0; j < chain.length - 1; j++) {
        _renderSkinSegment(
          canvas,
          _pos(chain[j]),
          _pos(chain[j + 1]),
          _segmentWidths[j],
          _segmentWidths[j + 1],
          accent,
        );
      }
    }

    // ══════════════════════════════════════════════════════════════
    // LAYER 5: KNUCKLE JOINTS
    // ══════════════════════════════════════════════════════════════
    for (int i = 1; i < 21; i++) {
      if (_fingertips.contains(i)) continue;
      _renderKnuckle(canvas, _pos(i), _jointRadius(i), accent);
    }

    // ══════════════════════════════════════════════════════════════
    // LAYER 6: FINGERTIPS + NAILS
    // ══════════════════════════════════════════════════════════════
    for (final tipIdx in _fingertips) {
      _renderFingertip(canvas, tipIdx, accent);
    }

    // ══════════════════════════════════════════════════════════════
    // LAYER 7: WRIST
    // ══════════════════════════════════════════════════════════════
    _renderWrist(canvas, accent);

    // ══════════════════════════════════════════════════════════════
    // LAYER 8: FLOATING MAGIC EMBERS
    // ══════════════════════════════════════════════════════════════
    for (final e in _embers) {
      if (e.life <= 0) continue;
      final alpha = (e.life / e.maxLife).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(e.x, e.y),
        e.size * alpha,
        Paint()
          ..color = e.color.withValues(alpha: alpha * 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );
    }

    // ══════════════════════════════════════════════════════════════
    // LAYER 9: GESTURE CHARGE RING
    // ══════════════════════════════════════════════════════════════
    if (gestureConfidence > 0.3 && activeGestureType != GestureType.none &&
        activeGestureType != GestureType.openPalm) {
      final chargeProgress = ((gestureConfidence - 0.3) / 0.7).clamp(0.0, 1.0);
      final ringRadius = 35.0 + chargeProgress * 15.0;
      final ringAlpha = chargeProgress * 0.6;
      final ringColor = activeGlowColor ?? Palette.fireGold;

      // Spinning arc that fills as confidence approaches 1.0
      canvas.drawArc(
        Rect.fromCircle(center: palmCenter, radius: ringRadius),
        _flameTime * 3.0,
        chargeProgress * 2 * pi,
        false,
        Paint()
          ..color = ringColor.withValues(alpha: ringAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
      );

      // Inner bright arc (thinner, brighter)
      if (chargeProgress > 0.6) {
        final innerAlpha = ((chargeProgress - 0.6) / 0.4) * 0.8;
        canvas.drawArc(
          Rect.fromCircle(center: palmCenter, radius: ringRadius - 4.0),
          _flameTime * -4.5,
          chargeProgress * 1.8 * pi,
          false,
          Paint()
            ..color = Colors.white.withValues(alpha: innerAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  double _jointRadius(int landmark) {
    if (landmark == 1 || landmark == 5 || landmark == 9 ||
        landmark == 13 || landmark == 17) { return 5.5; } // MCP knuckles
    if (landmark == 2 || landmark == 6 || landmark == 10 ||
        landmark == 14 || landmark == 18) { return 4.2; } // PIP knuckles
    if (landmark == 3 || landmark == 7 || landmark == 11 ||
        landmark == 15 || landmark == 19) { return 3.2; } // DIP knuckles
    return 3.0;
  }

  // ── Skin Palm ─────────────────────────────────────────────────────────
  void _renderSkinPalm(Canvas canvas, Color accent) {
    final path = Path();
    path.moveTo(_pos(_palmIndices[0]).dx, _pos(_palmIndices[0]).dy);
    for (int i = 1; i < _palmIndices.length; i++) {
      path.lineTo(_pos(_palmIndices[i]).dx, _pos(_palmIndices[i]).dy);
    }
    path.close();

    // Base skin fill
    canvas.drawPath(path, Paint()
      ..color = _skinBase
      ..style = PaintingStyle.fill);

    // Soft inner highlight (3D palm "mound" illusion)
    final palmCenter = _palmCenterOffset();
    canvas.drawCircle(
      palmCenter,
      28.0,
      Paint()
        ..color = _skinLight.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0)
        ..style = PaintingStyle.fill,
    );

    // Edge shadow
    canvas.drawPath(
      path,
      Paint()
        ..color = _skinShadow.withValues(alpha: 0.55)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    // Subtle magic glow overlay
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(
            alpha: 0.05 + 0.03 * sin(_flameTime * 3.0))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0),
    );
  }

  // ── Skin Finger Segment ───────────────────────────────────────────────
  void _renderSkinSegment(
    Canvas canvas,
    Offset from,
    Offset to,
    double baseW,
    double tipW,
    Color accent,
  ) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1.0) return;

    final nx = -dy / len;
    final ny = dx / len;

    final path = Path();
    path.moveTo(from.dx + nx * baseW / 2, from.dy + ny * baseW / 2);
    path.lineTo(to.dx + nx * tipW / 2, to.dy + ny * tipW / 2);
    path.lineTo(to.dx - nx * tipW / 2, to.dy - ny * tipW / 2);
    path.lineTo(from.dx - nx * baseW / 2, from.dy - ny * baseW / 2);
    path.close();

    // Skin fill
    canvas.drawPath(path, Paint()
      ..color = _skinBase
      ..style = PaintingStyle.fill);

    // Cylindrical center highlight streak
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = _skinLight.withValues(alpha: 0.55)
        ..strokeWidth = tipW * 0.4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // Edge shadow (gives 3D roundness)
    canvas.drawPath(
      path,
      Paint()
        ..color = _skinShadow.withValues(alpha: 0.5)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    // Very subtle magic energy vein
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = accent.withValues(
            alpha: 0.12 + 0.07 * sin(_flameTime * 5 + from.dx))
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  // ── Knuckle Joint ─────────────────────────────────────────────────────
  void _renderKnuckle(Canvas canvas, Offset pos, double r, Color accent) {
    // Skin fill
    canvas.drawCircle(pos, r, Paint()..color = _skinMid);

    // Off-center highlight
    canvas.drawCircle(
      pos.translate(-r * 0.25, -r * 0.3),
      r * 0.45,
      Paint()..color = _skinLight.withValues(alpha: 0.55),
    );

    // Dark rim
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = _skinShadow
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke,
    );

    // Faint magic glow
    canvas.drawCircle(
      pos,
      r + 2.5,
      Paint()
        ..color = accent.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  // ── Fingertip + Nail ──────────────────────────────────────────────────
  void _renderFingertip(Canvas canvas, int tipIdx, Color accent) {
    final pos = _pos(tipIdx);
    final prevIdx = tipIdx - 1;
    final prev = _pos(prevIdx);

    final dx = pos.dx - prev.dx;
    final dy = pos.dy - prev.dy;
    final len = max(sqrt(dx * dx + dy * dy), 1.0);
    final ux = dx / len; // unit along finger direction
    final uy = dy / len;

    final r = _segmentWidths[3] / 2 + 1.5; // ~5.0

    // Rounded fingertip cap
    canvas.drawCircle(pos, r, Paint()..color = _skinBase);

    // Highlight
    canvas.drawCircle(
      pos.translate(-r * 0.25, -r * 0.3),
      r * 0.45,
      Paint()..color = _skinLight.withValues(alpha: 0.6),
    );

    // Rim shadow
    canvas.drawCircle(
      pos,
      r,
      Paint()
        ..color = _skinShadow
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // Fingernail — small rounded rect sitting above the tip pad,
    // rotated to face the finger direction.
    final nailCx = pos.dx + ux * r * 0.35;
    final nailCy = pos.dy + uy * r * 0.35;
    final nailW = r * 1.3;
    final nailH = r * 0.7;
    final angle = atan2(uy, ux) - pi / 2;

    canvas.save();
    canvas.translate(nailCx, nailCy);
    canvas.rotate(angle);
    final nailRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: nailW, height: nailH),
      Radius.circular(nailH * 0.45),
    );
    canvas.drawRRect(nailRRect, Paint()..color = _nailColor);
    canvas.drawRRect(
      nailRRect,
      Paint()
        ..color = _nailLine
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );
    // Small glint on nail
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(-nailW * 0.1, -nailH * 0.2),
          width: nailW * 0.35,
          height: nailH * 0.3),
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );
    canvas.restore();

    // Subtle magic flame above the fingertip (not a full inferno — just a hint)
    final flicker = _flicker(tipIdx);
    canvas.drawCircle(
      pos.translate(ux * r * 0.5, uy * r * 0.5),
      r * 0.9 * flicker,
      Paint()
        ..color = accent.withValues(alpha: 0.2 * flicker)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0),
    );
    // White-hot nucleus dot
    canvas.drawCircle(
      pos,
      1.8,
      Paint()..color = Palette.fireWhite.withValues(alpha: 0.45 * flicker),
    );
  }

  // ── Wrist ─────────────────────────────────────────────────────────────
  void _renderWrist(Canvas canvas, Color accent) {
    final pos = _pos(0);

    canvas.drawCircle(pos, 13.0, Paint()..color = _skinBase);

    // Highlight
    canvas.drawCircle(
      pos.translate(-3, -4),
      7.0,
      Paint()..color = _skinLight.withValues(alpha: 0.4),
    );

    // Rim
    canvas.drawCircle(
      pos,
      13.0,
      Paint()
        ..color = _skinShadow
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    // Magic wrist glow
    final pulse = 0.75 + 0.25 * sin(_flameTime * 3.0);
    canvas.drawCircle(
      pos,
      17.0 * pulse,
      Paint()
        ..color = accent.withValues(alpha: 0.10 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0),
    );
  }

  Offset _palmCenterOffset() {
    double cx = 0, cy = 0;
    for (final idx in _palmIndices) {
      final p = _pos(idx);
      cx += p.dx;
      cy += p.dy;
    }
    return Offset(cx / _palmIndices.length, cy / _palmIndices.length);
  }
}

// ── Floating ember particle ────────────────────────────────────────────
class _EmberParticle {
  double x, y, vx, vy, size, life, maxLife;
  final Color color;
  static const List<Color> _colors = [
    Palette.fireDeep,
    Palette.fireMid,
    Palette.fireGold,
    Palette.fireBright,
  ];

  _EmberParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.maxLife,
    required this.color,
  });

  factory _EmberParticle.random(Random rng) => _EmberParticle(
        x: 0,
        y: 0,
        vx: (rng.nextDouble() - 0.5) * 30,
        vy: -(10 + rng.nextDouble() * 40),
        size: 1.5 + rng.nextDouble() * 2.5,
        life: 0,
        maxLife: 0,
        color: _colors[rng.nextInt(_colors.length)],
      );

  void respawn(Random rng, Offset center) {
    x = center.dx + (rng.nextDouble() - 0.5) * 40;
    y = center.dy + (rng.nextDouble() - 0.5) * 30;
    vx = (rng.nextDouble() - 0.5) * 30;
    vy = -(12 + rng.nextDouble() * 40);
    size = 1.2 + rng.nextDouble() * 2.5;
    maxLife = 0.4 + rng.nextDouble() * 0.7;
    life = maxLife;
  }

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 15 * dt;
    vx *= 1 - dt * 2;
    life -= dt;
    size -= dt * 1.5;
  }
}
