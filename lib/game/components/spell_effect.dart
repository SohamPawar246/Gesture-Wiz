import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flame/particles.dart';

import '../palette.dart';

/// Cyberpunk spell effect — digital impact with hexagonal patterns,
/// data fragments, and glitch aesthetics.
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
    final random = Random();

    // 0. Hexagonal shockwave ring (expanding, digital style)
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 1,
          lifespan: 0.6,
          generator: (_) => ComputedParticle(
            renderer: (canvas, particle) {
              final progress = particle.progress;
              final radius = 25 + progress * 130;
              final alpha = (1.0 - progress).clamp(0.0, 1.0);

              // Outer hex ring glow
              final hexPath = _createHexPath(Offset.zero, radius);
              canvas.drawPath(
                hexPath,
                Paint()
                  ..color = effectColor.withValues(alpha: alpha * 0.3)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 15 * (1 - progress),
              );

              // Crisp hex ring
              canvas.drawPath(
                hexPath,
                Paint()
                  ..color = Palette.dataWhite.withValues(alpha: alpha * 0.8)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.5 * (1 - progress * 0.5),
              );

              // Inner digital fill
              canvas.drawPath(
                _createHexPath(Offset.zero, radius * 0.5),
                Paint()
                  ..color = effectColor.withValues(alpha: alpha * 0.1)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
              );
            },
          ),
        ),
      ),
    );

    // 1. Spell Name — floating with digital glow
    final textComp = TextComponent(
      text: spellName.toUpperCase(),
      textRenderer: TextPaint(
        style: TextStyle(
          color: Palette.dataWhite,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 4.0,
          shadows: [
            Shadow(blurRadius: 12, color: effectColor),
            Shadow(blurRadius: 24, color: effectColor.withValues(alpha: 0.5)),
            const Shadow(blurRadius: 4, color: Palette.dataWhite),
          ],
        ),
      ),
      anchor: Anchor.center,
      position: Vector2(0, -50),
    );
    textComp.add(
      MoveByEffect(
        Vector2(0, -60),
        EffectController(duration: 1.4, curve: Curves.easeOut),
      ),
    );
    add(textComp);

    // 2. Data Fragment Burst — geometric shards exploding outward
    final fragmentBurst = ParticleSystemComponent(
      particle: Particle.generate(
        count: 40,
        lifespan: 1.5,
        generator: (i) {
          final speed = random.nextDouble() * 200 + 100;
          final angle = random.nextDouble() * 2 * pi;
          final vx = cos(angle) * speed;
          final vy = sin(angle) * speed;

          // Mix between spell color and cyan
          final t = random.nextDouble();
          final particleColor = Color.lerp(
            effectColor,
            Palette.neonCyan,
            t * 0.5,
          )!;
          final rotation = random.nextDouble() * pi * 2;
          final size = 4.0 + random.nextDouble() * 8.0;

          return AcceleratedParticle(
            acceleration: Vector2(0, 60),
            speed: Vector2(vx, vy),
            position: Vector2.zero(),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final progress = particle.progress;
                final alpha = (1.0 - progress).clamp(0.0, 1.0);
                final currentRot = rotation + progress * pi;

                canvas.save();
                canvas.rotate(currentRot);

                // Glow
                canvas.drawRect(
                  Rect.fromCenter(
                    center: Offset.zero,
                    width: size * 2.5,
                    height: size * 1.5,
                  ),
                  Paint()
                    ..color = particleColor.withValues(alpha: alpha * 0.4)
                    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
                );

                // Core fragment (rectangular)
                canvas.drawRect(
                  Rect.fromCenter(
                    center: Offset.zero,
                    width: size * 1.2,
                    height: size * 0.6,
                  ),
                  Paint()..color = particleColor.withValues(alpha: alpha),
                );

                // Bright edge
                if (progress < 0.4) {
                  canvas.drawRect(
                    Rect.fromCenter(
                      center: Offset.zero,
                      width: size * 0.8,
                      height: size * 0.3,
                    ),
                    Paint()
                      ..color = Palette.dataWhite.withValues(
                        alpha: alpha * 0.7,
                      ),
                  );
                }

                canvas.restore();
              },
            ),
          );
        },
      ),
    );
    add(fragmentBurst);

    // 3. Scan Lines — horizontal digital distortion expanding outward
    final scanBurst = ParticleSystemComponent(
      particle: Particle.generate(
        count: 12,
        lifespan: 0.7,
        generator: (i) {
          final speed = 150 + random.nextDouble() * 200;
          final direction = i % 2 == 0 ? 1.0 : -1.0;
          final yOffset = (random.nextDouble() - 0.5) * 60;

          return AcceleratedParticle(
            acceleration: Vector2.zero(),
            speed: Vector2(direction * speed, 0),
            position: Vector2(0, yOffset),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final alpha = (1.0 - particle.progress).clamp(0.0, 1.0);
                final width = 30 + particle.progress * 50;

                canvas.drawRect(
                  Rect.fromCenter(
                    center: Offset.zero,
                    width: width,
                    height: 2.0,
                  ),
                  Paint()
                    ..color = effectColor.withValues(alpha: alpha * 0.6)
                    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
                );
              },
            ),
          );
        },
      ),
    );
    add(scanBurst);

    // 4. Data Motes — small pixels floating upward
    final dataMotes = ParticleSystemComponent(
      particle: Particle.generate(
        count: 20,
        lifespan: 2.2,
        generator: (i) {
          final drift = (random.nextDouble() - 0.5) * 80;
          final moteColors = [
            Palette.neonCyan,
            Palette.neonPink,
            Palette.dataGreen,
            effectColor,
          ];
          final moteColor = moteColors[random.nextInt(moteColors.length)];

          return AcceleratedParticle(
            acceleration: Vector2(0, -20),
            speed: Vector2(drift, -random.nextDouble() * 50 - 30),
            position: Vector2(
              (random.nextDouble() - 0.5) * 60,
              (random.nextDouble() - 0.5) * 60,
            ),
            child: ComputedParticle(
              renderer: (canvas, particle) {
                final alpha = (1.0 - particle.progress) * 0.8;
                final size = 2.0 + random.nextDouble() * 3.0;

                // Pixel glow
                canvas.drawRect(
                  Rect.fromCenter(
                    center: Offset.zero,
                    width: size * 3,
                    height: size * 3,
                  ),
                  Paint()
                    ..color = moteColor.withValues(alpha: alpha * 0.3)
                    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
                );

                // Core pixel
                canvas.drawRect(
                  Rect.fromCenter(
                    center: Offset.zero,
                    width: size,
                    height: size,
                  ),
                  Paint()..color = moteColor.withValues(alpha: alpha),
                );
              },
            ),
          );
        },
      ),
    );
    add(dataMotes);

    // Auto-remove after effects finish
    add(
      TimerComponent(
        period: 2.8,
        removeOnFinish: true,
        onTick: () => removeFromParent(),
      ),
    );
  }

  /// Creates a hexagonal path centered at the given offset
  Path _createHexPath(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = i * pi / 3 - pi / 6;
      final x = center.dx + cos(angle) * radius;
      final y = center.dy + sin(angle) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}
