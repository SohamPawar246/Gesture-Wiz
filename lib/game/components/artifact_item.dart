import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../fpv_game.dart';

enum ArtifactType { mana, jammer, haste, vitality }

class ArtifactItem extends PositionComponent with HasGameReference<FpvGame> {
  final ArtifactType type;
  double depth;
  bool isTargeted = false; // Is the grab dragging it?
  bool isCollected = false;

  final double corridorX;
  final double corridorY;
  
  double _time = 0;

  ArtifactItem({
    required this.depth,
    required this.corridorX,
    required this.corridorY,
  }) : type = ArtifactType.values[Random().nextInt(ArtifactType.values.length)],
       super();

  Color get color {
    switch (type) {
      case ArtifactType.mana:
        return Colors.blueAccent;
      case ArtifactType.jammer:
        return Colors.greenAccent;
      case ArtifactType.haste:
        return Colors.amberAccent;
      case ArtifactType.vitality:
        return Colors.redAccent;
    }
  }

  String get label {
    switch (type) {
      case ArtifactType.mana:
        return 'MANA CORE';
      case ArtifactType.jammer:
        return 'JAMMER';
      case ArtifactType.haste:
        return 'HASTE';
      case ArtifactType.vitality:
        return 'VITALITY';
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isCollected) return;

    _time += dt;

    if (!isTargeted) {
      // Float towards player slowly
      depth += 0.05 * dt;
      if (depth >= 1.2) {
        removeFromParent(); // Missed it
        return;
      }
    }

    final w = game.size.x;
    final h = game.size.y;
    if (w <= 0 || h <= 0) return;

    final vpX = w * 0.5;
    final vpY = h * 0.38;
    final t = depth.clamp(0.0, 1.0);
    final screenX = vpX + corridorX * w * t;
    // Base Y drops slightly over time to simulate dropping
    final dropOffset = (depth * 0.2) * h;
    final screenY = vpY + corridorY * h * t + dropOffset;
    
    // Smooth follow if targeted, otherwise compute normally
    if (isTargeted) {
      // The game loop will update position directly during grab, 
      // but depth still drives size. We don't override position here if targeted.
    } else {
      position = Vector2(screenX, screenY);
    }
  }

  @override
  void render(Canvas canvas) {
    if (isCollected) return;

    final t = depth.clamp(0.05, 1.0);
    final s = 24.0 * t;
    if (s < 2.0) return;

    final floatDist = sin(_time * 4) * (s * 0.2);
    final center = Offset(0, floatDist);

    // Glow
    canvas.drawCircle(
      center,
      s * 1.5,
      Paint()
        ..color = color.withValues(alpha: 0.3 + 0.1 * sin(_time * 10))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s),
    );

    // Inner core
    canvas.drawCircle(
      center,
      s * 0.6,
      Paint()..color = Colors.white,
    );

    // Outer shell
    canvas.drawRect(
      Rect.fromCenter(center: center, width: s * 1.2, height: s * 1.2),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    
    // Diamond rotation
    canvas.save();
    canvas.translate(0, floatDist);
    canvas.rotate(_time * 2);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: s * 0.8, height: s * 0.8),
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.restore();
  }
}
