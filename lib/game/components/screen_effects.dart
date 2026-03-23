import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../palette.dart';

/// Persistent screen-space effects layered over the entire game.
///
/// Layers (bottom → top):
///   1. Animated scanlines
///   2. Edge vignette (danger-reactive)
///   3. Chromatic aberration (triggered on damage, fades out)
///   4. Random glitch displacement (triggered externally or by hazards)
class ScreenEffects extends PositionComponent with HasGameReference {
  // ── Scanlines ──────────────────────────────────────────────────
  double _scanOffset = 0.0;
  static const double _scanSpeed = 18.0; // px/s scroll speed

  // ── Vignette ───────────────────────────────────────────────────
  double _vignetteAlert = 0.0; // 0 = safe cyan, 1 = danger red
  double _vignettePulse = 0.0; // driven by pulse controller

  // ── Chromatic Aberration ───────────────────────────────────────
  double _chromaIntensity = 0.0; // 0–1; fades automatically
  static const double _chromaDecay = 2.5; // per second
  static const double _chromaMaxOffset = 18.0; // max pixel offset

  // ── Glitch ────────────────────────────────────────────────────
  double _glitchIntensity = 0.0; // 0–1; fades automatically
  double _glitchTimer = 0.0; // countdown for current glitch slice
  final Random _rng = Random();
  final List<_GlitchSlice> _slices = [];
  static const double _glitchDecay = 3.0;

  // ── Low-HP heartbeat ──────────────────────────────────────────
  double _heartbeat = 0.0; // accumulated time for sin wave

  ScreenEffects() : super(priority: 950);

  // ────────────────────────────────────────────────────────────────
  // Public API
  // ────────────────────────────────────────────────────────────────

  /// Trigger chromatic aberration (call on player taking damage).
  /// [intensity] 0–1, where 1 = maximum RGB split.
  void triggerChroma({double intensity = 0.8}) {
    _chromaIntensity = intensity.clamp(0.0, 1.0);
  }

  /// Trigger glitch effect (call on EMP, server-zero hazard, etc.).
  /// [intensity] 0–1.
  void triggerGlitch({double intensity = 0.6}) {
    _glitchIntensity = intensity.clamp(0.0, 1.0);
    _rebuildGlitchSlices();
  }

  /// Set how "danger" the vignette looks. 0 = calm cyan, 1 = pulsing red.
  void setAlertLevel(double level) {
    _vignetteAlert = level.clamp(0.0, 1.0);
  }

  // ────────────────────────────────────────────────────────────────
  // Internal
  // ────────────────────────────────────────────────────────────────

  void _rebuildGlitchSlices() {
    _slices.clear();
    final h = game.size.y;
    int count = 3 + _rng.nextInt(5);
    for (int i = 0; i < count; i++) {
      _slices.add(_GlitchSlice(
        y: _rng.nextDouble() * h,
        height: 2.0 + _rng.nextDouble() * 20.0,
        offset: (_rng.nextDouble() - 0.5) * 40.0 * _glitchIntensity,
      ));
    }
    _glitchTimer = 0.04 + _rng.nextDouble() * 0.08;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Scanline scroll
    _scanOffset = (_scanOffset + _scanSpeed * dt) % 4.0;

    // Chroma decay
    if (_chromaIntensity > 0) {
      _chromaIntensity -= _chromaDecay * dt;
      if (_chromaIntensity < 0) _chromaIntensity = 0;
    }

    // Glitch decay + re-slice
    if (_glitchIntensity > 0) {
      _glitchIntensity -= _glitchDecay * dt;
      if (_glitchIntensity < 0) {
        _glitchIntensity = 0;
        _slices.clear();
      } else {
        _glitchTimer -= dt;
        if (_glitchTimer <= 0) _rebuildGlitchSlices();
      }
    }

    // Heartbeat pulse for vignette
    _heartbeat += dt * 2.2;
    _vignettePulse = 0.5 + 0.5 * sin(_heartbeat);
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // 1. Scanlines
    _renderScanlines(canvas, w, h);

    // 2. Vignette
    _renderVignette(canvas, rect, w, h);

    // 3. Glitch slices
    if (_glitchIntensity > 0 && _slices.isNotEmpty) {
      _renderGlitch(canvas, w);
    }

    // 4. Chromatic aberration
    if (_chromaIntensity > 0) {
      _renderChroma(canvas, w, h);
    }
  }

