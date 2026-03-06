import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../systems/hand_tracking/landmark_model.dart';
import '../../systems/hand_tracking/coordinate_mapper.dart';
import '../palette.dart';

/// Renders the player's tracked hand as a thick, cartoonish hand
/// with rounded fleshy fingers, solid palm, bold outlines, and
/// animated fire/ember effects on fingertips.
class VirtualHand extends PositionComponent {
  final Map<int, CircleComponent> _jointComponents = {};

  Color? activeGlowColor;
  bool _isTracked = false;
  final List<Offset> _trailPoints = [];
  final int _maxTrailLen = 14;

  // Animation state
  double _flameTime = 0;

  // Finger bone chains (each list is a connected finger from base to tip)
  static const List<List<int>> _fingerChains = [
    [1, 2, 3, 4],           // Thumb
    [5, 6, 7, 8],           // Index
    [9, 10, 11, 12],        // Middle
    [13, 14, 15, 16],       // Ring
    [17, 18, 19, 20],       // Pinky
  ];

  // Palm polygon
  static const List<int> _palmIndices = [0, 1, 5, 9, 13, 17];

  // Knuckle bridge
  static const List<List<int>> _knuckleBridge = [
    [5, 9], [9, 13], [13, 17],
  ];

  // Fingertip indices
  static const List<int> _fingertips = [4, 8, 12, 16, 20];

  // Finger widths — base (MCP) is wider, tip is narrower
  static const List<double> _segmentWidths = [16.0, 14.0, 12.0, 10.0];

