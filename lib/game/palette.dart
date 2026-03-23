import 'package:flutter/material.dart';

/// Cyberpunk neon-noir color palette.
/// Deep blacks punctuated by electric cyan, hot magenta, and warning amber.
/// Every color serves the surveillance-state dystopian aesthetic.
class Palette {
  Palette._();

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKGROUNDS — Deep noir blacks
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color bgVoid = Color(0xFF020206); // Pure void
  static const Color bgDeep = Color(0xFF0A0A14); // Deep space
  static const Color bgPanel = Color(0xFF12121C); // UI panels
  static const Color bgElevated = Color(0xFF1A1A28); // Elevated surfaces
  static const Color bgDark = Color(0xFF0C0C16); // Dimmed backgrounds

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY NEON — Electric Cyan (Main accent)
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color neonCyan = Color(0xFF00FFFF); // Primary accent
  static const Color cyanDim = Color(0xFF00AAAA); // Dimmed state
  static const Color cyanDeep = Color(0xFF006688); // Deeper cyan
  static const Color cyanBright = Color(0xFF88FFFF); // Bright highlight

  // ═══════════════════════════════════════════════════════════════════════════
  // SECONDARY NEON — Hot Magenta/Pink
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color neonMagenta = Color(0xFFFF00FF); // Secondary accent
  static const Color neonPink = Color(0xFFFF0088); // Hot pink
  static const Color pinkDim = Color(0xFFAA0066); // Dimmed pink
  static const Color pinkBright = Color(0xFFFF66AA); // Bright pink

  // ═══════════════════════════════════════════════════════════════════════════
  // DANGER/ALERT — Warning Amber & Red
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color alertRed = Color(0xFFFF0044); // Critical warning
  static const Color alertAmber = Color(0xFFFFAA00); // Caution/warning
  static const Color alertOrange = Color(0xFFFF6600); // Fire/damage
  static const Color dangerDeep = Color(0xFFAA0022); // Deep danger

  // ═══════════════════════════════════════════════════════════════════════════
  // SYSTEM COLORS — Functional UI elements
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color dataGreen = Color(0xFF00FF66); // Success/safe/health
  static const Color dataBlue = Color(0xFF0088FF); // Mana/energy
  static const Color dataPurple = Color(0xFF8844FF); // Rare/special/corruption
  static const Color dataWhite = Color(0xFFEEEEFF); // Clean text
  static const Color dataGrey = Color(0xFF666680); // Disabled/inactive
  static const Color dataYellow = Color(0xFFFFFF00); // Ultimate/power

  // ═══════════════════════════════════════════════════════════════════════════
  // EFFECT COLORS — Special visual effects
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color scanLine = Color(0x18FFFFFF); // Scanline overlay
  static const Color hologram = Color(0xFF00FFCC); // Holographic tint
  static const Color corruption = Color(0xFFFF0066); // Data corruption
  static const Color glitchRed = Color(0xFFFF0000); // Chromatic aberration red
  static const Color glitchBlue = Color(
    0xFF0000FF,
  ); // Chromatic aberration blue
  static const Color empPulse = Color(0xFF44FFFF); // EMP/electric effects
  static const Color gridLine = Color(0xFF00FFFF); // Grid/floor lines

  // ═══════════════════════════════════════════════════════════════════════════
  // VIGNETTE & OVERLAY
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color vignette = Color(0xFF000000); // Vignette edge
  static const Color vignetteWarm = Color(0xFF110808); // Warm vignette (danger)
  static const Color vignetteCool = Color(0xFF080811); // Cool vignette (safe)

  // ═══════════════════════════════════════════════════════════════════════════
  // LEGACY COMPATIBILITY — Mapped to new cyberpunk colors
  // (Gradual migration — these will work with existing code)
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color fireDeep = alertOrange;
  static const Color fireMid = alertAmber;
  static const Color fireGold = alertAmber;
  static const Color fireBright = dataYellow;
  static const Color fireWhite = dataWhite;
  static const Color impactRed = alertRed;
  static const Color impactPink = neonPink;
  static const Color uiWhite = dataWhite;
  static const Color uiGold = alertAmber;
  static const Color uiGrey = dataGrey;
  static const Color uiDarkPanel = bgPanel;
  static const Color uiMana = dataBlue;
  static const Color uiXp = dataPurple;
  static const Color bgHighlight = cyanDeep;
  static const Color bgMid = bgPanel;
  static const Color bgLight = bgElevated;
  static const Color glowWarm = Color(0x44FF6600);
  static const Color glowHot = Color(0x66FFAA00);

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns a pulsing alpha value for glow effects
  static double pulseAlpha(double time, {double min = 0.4, double max = 1.0}) {
    // sin() from dart:math used via Flutter's dart:math re-export
    const twoPi = 3.14159265358979 * 2;
    final v = (time * 2) % twoPi;
    final s = (v < 3.14159265358979) ? v : twoPi - v; // hand-rolled abs(sin)
    return min + (max - min) * (0.5 + 0.5 * (s / 3.14159265358979));
  }

  /// Returns color shifted toward danger based on a 0-1 factor
  static Color dangerShift(Color base, double factor) {
    return Color.lerp(base, alertRed, factor.clamp(0.0, 1.0))!;
  }

  /// Creates a neon glow Paint for the given color
  static Paint neonGlow(Color color, {double blur = 20.0, double alpha = 0.5}) {
    return Paint()
      ..color = color.withValues(alpha: alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
  }
}

/// Extension for easy color manipulation
extension ColorX on Color {
  /// Returns this color with modified opacity (0.0 - 1.0)
  Color withAlpha01(double opacity) =>
      withValues(alpha: opacity.clamp(0.0, 1.0));

  /// Returns a pulsing version of this color based on time
  Color pulse(double time, {double min = 0.5, double max = 1.0}) {
    final factor = min + (max - min) * (0.5 + 0.5 * (time * 2).remainder(6.28));
    return withAlpha01(a * factor);
  }
}
