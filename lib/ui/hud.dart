import 'package:flutter/material.dart';

import '../systems/gesture/gesture_type.dart';
import '../models/player_stats.dart';
import '../game/palette.dart';

class HUD extends StatefulWidget {
  final GestureType activeGesture;
  final PlayerStats playerStats;

  /// 0.0–1.0 surveillance level fed from FpvGame/SurveillanceSystem
  final double surveillanceLevel;

  const HUD({
    super.key,
    required this.activeGesture,
    required this.playerStats,
    this.surveillanceLevel = 0.0,
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
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Cyberpunk action name mapping ──────────────────────────────
  String _actionName(GestureType gesture) {
    switch (gesture) {
      case GestureType.none:
        return 'SCANNING...';
      case GestureType.point:
        return 'DATA SPIKE';
      case GestureType.fist:
        return 'SYS RESTORE';
      case GestureType.openPalm:
        return 'FIREWALL';
      case GestureType.pinch:
        return 'HACK GRIP';
      case GestureType.vSign:
        return 'ZERO DAY';
    }
  }

  IconData _actionIcon(GestureType gesture) {
    switch (gesture) {
      case GestureType.none:
        return Icons.sensors;
      case GestureType.point:
        return Icons.bolt;
      case GestureType.fist:
        return Icons.healing;
      case GestureType.openPalm:
        return Icons.shield;
      case GestureType.pinch:
        return Icons.link;
      case GestureType.vSign:
        return Icons.radio_button_checked;
    }
  }

  Color _actionColor(GestureType gesture) {
    switch (gesture) {
      case GestureType.none:
        return Palette.dataGrey;
      case GestureType.point:
        return Palette.neonCyan;
      case GestureType.fist:
        return Palette.dataGreen;
      case GestureType.openPalm:
        return Palette.dataBlue;
      case GestureType.pinch:
        return Palette.neonPink;
      case GestureType.vSign:
        return Palette.alertAmber;
    }
  }

  // ── Surveillance color ramp ────────────────────────────────────
  Color _surveillanceColor(double level) {
    if (level < 0.5) return Color.lerp(Palette.dataGreen, Palette.alertAmber, level * 2)!;
    return Color.lerp(Palette.alertAmber, Palette.alertRed, (level - 0.5) * 2)!;
  }

  @override
  Widget build(BuildContext context) {
    final ps = widget.playerStats;
    final hpFraction = (ps.currentHp / ps.maxHp).clamp(0.0, 1.0);
    final isLowHp = hpFraction < 0.30;
    final surv = widget.surveillanceLevel.clamp(0.0, 1.0);
    final survColor = _surveillanceColor(surv);
    final actionColor = _actionColor(widget.activeGesture);

    return Positioned.fill(
      child: SafeArea(
        child: Column(
          children: [
            // ── TOP: Surveillance bar ──────────────────────────────
            _buildSurveillanceBar(surv, survColor),

            // ── MAIN BODY ─────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT: Vitals
                    _buildVitals(ps, hpFraction, isLowHp),
                    const Spacer(),
                    // RIGHT: Combat stats
                    _buildCombatStats(ps),
                  ],
                ),
              ),
            ),

            // ── BOTTOM: Active action indicator ───────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildActionIndicator(actionColor),
            ),
          ],
        ),
      ),
    );
  }

  // ── Surveillance Bar ──────────────────────────────────────────
  Widget _buildSurveillanceBar(double level, Color color) {
    final isCritical = level > 0.75;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final pulse = isCritical ? 0.7 + 0.3 * _pulseCtrl.value : 1.0;
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Palette.bgPanel.withValues(alpha: 0.85),
            border: Border.all(
              color: color.withValues(alpha: 0.35 * pulse),
              width: 1.0,
            ),
            boxShadow: isCritical
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2 * pulse),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.remove_red_eye,
                color: color.withValues(alpha: 0.9 * pulse),
                size: 14,
              ),
              const SizedBox(width: 8),
              _label('SURVEILLANCE', color.withValues(alpha: 0.7), 10),
              const SizedBox(width: 10),
              Expanded(
                child: _glowBar(
                  level,
                  color,
                  8,
                  glowForce: isCritical ? 0.3 * pulse : 0.12,
                  shimmer: !isCritical,
                  shimmerPhase: _pulseCtrl.value,
                ),
              ),
              const SizedBox(width: 8),
              _label(
                '${(level * 100).toInt()}%',
                color.withValues(alpha: pulse),
                11,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Vitals Panel ──────────────────────────────────────────────
  Widget _buildVitals(PlayerStats ps, double hpFraction, bool isLowHp) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Palette.bgPanel.withValues(alpha: 0.88),
          border: Border.all(
            color: Palette.neonCyan.withValues(alpha: 0.18),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Palette.neonCyan.withValues(alpha: 0.04),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Level + XP
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('LV.${ps.level}', Palette.neonCyan, 13),
                _label('${ps.currentXp}/${ps.maxXp} XP', Palette.dataGrey, 10),
              ],
            ),
            const SizedBox(height: 4),
            _glowBar(ps.currentXp / ps.maxXp, Palette.dataPurple, 4),

            const SizedBox(height: 10),

            // HP
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('HP', Palette.alertRed, 11),
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, child) {
                    final alpha = isLowHp ? 0.6 + 0.4 * _pulseCtrl.value : 1.0;
                    return Text(
                      '${ps.currentHp.toInt()}',
                      style: TextStyle(
                        color: isLowHp
                            ? Palette.alertRed.withValues(alpha: alpha)
                            : Palette.dataGrey,
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
              builder: (context, child) => _glowBar(
                hpFraction,
                isLowHp
                    ? Color.lerp(
                        Palette.alertRed,
                        Palette.alertOrange,
                        _pulseCtrl.value,
                      )!
                    : Palette.dataGreen,
                11,
                glowForce: isLowHp ? 0.3 + 0.35 * _pulseCtrl.value : 0.12,
                shimmer: !isLowHp,
                shimmerPhase: _pulseCtrl.value,
              ),
            ),

            const SizedBox(height: 10),

            // Mana
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _label('MANA', Palette.dataBlue, 11),
                _label('${ps.currentMana.toInt()}', Palette.dataGrey, 10),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) => _glowBar(
                ps.currentMana / ps.maxMana,
                Palette.dataBlue,
                9,
                shimmer: true,
                shimmerPhase: _pulseCtrl.value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Combat Stats Panel ────────────────────────────────────────
  Widget _buildCombatStats(PlayerStats ps) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _chip(Icons.location_on_outlined, ps.currentNodeLabel, Palette.neonCyan),
              if (ps.totalWaves > 1) ...[
                const SizedBox(height: 5),
                _chip(
                  Icons.wifi_tethering,
                  'WAVE ${ps.currentWave}/${ps.totalWaves}',
                  Palette.alertAmber,
                ),
              ],
              const SizedBox(height: 5),
              _chip(Icons.star_outline, '${ps.score}', Palette.dataWhite),
              const SizedBox(height: 5),
              _chip(Icons.close, '${ps.killCount} KILLS', Palette.neonPink),
            ],
          ),
        );
      },
    );
  }

  // ── Active Action Indicator ───────────────────────────────────
  Widget _buildActionIndicator(Color color) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        final isActive = widget.activeGesture != GestureType.none;
        final glow = isActive ? 0.4 + 0.6 * _pulseCtrl.value : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            border: Border.all(
              color: color.withValues(alpha: isActive ? 0.65 : 0.2),
              width: 1.5,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: glow * 0.25),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: color.withValues(alpha: glow * 0.08),
                      blurRadius: 40,
                      spreadRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _actionIcon(widget.activeGesture),
                color: isActive ? color : Palette.dataGrey,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                _actionName(widget.activeGesture),
                style: TextStyle(
                  color: isActive ? color : Palette.dataGrey,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 3.5,
                  shadows: isActive
                      ? [
                          Shadow(blurRadius: 10, color: color.withValues(alpha: 0.7)),
                          Shadow(blurRadius: 25, color: color.withValues(alpha: 0.3)),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────
  Widget _chip(IconData icon, String text, Color color) {
    final glow = _pulseCtrl.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.bgPanel.withValues(alpha: 0.85),
        border: Border.all(
          color: color.withValues(alpha: 0.3 + 0.12 * glow),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05 + 0.04 * glow),
            blurRadius: 8 + 3 * glow,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 2.0,
              shadows: [Shadow(blurRadius: 5, color: color.withValues(alpha: 0.4))],
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
    bool shimmer = false,
    double shimmerPhase = 0.0,
  }) {
    return Stack(
      children: [
        // Track
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            border: Border.all(color: color.withValues(alpha: 0.18), width: 0.5),
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
                  color.withValues(alpha: 0.65),
                  color,
                  Color.lerp(color, Colors.white, 0.25)!,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glowForce),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
        // Shimmer
        if (shimmer && value > 0.05)
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bw = constraints.maxWidth;
                  if (bw <= 0) return const SizedBox.shrink();
                  final sx = shimmerPhase * (bw + 30) - 15;
                  return SizedBox(
                    height: height,
                    child: CustomPaint(
                      painter: _ShimmerPainter(x: sx, color: Colors.white, height: height),
                    ),
                  );
                },
              ),
            ),
          ),
        // Leading edge dot
        if (value > 0.02 && value < 0.98)
          FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 3,
                height: height + 2,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 5),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double x;
  final Color color;
  final double height;
  _ShimmerPainter({required this.x, required this.color, required this.height});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(x - 8, 0, 16, height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, color.withValues(alpha: 0.22), Colors.transparent],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) => old.x != x;
}