  void _renderScanlines(Canvas canvas, double w, double h) {
    const lineSpacing = 4.0;
    const lineAlpha = 0.06;

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: lineAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final startY = -_scanOffset;
    var y = startY;
    while (y < h) {
      canvas.drawLine(Offset(0, y), Offset(w, y), paint);
      y += lineSpacing;
    }
  }

  void _renderVignette(Canvas canvas, Rect rect, double w, double h) {
    // Base vignette — always-on cool dark edges
    final basePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Palette.vignetteCool.withValues(alpha: 0.65),
        ],
        stops: const [0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    // Alert vignette — danger state overlay
    if (_vignetteAlert > 0.01) {
      final pulse = _vignettePulse * 0.3 + 0.7; // 0.7–1.0
      final alertAlpha = _vignetteAlert * 0.55 * pulse;
      final alertPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Palette.alertRed.withValues(alpha: alertAlpha),
          ],
          stops: const [0.4, 1.0],
        ).createShader(rect);
      canvas.drawRect(rect, alertPaint);
    }

    // Thin cyan border glow — cyberpunk terminal frame
    final borderAlpha = 0.12 + 0.05 * _vignettePulse;
    final borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Palette.neonCyan.withValues(alpha: borderAlpha * 1.5),
          Colors.transparent,
          Colors.transparent,
          Palette.neonCyan.withValues(alpha: borderAlpha),
        ],
        stops: const [0.0, 0.08, 0.92, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, borderPaint);

    // Left/right edge glow
    final sidePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Palette.neonCyan.withValues(alpha: borderAlpha),
          Colors.transparent,
          Colors.transparent,
          Palette.neonCyan.withValues(alpha: borderAlpha),
        ],
        stops: const [0.0, 0.04, 0.96, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, sidePaint);
  }

  void _renderGlitch(Canvas canvas, double w) {
    canvas.save();
    for (final slice in _slices) {
      final sliceRect = Rect.fromLTWH(
        0, slice.y, w, slice.height,
      );
      canvas.saveLayer(sliceRect, Paint());
      canvas.translate(slice.offset, 0);
      // Draw a semi-transparent magenta/cyan tint on displaced area
      canvas.drawRect(
        Rect.fromLTWH(
          -slice.offset.abs() - 2,
          slice.y,
          w + slice.offset.abs() * 2 + 4,
          slice.height,
        ),
        Paint()
          ..color = Palette.neonMagenta.withValues(
            alpha: 0.12 * _glitchIntensity,
          ),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _renderChroma(Canvas canvas, double w, double h) {
    // Simulate chromatic aberration with edge-tinted overlays
    final offset = _chromaMaxOffset * _chromaIntensity;
    final alpha = 0.25 * _chromaIntensity;

    final rect = Rect.fromLTWH(0, 0, w, h);

    // Red channel — shifted left
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Palette.glitchRed.withValues(alpha: alpha),
            Colors.transparent,
          ],
          stops: [0.0, (offset / w * 3).clamp(0.0, 1.0)],
        ).createShader(rect),
    );

    // Blue channel — shifted right
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            Palette.glitchBlue.withValues(alpha: alpha),
            Colors.transparent,
          ],
          stops: [0.0, (offset / w * 3).clamp(0.0, 1.0)],
        ).createShader(rect),
    );

    // Subtle horizontal line artifacts at top/bottom
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, 3),
      Paint()
        ..color = Palette.glitchRed.withValues(alpha: alpha * 1.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h - 3, w, 3),
      Paint()
        ..color = Palette.glitchBlue.withValues(alpha: alpha * 1.5),
    );
  }
}

class _GlitchSlice {
  final double y;
  final double height;
  final double offset;

  const _GlitchSlice({
    required this.y,
    required this.height,
    required this.offset,
  });
}
