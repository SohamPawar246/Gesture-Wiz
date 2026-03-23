import 'dart:math';
import 'package:flutter/material.dart';
import '../models/player_stats.dart';
import '../models/spell_upgrade.dart';
import '../models/spell.dart';
import '../game/palette.dart';
import 'glitch_text.dart';
import '../systems/audio_manager.dart';
import '../systems/achievement_manager.dart';
import '../models/gesture_cursor_controller.dart';
import 'gesture_cursor_overlay.dart';

class UpgradeScreen extends StatefulWidget {
  final PlayerStats playerStats;
  final GestureCursorController cursorController;
  final VoidCallback onBack;

  const UpgradeScreen({
    super.key,
    required this.playerStats,
    required this.cursorController,
    required this.onBack,
  });

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _scanCtrl;

  @override
  void initState() {
    super.initState();
    widget.playerStats.addListener(_onStatsChanged);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    widget.playerStats.removeListener(_onStatsChanged);
    super.dispose();
  }

  void _onStatsChanged() => setState(() {});

  void _attemptUpgrade(ActionType type) {
    if (widget.playerStats.spendSkillPoint(type)) {
      AudioManager.playSfx('menu_select.wav', volume: 0.6);
      if (widget.playerStats.upgrades.getLevel(type) >= 3) {
        AchievementManager.instance.unlock('archmage');
      }
    } else {
      AudioManager.playSfx('error.wav', volume: 0.5);
    }
  }

  // ── Branch-specific color theming ──
  Color _branchColor(ActionType type) {
    return switch (type) {
      ActionType.attack => const Color(0xFFFF6622),
      ActionType.shield => const Color(0xFF44DDFF),
      ActionType.push => const Color(0xFF44FF88),
      ActionType.ultimate => const Color(0xFFFFDD00),
      _ => Palette.fireGold,
    };
  }

  IconData _branchIcon(ActionType type) {
    return switch (type) {
      ActionType.attack => Icons.local_fire_department,
      ActionType.shield => Icons.shield,
      ActionType.push => Icons.favorite,
      ActionType.ultimate => Icons.flash_on,
      _ => Icons.star,
    };
  }

  String _branchTitle(ActionType type) {
    return switch (type) {
      ActionType.attack => 'FIRE BREACH',
      ActionType.shield => 'WARD MATRIX',
      ActionType.push => 'SYS RESTORE',
      ActionType.ultimate => 'OVERWATCH',
      _ => 'UNKNOWN',
    };
  }

  String _branchSubtitle(ActionType type) {
    return switch (type) {
      ActionType.attack => 'ATTACK',
      ActionType.shield => 'SHIELD',
      ActionType.push => 'HEAL',
      ActionType.ultimate => 'ULTIMATE',
      _ => '???',
    };
  }

