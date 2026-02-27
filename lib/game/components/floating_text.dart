import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// Floating text that drifts upward and fades out.
/// Used for damage numbers, score popups, combo text, etc.
class FloatingText extends PositionComponent {
  final String text;
  final Color color;
  final double fontSize;
  double _life = 0;
  final double duration;

  FloatingText({
    required Vector2 position,
    required this.text,
    this.color = Palette.fireGold,
    this.fontSize = 20,
    this.duration = 1.5,
  }) : super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    position.y -= 60 * dt; // Float upward
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final alpha = (1.0 - (_life / duration)).clamp(0.0, 1.0);
    final scale = 1.0 + _life * 0.3; // Slight scale up

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: alpha),
          fontSize: fontSize * scale,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 2.0,
          shadows: [
            Shadow(
              blurRadius: 8,
              color: Colors.black.withValues(alpha: alpha * 0.8),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
  }
}
