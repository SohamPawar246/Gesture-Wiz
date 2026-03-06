import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class _Texel {
  Vector2 position;
  Vector2 velocity;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;
  double life;

  _Texel({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
    required this.life,
  });
}

/// Renders a massive burst of chunky, blocky "texels" (pixels) that 
/// explode outward with gravity. Creates a retro DOOM/Minecraft-style 
/// physical gore/blood splat.
class TexelSplat extends PositionComponent {
  final Color baseColor;
  final List<_Texel> _texels = [];
  final Random _rng = Random();

  TexelSplat({required Vector2 position, required this.baseColor})
      : super(position: position.clone(), anchor: Anchor.center) {
    
    // Generate massive amount of chunky pixels
    final numTexels = 40 + _rng.nextInt(30);
    
    for (int i = 0; i < numTexels; i++) {
      // Explode outward in a hemisphere/upward cone
      final angle = _rng.nextDouble() * pi + pi; // PI to 2PI (upwards)
      final speed = _rng.nextDouble() * 600 + 200;
      
      // Randomize color slightly (some lighter/darker shades of base color)
      final shadeMod = (_rng.nextDouble() - 0.5) * 0.4;
      final hsl = HSLColor.fromColor(baseColor);
      final rLightness = (hsl.lightness + shadeMod).clamp(0.1, 0.9);
      final derivedColor = hsl.withLightness(rLightness).toColor();

      _texels.add(_Texel(
        position: Vector2.zero(),
        velocity: Vector2(cos(angle) * speed, sin(angle) * speed),
        size: _rng.nextDouble() * 12 + 8, // Chunky blocks!
        color: derivedColor,
        rotation: _rng.nextDouble() * pi,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 10,
        life: _rng.nextDouble() * 0.8 + 0.4, // Max 1.2 seconds
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_texels.isEmpty) {
      removeFromParent();
      return;
    }

    final gravity = 1200.0 * dt; // Heavy gravity pull

    for (int i = _texels.length - 1; i >= 0; i--) {
      final t = _texels[i];
      t.life -= dt;
      if (t.life <= 0) {
        _texels.removeAt(i);
        continue;
      }

      t.velocity.y += gravity;
      t.position += t.velocity * dt;
      t.rotation += t.rotationSpeed * dt;
      
      // Shrink over time
      t.size = max(0.0, t.size - dt * 10);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Draw without anti-aliasing for true retro chunky texel feel
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (final t in _texels) {
      paint.color = t.color;
      canvas.save();
      canvas.translate(t.position.x, t.position.y);
      canvas.rotate(t.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: t.size, height: t.size),
        paint,
      );
      canvas.restore();
    }
  }
}
