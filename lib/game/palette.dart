import 'package:flutter/material.dart';

/// Jon Wick inspired retro color palette.
/// Teal environments, amber/gold fire, warm pixel aesthetic.
class Palette {
  Palette._();

  // --- Environment (Teal Dungeon) ---
  static const Color bgDeep       = Color(0xFF0A1A1A);   // Deepest black-teal
  static const Color bgDark       = Color(0xFF0F2A2A);   // Dark teal walls
  static const Color bgMid        = Color(0xFF1A4040);   // Mid teal stone
  static const Color bgLight      = Color(0xFF2A6B6B);   // Lighter teal accents
  static const Color bgHighlight  = Color(0xFF3A8888);   // Bright teal highlights

  // --- Fire / Hands (Amber → Gold → White) ---
  static const Color fireDeep     = Color(0xFFCC4400);   // Deep ember orange
  static const Color fireMid      = Color(0xFFD4A030);   // Warm amber (candle wax)
  static const Color fireGold     = Color(0xFFFFD700);   // Bright gold
  static const Color fireBright   = Color(0xFFFFFF00);   // Yellow flame tip
  static const Color fireWhite    = Color(0xFFFFFFEE);   // White-hot core

  // --- Impact / Damage ---
  static const Color impactRed    = Color(0xFFCC2222);   // Blood/damage red
  static const Color impactPink   = Color(0xFFFF4466);   // Impact flash

  // --- UI ---
  static const Color uiWhite      = Color(0xFFFFFFFF);
  static const Color uiGold       = Color(0xFFFFD700);
  static const Color uiGrey       = Color(0xFF888888);
  static const Color uiDarkPanel  = Color(0xCC0A1A1A);   // Semi-transparent panel
  static const Color uiMana       = Color(0xFF2288CC);   // Mana blue (kept for contrast)
  static const Color uiXp         = Color(0xFFD4A030);   // XP amber

  // --- Effects ---
  static const Color glowWarm     = Color(0x44FF6600);   // Ambient warm glow
  static const Color glowHot      = Color(0x66FFD700);   // Hot glow
  static const Color scanline     = Color(0x18000000);   // Scanline overlay
  static const Color vignette     = Color(0xFF000000);   // Vignette edge
}
