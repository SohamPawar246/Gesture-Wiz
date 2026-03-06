import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// Renders a glowing progress ring around a target position (e.g. hand or center screen).
/// Visually indicates how much time is left in the combo timeout window.
class ComboRing extends PositionComponent {
  double progress = 0.0; // 0.0 (full) to 1.0 (empty)
  Color ringColor = Palette.fireGold;

  ComboRing() : super(anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (progress <= 0 || progress >= 1.0) return; // Only draw when active

    final radius = 60.0;
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);

    // Background track (faint)
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(Offset.zero, radius, trackPaint);

    // Foreground sweeping arc
    final sweepAngle = 2 * pi * (1.0 - progress);
    final arcPaint = Paint()
      ..color = ringColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    // Custom start angle (top = -pi/2)
    canvas.drawArc(rect, -pi / 2, sweepAngle, false, arcPaint);
  }
}
