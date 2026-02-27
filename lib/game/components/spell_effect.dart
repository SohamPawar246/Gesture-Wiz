import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flame/particles.dart';

import '../palette.dart';

/// Fire-themed spell effect in the Jon Wick retro aesthetic.
/// Spawns a particle burst + floating spell name + lingering ember trail.
class SpellEffect extends PositionComponent {
  final Color effectColor;
  final String spellName;

  SpellEffect({
    required Vector2 position,
    required this.effectColor,
    required this.spellName,
  }) : super(position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // 1. Spell Name — floating text with warm glow
    final textComp = TextComponent(
      text: spellName.toUpperCase(),
      textRenderer: TextPaint(
        style: TextStyle(
          color: Palette.fireGold,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 3.0,
          shadows: const [
            Shadow(blurRadius: 12, color: Palette.fireDeep),
            Shadow(blurRadius: 24, color: Palette.fireDeep),
          ],
        ),
      ),
      anchor: Anchor.center,
      position: Vector2(0, -70),
    );
    add(textComp);

    // 2. Main Fire Burst — large explosive particles
    final random = Random();
    final mainBurst = ParticleSystemComponent(
      particle: Particle.generate(
        count: 60,
        lifespan: 1.8,
        generator: (i) {
          final speed = random.nextDouble() * 250 + 80;
          final angle = random.nextDouble() * 2 * pi;
          final vx = cos(angle) * speed;
          final vy = sin(angle) * speed;
          
          // Blend between spell color and fire gold
          final t = random.nextDouble();
          final particleColor = Color.lerp(effectColor, Palette.fireGold, t)!;

          return AcceleratedParticle(
            acceleration: Vector2(0, 120), // Gravity
            speed: Vector2(vx, vy),
            position: Vector2.zero(),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final progress = particle.progress;
                final alpha = (1.0 - progress).clamp(0.0, 1.0);
                final size = (10.0 * (1.0 - progress * 0.5));

                // Outer glow
                final glowPaint = Paint()
                  ..color = particleColor.withValues(alpha: alpha * 0.3)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
                canvas.drawCircle(Offset.zero, size * 2.0, glowPaint);

                // Core
                final paint = Paint()
                  ..color = particleColor.withValues(alpha: alpha)
                  ..style = PaintingStyle.fill;
                canvas.drawCircle(Offset.zero, size, paint);

                // White-hot center (early particles)
                if (progress < 0.3) {
                  final whitePaint = Paint()
                    ..color = Palette.fireWhite.withValues(alpha: alpha * 0.8);
                  canvas.drawCircle(Offset.zero, size * 0.4, whitePaint);
                }
              },
            ),
          );
        },
      ),
    );
    add(mainBurst);

    // 3. Spark Streaks — fast, thin sparks shooting outward
    final sparkBurst = ParticleSystemComponent(
      particle: Particle.generate(
        count: 20,
        lifespan: 0.8,
        generator: (i) {
          final speed = random.nextDouble() * 400 + 200;
          final angle = random.nextDouble() * 2 * pi;
          
          return AcceleratedParticle(
            acceleration: Vector2(0, 200),
            speed: Vector2(cos(angle) * speed, sin(angle) * speed),
            position: Vector2.zero(),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final alpha = (1.0 - particle.progress).clamp(0.0, 1.0);
                final paint = Paint()
                  ..color = Palette.fireBright.withValues(alpha: alpha)
                  ..strokeWidth = 2.0
                  ..strokeCap = StrokeCap.round;
                // Draw a short streak
                canvas.drawLine(
                  Offset.zero,
                  Offset(cos(angle) * 8, sin(angle) * 8),
                  paint,
                );
              },
            ),
          );
        },
      ),
    );
    add(sparkBurst);

    // 4. Lingering Embers — slow, floating upward
    final emberTrail = ParticleSystemComponent(
      particle: Particle.generate(
        count: 15,
        lifespan: 2.5,
        generator: (i) {
          final drift = (random.nextDouble() - 0.5) * 60;
          
          return AcceleratedParticle(
            acceleration: Vector2(0, -30), // Float upward
            speed: Vector2(drift, -random.nextDouble() * 40 - 20),
            position: Vector2(
              (random.nextDouble() - 0.5) * 40,
              (random.nextDouble() - 0.5) * 40,
            ),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final alpha = (1.0 - particle.progress) * 0.7;
                final size = 2.0 + random.nextDouble() * 2.0;
                
                final glowPaint = Paint()
                  ..color = Palette.fireGold.withValues(alpha: alpha * 0.4)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
                canvas.drawCircle(Offset.zero, size * 2, glowPaint);
                
                final corePaint = Paint()
                  ..color = Palette.fireBright.withValues(alpha: alpha);
                canvas.drawCircle(Offset.zero, size, corePaint);
              },
            ),
          );
        },
      ),
    );
    add(emberTrail);

    // Auto-remove after effects finish
    add(TimerComponent(
      period: 3.0,
      removeOnFinish: true,
      onTick: () => removeFromParent(),
    ));
  }
}