  // Cartoon skin colors
  static const Color _skinBase      = Color(0xFFE8B87A);  // Warm cartoon skin
  static const Color _skinShadow    = Color(0xFFC49456);  // Darker skin shadow
  static const Color _skinHighlight = Color(0xFFF5D4A0);  // Highlight
  static const Color _outline       = Color(0xFF3A2510);  // Bold dark outline
  static const Color _nailColor     = Color(0xFFF0D0B0);  // Fingernail

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
  }

  void updateLandmarks(List<Landmark> landmarks, CoordinateMapper mapper, {double dt = 0.0}) {
    _flameTime += dt;
    
    if (landmarks.length != 21) {
      _isTracked = false;
      return;
    }
    _isTracked = true;

    for (int i = 0; i < 21; i++) {
      final targetScreenPosition = mapper.mapLandmarkToScreen(landmarks[i]);

      if (dt > 0 && _jointComponents[i]!.position != Vector2.zero()) {
        // 28.0 factor: at 60fps (dt≈0.016) → lerp t≈0.45 per frame
        // Hand visually catches up in ~2-3 frames (~35ms) — feels instant
        _jointComponents[i]!.position.lerp(targetScreenPosition, (dt * 28.0).clamp(0.0, 1.0));
      } else {
        _jointComponents[i]!.position = targetScreenPosition;
      }
    }
  }

  Offset _pos(int i) => _jointComponents[i]!.position.toOffset();

  double _flicker(int seed) {
    return 0.7 + 0.3 * sin(_flameTime * (6.0 + seed * 0.7) + seed * 1.3);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isTracked && _jointComponents[8] != null) {
      final currentPos = _pos(8); // Index fingertip
      if (_trailPoints.isEmpty || (_trailPoints.last - currentPos).distance > 4.0) {
        _trailPoints.add(currentPos);
        if (_trailPoints.length > _maxTrailLen) _trailPoints.removeAt(0);
      }
    } else {
      if (_trailPoints.isNotEmpty) _trailPoints.removeAt(0);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // ======================================================
    // LAYER 0: MAGIC MOTION TRAIL (Always draw if fading)
    // ======================================================
    if (_trailPoints.length > 1) {
      final trailColor = activeGlowColor ?? Palette.fireGold;
      for (int i = 0; i < _trailPoints.length - 1; i++) {
        final double progress = i / (_trailPoints.length - 1);
        final paint = Paint()
          ..color = trailColor.withValues(alpha: progress * 0.7)
          ..strokeWidth = progress * 16.0 + 4.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawLine(_trailPoints[i], _trailPoints[i + 1], paint);
      }
    }

    if (!_isTracked) return; // Hide physical hand if not tracked

    // ======================================================
    // LAYER 1: WARM AMBIENT GLOW (behind everything)
    // ======================================================
    final glowColor = activeGlowColor ?? Palette.glowWarm;
    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.12 + 0.03 * sin(_flameTime * 2.5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30.0);

    // Glow around the palm center
    final palmCenter = _palmCenterOffset();
    canvas.drawCircle(palmCenter, 80.0, glowPaint);

    // ======================================================
    // LAYER 2: PALM (filled cartoon shape with outline)
    // ======================================================
    _renderPalm(canvas);

    // ======================================================
    // LAYER 3: KNUCKLE BRIDGES (thick cartoon connectors)
    // ======================================================
    for (final bridge in _knuckleBridge) {
      _renderFingerSegment(canvas, _pos(bridge[0]), _pos(bridge[1]), 14.0, 14.0);
    }

    // ======================================================
    // LAYER 4: FINGERS (thick rounded cartoon segments)
    // ======================================================
    for (final chain in _fingerChains) {
      for (int j = 0; j < chain.length - 1; j++) {
        final baseWidth = _segmentWidths[j];
        final tipWidth = _segmentWidths[j + 1];
        _renderFingerSegment(canvas, _pos(chain[j]), _pos(chain[j + 1]), baseWidth, tipWidth);
      }
    }

    // ======================================================
    // LAYER 5: KNUCKLE DIMPLES (cartoon joint dots)
    // ======================================================
    for (int i = 0; i < 21; i++) {
      if (_fingertips.contains(i) || i == 0) continue;
      final pos = _pos(i);
      // Small shadow dimple for cartoon joint
      final dimplePaint = Paint()
        ..color = _skinShadow.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawCircle(pos, 3.5, dimplePaint);
    }

    // ======================================================
    // LAYER 6: FINGERTIPS — cartoon rounded caps + fire
    // ======================================================
    for (final tipIdx in _fingertips) {
      _renderCartoonTip(canvas, tipIdx);
    }

    // ======================================================
    // LAYER 7: WRIST (large cartoon base)
    // ======================================================
    _renderWrist(canvas);
  }

  /// Renders the palm as a filled, outlined polygon
  void _renderPalm(Canvas canvas) {
    final palmPath = Path();
    palmPath.moveTo(_pos(_palmIndices[0]).dx, _pos(_palmIndices[0]).dy);
    for (int i = 1; i < _palmIndices.length; i++) {
      palmPath.lineTo(_pos(_palmIndices[i]).dx, _pos(_palmIndices[i]).dy);
    }
    palmPath.close();

    // Shadow fill
    final shadowPaint = Paint()
      ..color = _skinShadow
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(2, 3);
    canvas.drawPath(palmPath, shadowPaint);
    canvas.restore();

    // Main skin fill
    final fillPaint = Paint()
      ..color = _skinBase
      ..style = PaintingStyle.fill;
    canvas.drawPath(palmPath, fillPaint);

    // Highlight on upper palm
    final highlightPaint = Paint()
      ..color = _skinHighlight.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    
    // Draw a smaller highlight polygon (offset toward fingertips)
    final highlightPath = Path();
    highlightPath.moveTo(_pos(5).dx, _pos(5).dy);
    highlightPath.lineTo(_pos(9).dx, _pos(9).dy);
    highlightPath.lineTo(_pos(13).dx, _pos(13).dy);
    highlightPath.close();
    canvas.drawPath(highlightPath, highlightPaint);

    // Bold outline
    final outlinePaint = Paint()
      ..color = _outline
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(palmPath, outlinePaint);
  }

  /// Renders a single finger segment as a thick tapered capsule with outline
  void _renderFingerSegment(Canvas canvas, Offset from, Offset to, double baseW, double tipW) {
    // Direction and perpendicular vectors
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 1.0) return;

    final nx = -dy / len; // Perpendicular
    final ny = dx / len;

    // Build a tapered quad (trapezoid shape for each bone segment)
    final path = Path();
    path.moveTo(from.dx + nx * baseW / 2, from.dy + ny * baseW / 2);
    path.lineTo(to.dx + nx * tipW / 2, to.dy + ny * tipW / 2);
    path.lineTo(to.dx - nx * tipW / 2, to.dy - ny * tipW / 2);
    path.lineTo(from.dx - nx * baseW / 2, from.dy - ny * baseW / 2);
    path.close();

    // Shadow (offset)
    final shadowPaint = Paint()
      ..color = _skinShadow.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(1.5, 2.0);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Main fill
    final fillPaint = Paint()
      ..color = _skinBase
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Highlight stripe along the center
    final highlightPaint = Paint()
      ..color = _skinHighlight.withValues(alpha: 0.35)
      ..strokeWidth = baseW * 0.25
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawLine(
      Offset(from.dx, from.dy),
      Offset(to.dx, to.dy),
      highlightPaint,
    );

    // Bold outline
    final outlinePaint = Paint()
      ..color = _outline
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, outlinePaint);

    // Rounded caps at each end
    final capFill = Paint()..color = _skinBase;
    final capOutline = Paint()
      ..color = _outline
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(from, baseW / 2 - 1, capFill);
    canvas.drawCircle(to, tipW / 2 - 1, capFill);
    canvas.drawCircle(from, baseW / 2 - 1, capOutline);
    canvas.drawCircle(to, tipW / 2 - 1, capOutline);
  }

  /// Renders a cartoonish fingertip with rounded cap, nail, and fire effect
  void _renderCartoonTip(Canvas canvas, int tipIdx) {
    final pos = _pos(tipIdx);
    final flicker = _flicker(tipIdx);

    // 1. Rounded cartoon tip (filled circle)
    final tipFill = Paint()..color = _skinBase;
    canvas.drawCircle(pos, 7.0, tipFill);

    // Tip outline
    final tipOutline = Paint()
      ..color = _outline
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(pos, 7.0, tipOutline);

    // 2. Small fingernail highlight
    final nailPaint = Paint()
      ..color = _nailColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
    canvas.drawCircle(pos.translate(0, -2), 3.5, nailPaint);

    // 3. Fire effect on top of the fingertip!
    _renderFingerFlame(canvas, pos, tipIdx, flicker);
  }

  /// Renders animated fire above a fingertip
  void _renderFingerFlame(Canvas canvas, Offset pos, int idx, double flicker) {
    // Layer 1: Wide outer glow
    final outerGlow = Paint()
      ..color = Palette.fireDeep.withValues(alpha: 0.18 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0);
    canvas.drawCircle(pos.translate(0, -10 * flicker), 18.0 * flicker, outerGlow);

    // Layer 2: Mid flame body
    final midFlame = Paint()
      ..color = Palette.fireMid.withValues(alpha: 0.45 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0);
    canvas.drawCircle(pos.translate(0, -14 * flicker), 11.0 * flicker, midFlame);

    // Layer 3: Bright gold core
    final goldCore = Paint()
      ..color = Palette.fireGold.withValues(alpha: 0.65 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(pos.translate(0, -12 * flicker), 6.0, goldCore);

    // Layer 4: White-hot center
    final whiteCore = Paint()
      ..color = Palette.fireWhite.withValues(alpha: 0.85);
    canvas.drawCircle(pos.translate(0, -11 * flicker), 2.5, whiteCore);

    // Layer 5: Upward flame wisp
    final wispPath = Path();
    final wispH = 10.0 + 6.0 * flicker;
    final sway = 2.0 * sin(_flameTime * 8.0 + idx);
    wispPath.moveTo(pos.dx - 3.5, pos.dy - 8);
    wispPath.quadraticBezierTo(
      pos.dx + sway,
      pos.dy - 8 - wispH,
      pos.dx + 3.5,
      pos.dy - 8,
    );
    wispPath.close();

    final wispPaint = Paint()
      ..color = Palette.fireBright.withValues(alpha: 0.25 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(wispPath, wispPaint);
  }

  /// Renders the wrist as a large cartoon base with warm glow
  void _renderWrist(Canvas canvas) {
    final pos = _pos(0);

    // Shadow
    final shadowPaint = Paint()
      ..color = _skinShadow.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(pos.translate(2, 3), 12.0, shadowPaint);

    // Main fill
    final fillPaint = Paint()..color = _skinBase;
    canvas.drawCircle(pos, 12.0, fillPaint);

    // Highlight
    final highlightPaint = Paint()
      ..color = _skinHighlight.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawCircle(pos.translate(-2, -2), 6.0, highlightPaint);

    // Outline
    final outlinePaint = Paint()
      ..color = _outline
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(pos, 12.0, outlinePaint);

    // Warm ember glow on wrist
    final emberGlow = Paint()
      ..color = Palette.fireDeep.withValues(alpha: 0.15 + 0.05 * sin(_flameTime * 2.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16.0);
    canvas.drawCircle(pos, 24.0, emberGlow);
  }

  /// Returns the averaged center of the palm polygon
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
