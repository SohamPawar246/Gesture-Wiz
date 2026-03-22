import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/fpv_game.dart';
import '../models/gesture_cursor_controller.dart'; 
import '../systems/audio_manager.dart';

class HazardController extends PositionComponent with HasGameReference<FpvGame> {
  final String nodeId;
  late final int sector;
  
  // Timers
  double _hazardTimer = 0;
  bool _hazardActive = false;
  double _activeDuration = 0;
  
  // Scanner properties
  double _scannerX = 0;
  double _scannerDir = 1;
  static const double scannerWidth = 400.0;

  HazardController(this.nodeId) : super() {
    priority = 150; // Render above enemies and UI if needed
    
    // Determine sector from node ID
    if (['1', '2b', '3b'].contains(nodeId)) {
      sector = 1; // Underground: EMP Pulses
    } else if (['2a', '3a', '4a', '4b'].contains(nodeId)) {
      sector = 2; // Corp/Neon: Scanner Sweeps
    } else if (['5', '6'].contains(nodeId)) {
      sector = 3; // Server Zero: Glitch Zones
    } else {
      sector = 1; // Default
    }
  }

  bool get isEmpActive => sector == 1 && _hazardActive;
  bool get isGlitchActive => sector == 3 && _hazardActive;

  @override
  void update(double dt) {
    super.update(dt);
    
    final size = game.size;
    if (size.x == 0) return;

    if (!_hazardActive) {
      _hazardTimer += dt;
      final threshold = sector == 2 ? 0.0 : 8.0; // Sector 2 is always active (Scanner)
      if (_hazardTimer >= threshold) {
        _hazardActive = true;
        _hazardTimer = 0;
        
        if (sector == 1) {
          _activeDuration = 3.0; // EMP lasts 3s
          AudioManager.playSfx('error.wav', volume: 0.6); // Play EMP sound
        } else if (sector == 3) {
          _activeDuration = 2.5; // Glitch lasts 2.5s
          AudioManager.playSfx('glitch.wav', volume: 0.8);
        }
      }
    } else {
      if (sector != 2) {
        _activeDuration -= dt;
        if (_activeDuration <= 0) {
          _hazardActive = false;
        }
      }
    }

    // Sector 2 Scanner Logic
    if (sector == 2) {
      _scannerX += _scannerDir * 350 * dt;
      if (_scannerX < 0) {
        _scannerX = 0;
        _scannerDir = 1;
      } else if (_scannerX > size.x) {
        _scannerX = size.x;
        _scannerDir = -1;
      }

      // Check if player cast a spell inside scanner
      final cursor = game.currentCursorPosition;
      if (cursor != null) {
        final distToScanner = (cursor.x - _scannerX).abs();
        if (distToScanner < scannerWidth * 0.5) {
          // Inside scanner
          game.surveillance.addSurveillanceFrame(dt * 0.3); // High passive gain
          if (game.justCastSpellThisFrame) { // We'll add this flag to FpvGame
            game.surveillance.spikeSurveillance(0.3); // 30% spike
            AudioManager.playSfx('error.wav', volume: 0.8);
            game.triggerScreenShake(10.0);
          }
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (sector == 2) {
      // Render Scanner spotlight
      final rect = Rect.fromCenter(
        center: Offset(_scannerX, game.size.y / 2),
        width: scannerWidth,
        height: game.size.y * 1.5,
      );
      
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.redAccent.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ).createShader(rect)
        ..blendMode = BlendMode.screen;
        
      canvas.drawRect(rect, paint);
      
      // Sweep line
      final linePaint = Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.5)
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(_scannerX, 0), Offset(_scannerX, game.size.y), linePaint);
    }
    
    if (sector == 1 && _hazardActive) {
      // EMP visual overlay
      canvas.drawColor(Colors.black.withValues(alpha: 0.3 + 0.1 * sin(_activeDuration * 20)), BlendMode.darken);
    }

    if (sector == 3 && _hazardActive) {
      // Glitch visual overlay (inverts colors beneath it)
      // Pulsing effect to make it chaotic
      final glitchPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85 + 0.15 * sin(_activeDuration * 30))
        ..blendMode = BlendMode.difference;
      canvas.drawRect(Rect.fromLTWH(0, 0, game.size.x, game.size.y), glitchPaint);
    }
  }
}
