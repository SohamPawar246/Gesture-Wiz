import 'package:flutter/material.dart';

import '../systems/gesture/gesture_type.dart';
import '../models/player_stats.dart';
import '../game/palette.dart';

class HUD extends StatefulWidget {
  final GestureType activeGesture;
  final PlayerStats playerStats;

  const HUD({
    super.key,
    required this.activeGesture,
    required this.playerStats,
  });

  @override
  State<HUD> createState() => _HUDState();
}

class _HUDState extends State<HUD> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _gestureActionName(GestureType gesture) {
    switch (gesture) {
      case GestureType.none:
        return 'SCANNING...';
      case GestureType.point:
        return 'FIRE BOLT';
      case GestureType.fist:
        return 'FORCE PUSH';
      case GestureType.openPalm:
        return 'WARD SHIELD';
      case GestureType.pinch:
        return 'GRIP';
      case GestureType.vSign:
        return 'OVERWATCH PULSE';
    }
  }

  IconData _gestureIcon(GestureType gesture) {
    switch (gesture) {
      case GestureType.none:
        return Icons.sensors;
      case GestureType.point:
        return Icons.local_fire_department;
      case GestureType.fist:
        return Icons.sports_mma;
      case GestureType.openPalm:
        return Icons.shield;
      case GestureType.pinch:
        return Icons.pinch;
      case GestureType.vSign:
        return Icons.flash_on;
    }
  }

  Color _gestureColor(GestureType gesture) {
    switch (gesture) {
      case GestureType.none:
        return Palette.uiGrey;
      case GestureType.point:
        return const Color(0xFFFF6622);
      case GestureType.fist:
        return const Color(0xFF9944FF);
      case GestureType.openPalm:
        return const Color(0xFF44DDFF);
      case GestureType.pinch:
        return const Color(0xFF88FF44);
      case GestureType.vSign:
        return const Color(0xFFFFFF44);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ps = widget.playerStats;
    final hpFraction = (ps.currentHp / ps.maxHp).clamp(0.0, 1.0);
    final isLowHp = hpFraction < 0.30;
    final gestureColor = _gestureColor(widget.activeGesture);

    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── TOP ROW ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: Vitals panel
                  _buildVitalsPanel(ps, hpFraction, isLowHp),

                  // RIGHT: Combat info
                  _buildCombatPanel(ps),
                ],
              ),

              const Spacer(),

              // ─── BOTTOM: Active spell indicator ────────────────
              Center(
                child: AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, _) {
                    final isActive = widget.activeGesture != GestureType.none;
                    final glow = isActive ? 0.4 + 0.6 * _pulseCtrl.value : 0.0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: gestureColor.withValues(alpha: 0.08),
                        border: Border.all(
                          color: gestureColor.withValues(
                            alpha: isActive ? 0.7 : 0.3,
                          ),
                          width: 1.5,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: gestureColor.withValues(
                                    alpha: glow * 0.3,
                                  ),
                                  blurRadius: 18,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _gestureIcon(widget.activeGesture),
                            color: isActive ? gestureColor : Palette.uiGrey,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _gestureActionName(widget.activeGesture),
                            style: TextStyle(
                              color: isActive ? gestureColor : Palette.uiGrey,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              letterSpacing: 3.5,
                              shadows: isActive
                                  ? [
                                      Shadow(
                                        blurRadius: 10,
                                        color: gestureColor.withValues(alpha: 0.7),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Vitals Panel (HP / Mana / XP) ─────────────────────────────
  Widget _buildVitalsPanel(PlayerStats ps, double hpFraction, bool isLowHp) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC060C0C),
        border: Border.all(
          color: Palette.fireMid.withValues(alpha: 0.2),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Level row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('LV.${ps.level}', Palette.fireGold, 13),
              _label('${ps.currentXp}/${ps.maxXp} XP', Palette.uiGrey, 10),
            ],
          ),
          const SizedBox(height: 4),
          _glowBar(ps.currentXp / ps.maxXp, Palette.uiXp, 4),

          const SizedBox(height: 10),

          // HP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('HP', Palette.impactRed, 11),
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, _) {
                  final alpha = isLowHp ? 0.6 + 0.4 * _pulseCtrl.value : 1.0;
                  return Text(
                    '${ps.currentHp.toInt()}',
                    style: TextStyle(
                      color: isLowHp
                          ? Palette.impactRed.withValues(alpha: alpha)
                          : Palette.uiGrey,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: isLowHp ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, _) => _glowBar(
              hpFraction,
              isLowHp
                  ? Color.lerp(
                      Palette.impactRed,
                      const Color(0xFFFF8844),
                      _pulseCtrl.value,
                    )!
                  : Palette.impactRed,
              11,
              glowForce: isLowHp ? 0.3 + 0.4 * _pulseCtrl.value : 0.15,
            ),
          ),

          const SizedBox(height: 10),

          // Mana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('MANA', Palette.uiMana, 11),
              _label('${ps.currentMana.toInt()}', Palette.uiGrey, 10),
            ],
          ),
          const SizedBox(height: 4),
          _glowBar(ps.currentMana / ps.maxMana, Palette.uiMana, 9),
        ],
      ),
    );
  }

  // ── Combat Panel (Wave / Score / Kills) ───────────────────────
  Widget _buildCombatPanel(PlayerStats ps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sector name
        _iconInfoChip(Icons.location_on, ps.currentNodeLabel, Palette.fireGold, Palette.fireDeep),
        if (ps.totalWaves > 1) ...[
          const SizedBox(height: 6),
          _iconInfoChip(Icons.waves, 'WAVE ${ps.currentWave}/${ps.totalWaves}', Palette.fireGold, Palette.fireDeep),
        ],
        const SizedBox(height: 6),
        _iconInfoChip(Icons.star, '${ps.score}', Palette.fireWhite, const Color(0xFF1A1008)),
        const SizedBox(height: 6),
        _iconInfoChip(Icons.dangerous, '${ps.killCount} KILLS', Palette.impactPink, const Color(0xFF1A0808)),
      ],
    );
  }

  Widget _iconInfoChip(IconData icon, String text, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.85),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.0),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              fontSize: 13,
              letterSpacing: 2.0,
              shadows: [Shadow(blurRadius: 6, color: color.withValues(alpha: 0.4))],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, Color color, double size) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
        fontSize: size,
        letterSpacing: 1.5,
        shadows: [Shadow(blurRadius: 4, color: color.withValues(alpha: 0.4))],
      ),
    );
  }

  Widget _glowBar(
    double value,
    Color color,
    double height, {
    double glowForce = 0.15,
  }) {
    return Stack(
      children: [
        // Track
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        // Fill
        FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.7),
                  color,
                  Color.lerp(color, Colors.white, 0.3)!,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glowForce),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
