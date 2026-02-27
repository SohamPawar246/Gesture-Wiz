import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

/// Spawns a burst of color-matched particles when an enemy dies.
/// Different patterns per enemy type for satisfying visual feedback.
class DeathPop extends PositionComponent {
  final Color primaryColor;
  final double popScale;

  DeathPop({
    required Vector2 position,
    required this.primaryColor,
    this.popScale = 1.0,
  }) : super(position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    final random = Random();

    // 1. Main color burst — 25 particles
    final mainBurst = ParticleSystemComponent(
      particle: Particle.generate(
        count: 25,
        lifespan: 0.8,
        generator: (i) {
          final speed = random.nextDouble() * 300 + 100;
          final angle = random.nextDouble() * 2 * pi;

          return AcceleratedParticle(
            acceleration: Vector2(0, 200),
            speed: Vector2(cos(angle) * speed, sin(angle) * speed),
            position: Vector2.zero(),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final alpha = (1.0 - particle.progress).clamp(0.0, 1.0);
                final s = 6.0 * popScale * (1.0 - particle.progress * 0.5);

                // Glow
                final glowPaint = Paint()
                  ..color = primaryColor.withValues(alpha: alpha * 0.4)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
                canvas.drawCircle(Offset.zero, s * 1.5, glowPaint);

                // Core
                final paint = Paint()..color = primaryColor.withValues(alpha: alpha);
                canvas.drawCircle(Offset.zero, s, paint);
              },
            ),
          );
        },
      ),
    );
    add(mainBurst);

    // 2. White flash — fast outward ring
    final flashBurst = ParticleSystemComponent(
      particle: Particle.generate(
        count: 10,
        lifespan: 0.4,
        generator: (i) {
          final speed = random.nextDouble() * 500 + 200;
          final angle = random.nextDouble() * 2 * pi;

          return AcceleratedParticle(
            acceleration: Vector2.zero(),
            speed: Vector2(cos(angle) * speed, sin(angle) * speed),
            position: Vector2.zero(),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final alpha = (1.0 - particle.progress).clamp(0.0, 1.0);
                final paint = Paint()
                  ..color = Colors.white.withValues(alpha: alpha * 0.8);
                canvas.drawCircle(Offset.zero, 3.0 * popScale, paint);
              },
            ),
          );
        },
      ),
    );
    add(flashBurst);

    // 3. Expanding shockwave ring
    add(_ShockwaveRing(color: primaryColor, maxRadius: 60.0 * popScale));

    // Auto-remove
    add(TimerComponent(
      period: 1.2,
      removeOnFinish: true,
      onTick: () => removeFromParent(),
    ));
  }
}

class _ShockwaveRing extends PositionComponent {
  final Color color;
  final double maxRadius;
  double _life = 0;

  _ShockwaveRing({required this.color, this.maxRadius = 60});

  @override
  void update(double dt) {
    _life += dt;
    if (_life > 0.5) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final progress = (_life / 0.5).clamp(0.0, 1.0);
    final alpha = (1.0 - progress).clamp(0.0, 1.0);
    final radius = maxRadius * progress;

    final paint = Paint()
      ..color = color.withValues(alpha: alpha * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 * (1.0 - progress)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset.zero, radius, paint);
  }
}
