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

class _UpgradeScreenState extends State<UpgradeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    widget.playerStats.addListener(_onStatsChanged);
    _pulseCtrl = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    widget.playerStats.removeListener(_onStatsChanged);
    super.dispose();
  }

  void _onStatsChanged() {
    setState(() {});
  }

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

  Widget _buildSkillTreeBranch(ActionType type, String title, IconData icon) {
    final state = widget.playerStats.upgrades;
    final currentLevel = state.getLevel(type);
    final upgrades = SpellUpgrade.upgradeTree[type]!;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Palette.bgDark.withValues(alpha: 0.7),
          border: Border.all(color: Palette.bgHighlight.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Palette.bgHighlight.withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ]
        ),
        child: Column(
          children: [
            Icon(icon, color: Palette.fireGold, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Palette.uiWhite,
                letterSpacing: 2.0,
                shadows: [Shadow(color: Palette.fireGold, blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Connecting vertical line
                  Positioned(
                    top: 20,
                    bottom: 20,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Palette.fireGold.withValues(alpha: currentLevel > 0 ? 0.8 : 0.2),
                            Palette.fireGold.withValues(alpha: currentLevel > 1 ? 0.8 : 0.2),
                            Palette.fireGold.withValues(alpha: currentLevel > 2 ? 0.8 : 0.2),
                          ]
                        )
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(3, (index) {
                      final upgrade = upgrades[index];
                      final isUnlocked = index < currentLevel;
                      final isNext = index == currentLevel;
                      final canAfford = widget.playerStats.skillPoints >= upgrade.cost;
                      final isAvailable = isNext && canAfford;

                      Color borderColor = Palette.uiGrey.withValues(alpha: 0.3);
                      Color bgColor = Palette.bgDeep;
                      Color textColor = Palette.uiGrey;

                      if (isUnlocked) {
                        borderColor = Palette.fireGold;
                        bgColor = Palette.fireGold.withValues(alpha: 0.15);
                        textColor = Palette.fireGold;
                      } else if (isNext) {
                        borderColor = canAfford ? Palette.bgHighlight : Palette.impactRed.withValues(alpha: 0.5);
                        bgColor = canAfford ? Palette.bgHighlight.withValues(alpha: 0.2) : Palette.bgDeep;
                        textColor = canAfford ? Palette.uiWhite : Palette.uiGrey;
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
                          cursor: (isAvailable || isUnlocked) ? SystemMouseCursors.click : SystemMouseCursors.basic,
                          child: GestureDetector(
                            onTap: handleTap,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              decoration: BoxDecoration(
                                color: bgColor,
                                border: Border.all(color: borderColor, width: isAvailable ? 2 : 1),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: (isUnlocked || isAvailable) ? [
                                  BoxShadow(
                                    color: borderColor.withValues(alpha: isAvailable ? 0.6 : 0.3),
                                    blurRadius: isAvailable ? 16 : 8,
                                    spreadRadius: isAvailable ? 2 : 1,
                                  )
                                ] : [],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'LVL ${index + 1}: ${upgrade.name}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: textColor,
                                      shadows: isAvailable ? [Shadow(color: textColor, blurRadius: 10)] : null,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    upgrade.description,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: 10,
                                      color: textColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isUnlocked)
                                        Icon(Icons.check_circle, color: Palette.fireGold, size: 16)
                                      else if (isNext)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(canAfford ? Icons.upgrade : Icons.lock_outline,
                                                color: canAfford ? Palette.bgHighlight : Palette.impactRed, size: 16),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${upgrade.cost} SP',
                                              style: TextStyle(
                                                fontFamily: 'Courier',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: canAfford ? Palette.bgHighlight : Palette.impactRed,
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Icon(Icons.lock, color: Palette.uiGrey.withValues(alpha: 0.3), size: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bgDeep,
      body: Stack(
        children: [
          // Cyberpunk Background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _CyberBackgroundPainter(pulseValue: _pulseCtrl.value),
                );
              }
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const GlitchText(
                        text: 'NEURAL AUGMENTATIONS',
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Palette.fireGold,
                          letterSpacing: 4,
                          shadows: [Shadow(color: Palette.fireDeep, blurRadius: 20)],
                        ),
                        glitchIntensity: 0.1,
                      ),
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, _) {
                          final canUpgrade = widget.playerStats.skillPoints > 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Palette.bgDark,
                              border: Border.all(
                                color: canUpgrade ? Palette.bgHighlight : Palette.uiGrey.withValues(alpha: 0.5),
                                width: canUpgrade ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: canUpgrade ? [
                                BoxShadow(
                                  color: Palette.bgHighlight.withValues(alpha: 0.3 + 0.2 * _pulseCtrl.value),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                )
                              ] : [],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.memory, color: canUpgrade ? Palette.uiWhite : Palette.uiGrey),
                                const SizedBox(width: 8),
                                Text(
                                  'AVAILABLE SP: ${widget.playerStats.skillPoints}',
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: canUpgrade ? Palette.uiWhite : Palette.uiGrey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    ],
                  ),
                ),
                
                // Upgrade Tree UI
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSkillTreeBranch(ActionType.attack, 'FIREWALL BREACH\n[ ATTACK ]', Icons.local_fire_department),
                        _buildSkillTreeBranch(ActionType.shield, 'DEFLECTOR WARD\n[ SHIELD ]', Icons.security),
                        _buildSkillTreeBranch(ActionType.push, 'SYSTEM RESTORE\n[ HEAL ]', Icons.healing),
                        _buildSkillTreeBranch(ActionType.ultimate, 'OVERWATCH PULSE\n[ ULTIMATE ]', Icons.warning_amber_rounded),
                      ],
                    ),
                  ),
                ),

                // Footer (Back)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: GestureTapTarget(
                      controller: widget.cursorController,
                      onTap: widget.onBack,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.onBack,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            decoration: BoxDecoration(
                              color: Palette.bgDark.withValues(alpha: 0.8),
                              border: Border.all(color: Palette.fireMid, width: 2),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(color: Palette.fireMid.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1)
                              ],
                            ),
                            child: const Text(
                              '< DISCONNECT',
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Palette.fireMid,
                                letterSpacing: 3,
                                shadows: [Shadow(color: Palette.fireGold, blurRadius: 5)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Subtle Cyber Scanline Overlay
          IgnorePointer(
            child: Container(
              color: Palette.scanline,
            ),
          ),
        ],
      ),
    );
  }
}

class _CyberBackgroundPainter extends CustomPainter {
  final double pulseValue;
  
  _CyberBackgroundPainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Hexagonal / Grid Matrix
    final paint = Paint()
      ..color = Palette.bgHighlight.withValues(alpha: 0.03 + (pulseValue * 0.02))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const gridSize = 60.0;
    
    // Draw grid
    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    
    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw random glowing nodes at intersections
    final random = Random(42); // deterministic for stable positions
    final nodePaint = Paint()..style = PaintingStyle.fill;
    
    for (int i = 0; i < 40; i++) {
      final x = (random.nextInt((size.width / gridSize).ceil()) * gridSize);
      final y = (random.nextInt((size.height / gridSize).ceil()) * gridSize);
      final isBright = random.nextBool();
      
      nodePaint.color = isBright 
          ? Palette.fireGold.withValues(alpha: 0.15 + (pulseValue * 0.15))
          : Palette.bgHighlight.withValues(alpha: 0.1);
          
      canvas.drawCircle(Offset(x, y), isBright ? 3 : 2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberBackgroundPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue;
  }
}