  Widget _buildBranch(ActionType type) {
    final branchCol = _branchColor(type);
    final state = widget.playerStats.upgrades;
    final currentLevel = state.getLevel(type);
    final upgrades = SpellUpgrade.upgradeTree[type]!;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            // ── Branch header ──
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: branchCol.withValues(alpha: 0.08),
                    border: Border(
                      bottom: BorderSide(
                        color: branchCol
                            .withValues(alpha: 0.4 + _pulseCtrl.value * 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(_branchIcon(type), color: branchCol, size: 36),
                      const SizedBox(height: 6),
                      Text(
                        _branchTitle(type),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: branchCol,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(color: branchCol, blurRadius: 8),
                          ],
                        ),
                      ),
                      Text(
                        '[ ${_branchSubtitle(type)} ]',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 9,
                          color: branchCol.withValues(alpha: 0.6),
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 8),

            // ── Upgrade nodes ──
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // ── Circuit trace line ──
                      Positioned(
                        top: 0,
                        bottom: 0,
                        child: AnimatedBuilder(
                          animation: _scanCtrl,
                          builder: (context, _) {
                            return CustomPaint(
                              size: Size(
                                  4, constraints.maxHeight),
                              painter: _CircuitLinePainter(
                                color: branchCol,
                                unlockedLevels: currentLevel,
                                scanProgress: _scanCtrl.value,
                              ),
                            );
                          },
                        ),
                      ),

                      // ── Node cards ──
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(3, (index) {
                          return _buildNodeCard(
                            type: type,
                            index: index,
                            upgrade: upgrades[index],
                            isUnlocked: index < currentLevel,
                            isNext: index == currentLevel,
                            canAfford: widget.playerStats.skillPoints >=
                                upgrades[index].cost,
                            branchCol: branchCol,
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeCard({
    required ActionType type,
    required int index,
    required SpellUpgrade upgrade,
    required bool isUnlocked,
    required bool isNext,
    required bool canAfford,
    required Color branchCol,
  }) {
    final isAvailable = isNext && canAfford;
    final isApex = index == 2;

    Color borderColor;
    Color bgColor;
    Color textColor;
    double borderWidth;

    if (isUnlocked) {
      borderColor = branchCol;
      bgColor = branchCol.withValues(alpha: 0.12);
      textColor = branchCol;
      borderWidth = 2;
    } else if (isAvailable) {
      borderColor = branchCol.withValues(alpha: 0.9);
      bgColor = branchCol.withValues(alpha: 0.06);
      textColor = Palette.uiWhite;
      borderWidth = 2;
    } else if (isNext) {
      borderColor = Palette.impactRed.withValues(alpha: 0.4);
      bgColor = Palette.bgDeep;
      textColor = Palette.uiGrey;
      borderWidth = 1;
    } else {
      borderColor = Palette.uiGrey.withValues(alpha: 0.15);
      bgColor = Palette.bgDeep.withValues(alpha: 0.6);
      textColor = Palette.uiGrey.withValues(alpha: 0.5);
      borderWidth = 1;
    }

    void handleTap() {
      if (isAvailable) {
        _attemptUpgrade(type);
      } else if (isNext && !canAfford) {
        AudioManager.playSfx('error.wav', volume: 0.5);
      }
    }

    return GestureTapTarget(
      controller: widget.cursorController,
      onTap: handleTap,
      child: MouseRegion(
        cursor: isAvailable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: handleTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: borderWidth),
              borderRadius: BorderRadius.circular(isApex ? 12 : 6),
              boxShadow: [
                if (isUnlocked || isAvailable)
                  BoxShadow(
                    color: branchCol.withValues(alpha: isAvailable ? 0.5 : 0.2),
                    blurRadius: isAvailable ? 18 : 8,
                    spreadRadius: isAvailable ? 3 : 1,
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Level label
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isApex)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.auto_awesome, color: branchCol, size: 12),
                      ),
                    Text(
                      isApex ? 'APEX: ${upgrade.name}' : 'LV${index + 1}: ${upgrade.name}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.w800,
                        fontSize: isApex ? 11 : 12,
                        color: textColor,
                        letterSpacing: isApex ? 1.5 : 0.5,
                        shadows: isAvailable
                            ? [Shadow(color: branchCol, blurRadius: 6)]
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  upgrade.description,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 9,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                // Status indicator
                _buildStatusIndicator(
                  isUnlocked: isUnlocked,
                  isNext: isNext,
                  canAfford: canAfford,
                  cost: upgrade.cost,
                  branchCol: branchCol,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator({
    required bool isUnlocked,
    required bool isNext,
    required bool canAfford,
    required int cost,
    required Color branchCol,
  }) {
    if (isUnlocked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: branchCol, size: 14),
          const SizedBox(width: 4),
          Text(
            'ACTIVE',
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: branchCol,
              letterSpacing: 2,
            ),
          ),
        ],
      );
    }

    if (isNext) {
      final statusColor = canAfford ? branchCol : Palette.impactRed;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: statusColor.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(4),
          color: statusColor.withValues(alpha: 0.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              canAfford ? Icons.upgrade : Icons.lock_outline,
              color: statusColor,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              '$cost SP',
              style: TextStyle(
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: statusColor,
              ),
            ),
          ],
        ),
      );
    }

    return Icon(Icons.lock, color: Palette.uiGrey.withValues(alpha: 0.2), size: 12);
  }

  @override
  Widget build(BuildContext context) {
    final canUpgrade = widget.playerStats.skillPoints > 0;

    return Scaffold(
      backgroundColor: Palette.bgDeep,
      body: Stack(
        children: [
          // ── Animated cyber background ──
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _HexGridPainter(pulseValue: _pulseCtrl.value),
                );
              },
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ════ Header ════
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const GlitchText(
                              text: 'NEURAL AUGMENTATIONS',
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Palette.fireGold,
                                letterSpacing: 3,
                                shadows: [
                                  Shadow(color: Palette.fireDeep, blurRadius: 16),
                                ],
                              ),
                              glitchIntensity: 0.08,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'UPGRADE YOUR ABILITIES  ·  LEVEL ${widget.playerStats.level}',
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 10,
                                color: Palette.uiGrey.withValues(alpha: 0.6),
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // SP Badge
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, _) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: Palette.bgDark,
                              border: Border.all(
                                color: canUpgrade
                                    ? Palette.fireGold
                                        .withValues(alpha: 0.7 + 0.3 * _pulseCtrl.value)
                                    : Palette.uiGrey.withValues(alpha: 0.3),
                                width: canUpgrade ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: canUpgrade
                                  ? [
                                      BoxShadow(
                                        color: Palette.fireGold.withValues(
                                            alpha: 0.2 + 0.15 * _pulseCtrl.value),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.memory,
                                    color: canUpgrade
                                        ? Palette.fireGold
                                        : Palette.uiGrey,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.playerStats.skillPoints} SP',
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: canUpgrade
                                        ? Palette.fireGold
                                        : Palette.uiGrey,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ════ Tech Tree ════
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 180, bottom: 20, top: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBranch(ActionType.attack),
                        _buildBranch(ActionType.shield),
                        _buildBranch(ActionType.push),
                        _buildBranch(ActionType.ultimate),
                      ],
                    ),
                  ),
                ),

