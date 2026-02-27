import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// Optimized CRT overlay — caches scanline texture, only redraws vignette.
/// Much lighter on the GPU than drawing individual rects per scanline.
class RetroOverlay extends PositionComponent with HasGameReference {
  ui.Image? _scanlineImage;
  double _cachedW = 0;
  double _cachedH = 0;

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    if (w <= 0 || h <= 0) return;

    // ==========================================================
    // 1. SCANLINES — cached as an image, drawn once
    // ==========================================================
    if (_scanlineImage == null || _cachedW != w || _cachedH != h) {
      _buildScanlineImage(w, h);
    }

    if (_scanlineImage != null) {
      canvas.drawImage(_scanlineImage!, Offset.zero, Paint());
    }

    // ==========================================================
    // 2. VIGNETTE — radial edge darkening (1 draw call)
    // ==========================================================
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          Palette.vignette.withValues(alpha: 0.6),
          Palette.vignette.withValues(alpha: 0.85),
        ],
        stops: const [0.0, 0.45, 0.8, 1.0],
      ).createShader(Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: w * 1.1,
        height: h * 1.1,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), vignettePaint);

    // ==========================================================
    // 3. SUBTLE BOTTOM GLOW (1 draw call)
    // ==========================================================
    final bottomGlow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.center,
        colors: [
          Palette.fireDeep.withValues(alpha: 0.1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.6, w, h * 0.4), bottomGlow);
  }

  void _buildScanlineImage(double w, double h) {
    _cachedW = w;
    _cachedH = h;

    // Build scanlines every 4px (instead of 3) and cache as image
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    final scanPaint = Paint()
      ..color = const Color(0x33000000) // Increased from 0x0C to 0x33 (20% opacity)
      ..style = PaintingStyle.fill;

    for (double y = 0; y < h; y += 4.0) {
      c.drawRect(Rect.fromLTWH(0, y, w, 1.5), scanPaint); // Increased thickness 1.0 -> 1.5
    }

    final picture = recorder.endRecording();
    picture.toImage(w.toInt(), h.toInt()).then((image) {
      _scanlineImage = image;
    });
  }
}
