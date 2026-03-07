import 'package:flutter/material.dart';

import '../systems/gesture/gesture_type.dart';
import '../models/player_stats.dart';
import '../game/palette.dart';

class HUD extends StatelessWidget {
  final GestureType activeGesture;
  final PlayerStats playerStats;

  const HUD({
    super.key,
    required this.activeGesture,
    required this.playerStats,
  });

  /// Maps gesture to its action name for display
  String _gestureActionName(GestureType gesture) {
    switch (gesture) {
      case GestureType.none:
        return 'SCANNING';
      case GestureType.point:
        return 'FIRE BOLT';
      case GestureType.fist:
        return 'FORCE PUSH';
      case GestureType.openPalm:
        return 'WARD SHIELD';
      case GestureType.pinch:
        return 'GRAB';
      case GestureType.vSign:
        return 'OVERWATCH';
    }
  }

  Color _gestureColor(GestureType gesture) {
    switch (gesture) {
      case GestureType.none:
        return Palette.uiGrey;
      case GestureType.point:
        return const Color(0xFFFF6622);
      case GestureType.fist:
        return const Color(0xFF8844FF);
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
    return Positioned.fill(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsBox(),
                  _buildTopRight(),
                ],
              ),
              
              const Spacer(),
              
              // Bottom — Active action indicator
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: Palette.uiDarkPanel,
                    border: Border.all(
                      color: _gestureColor(activeGesture).withValues(alpha: 0.6), 
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _gestureActionName(activeGesture),
                    style: TextStyle(
                      color: _gestureColor(activeGesture),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 4.0,
                      shadows: [
                        Shadow(blurRadius: 10, color: _gestureColor(activeGesture).withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRight() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Chamber counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Palette.uiDarkPanel,
            border: Border.all(color: Palette.fireMid.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Text(
            'CHAMBER ${playerStats.currentWave}/10',
            style: const TextStyle(
              color: Palette.fireGold,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              fontSize: 14,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Score
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Palette.uiDarkPanel,
            border: Border.all(color: Palette.fireMid.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Text(
            'SCORE: ${playerStats.score}',
            style: const TextStyle(
              color: Palette.uiWhite,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBox() {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Palette.uiDarkPanel,
        border: Border.all(color: Palette.fireMid.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Level & XP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("LV.${playerStats.level}", 
                style: const TextStyle(
                  color: Palette.fireGold,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  letterSpacing: 2.0,
                )),
              Text("${playerStats.currentXp}/${playerStats.maxXp} XP",
                style: const TextStyle(
                  color: Palette.uiGrey,
                  fontFamily: 'monospace',
                  fontSize: 11,
                )),
            ],
          ),
          const SizedBox(height: 4),
          _buildBar(
            value: playerStats.currentXp / playerStats.maxXp,
            color: Palette.uiXp,
            height: 5,
          ),
          const SizedBox(height: 10),
          
          // HP Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("HP", style: TextStyle(
                color: Palette.impactRed,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 2.0,
              )),
              Text("${playerStats.currentHp.toInt()}/${playerStats.maxHp.toInt()}",
                style: const TextStyle(
                  color: Palette.uiGrey,
                  fontFamily: 'monospace',
                  fontSize: 11,
                )),
            ],
          ),
          const SizedBox(height: 4),
          _buildBar(
            value: playerStats.currentHp / playerStats.maxHp,
            color: Palette.impactRed,
            height: 10,
          ),
          const SizedBox(height: 10),
          
          // Mana Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("MANA", style: TextStyle(
                color: Palette.uiMana,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 2.0,
              )),
              Text("${playerStats.currentMana.toInt()}/${playerStats.maxMana.toInt()}",
                style: const TextStyle(
                  color: Palette.uiGrey,
                  fontFamily: 'monospace',
                  fontSize: 11,
                )),
            ],
          ),
          const SizedBox(height: 4),
          _buildBar(
            value: playerStats.currentMana / playerStats.maxMana,
            color: Palette.uiMana,
            height: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildBar({required double value, required Color color, double height = 8}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Palette.bgMid.withValues(alpha: 0.5),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(color: color),
      ),
    );
  }
}