                // ════ Footer ════
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    children: [
                      GestureTapTarget(
                        controller: widget.cursorController,
                        onTap: widget.onBack,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: widget.onBack,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 12),
                              decoration: BoxDecoration(
                                color: Palette.bgDark.withValues(alpha: 0.8),
                                border:
                                    Border.all(color: Palette.fireMid, width: 2),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Palette.fireMid.withValues(alpha: 0.2),
                                      blurRadius: 10)
                                ],
                              ),
                              child: const Text(
                                '< DISCONNECT',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Palette.fireMid,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Legend
                      _legendDot(Palette.fireGold, 'ACTIVE'),
                      const SizedBox(width: 12),
                      _legendDot(const Color(0xFF44DDFF), 'AVAILABLE'),
                      const SizedBox(width: 12),
                      _legendDot(Palette.uiGrey, 'LOCKED'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Scanline overlay ──
          IgnorePointer(
            child: ColoredBox(
              color: Palette.scanLine,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Courier',
            fontSize: 8,
            color: color.withValues(alpha: 0.7),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Circuit line between nodes — animates a scan pulse down the trace
// ══════════════════════════════════════════════════════════════════════════
class _CircuitLinePainter extends CustomPainter {
  final Color color;
  final int unlockedLevels;
  final double scanProgress;

  _CircuitLinePainter({
    required this.color,
    required this.unlockedLevels,
    required this.scanProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final cx = size.width / 2;

    // Base dim trace
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, 0), Offset(cx, h), basePaint);

    // Unlocked portion (brighter)
    if (unlockedLevels > 0) {
      final unlockFraction = (unlockedLevels / 3.0).clamp(0.0, 1.0);
      final unlockPaint = Paint()
        ..color = color.withValues(alpha: 0.6)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
          Offset(cx, 0), Offset(cx, h * unlockFraction), unlockPaint);

      // Glow on unlocked part
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
          Offset(cx, 0), Offset(cx, h * unlockFraction), glowPaint);
    }

    // Scanning pulse dot
    final scanY = h * scanProgress;
    canvas.drawCircle(
      Offset(cx, scanY),
      3,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _CircuitLinePainter old) =>
      old.scanProgress != scanProgress || old.unlockedLevels != unlockedLevels;
}

// ══════════════════════════════════════════════════════════════════════════
// Hexagonal grid background with pulsing glow nodes
// ══════════════════════════════════════════════════════════════════════════
class _HexGridPainter extends CustomPainter {
  final double pulseValue;
  _HexGridPainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Palette.bgHighlight.withValues(alpha: 0.025 + pulseValue * 0.015)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const spacing = 55.0;
    final random = Random(42);

    // Hex grid
    for (double y = 0; y < size.height + spacing; y += spacing * 0.866) {
      final row = (y / (spacing * 0.866)).floor();
      final xOff = (row % 2 == 0) ? 0.0 : spacing * 0.5;
      for (double x = xOff; x < size.width + spacing; x += spacing) {
        _drawHex(canvas, Offset(x, y), spacing * 0.48, paint);
      }
    }

    // Random glow nodes
    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 25; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final bright = random.nextBool();
      nodePaint.color = bright
          ? Palette.fireGold.withValues(alpha: 0.08 + pulseValue * 0.1)
          : Palette.bgHighlight.withValues(alpha: 0.06);
      canvas.drawCircle(Offset(x, y), bright ? 2.5 : 1.5, nodePaint);
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3) * i - pi / 6;
      final px = center.dx + r * cos(angle);
      final py = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HexGridPainter old) =>
      old.pulseValue != pulseValue;
}
