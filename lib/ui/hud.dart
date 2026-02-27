import 'package:flutter/material.dart';

import 'grimoire_screen.dart';
import '../systems/gesture/gesture_type.dart';
import '../models/player_stats.dart';
import '../models/spell.dart';
import '../game/palette.dart';

class HUD extends StatelessWidget {
  final GestureType activeGesture;
  final List<GestureType> currentCombo;
  final double timeoutProgress;
  final PlayerStats playerStats;
  final List<Spell> knownSpells;

  const HUD({
    super.key,
    required this.activeGesture,
    required this.currentCombo,
    required this.timeoutProgress,
    required this.playerStats,
    required this.knownSpells,
  });

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
                  _buildTopRight(context),
                ],
              ),
              
              const Spacer(),
              
              // Combo Tracker
              if (currentCombo.isNotEmpty) _buildComboTracker(),
              
              const Spacer(),
              
              // Bottom Bar — Active Gesture indicator
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Palette.uiDarkPanel,
                    border: Border.all(color: Palette.fireMid.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Text(
                    activeGesture.displayName.toUpperCase(),
                    style: const TextStyle(
                      color: Palette.fireGold,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 4.0,
                      shadows: [
                        Shadow(blurRadius: 8, color: Palette.fireDeep),
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

  Widget _buildTopRight(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Wave counter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Palette.uiDarkPanel,
            border: Border.all(color: Palette.fireMid.withValues(alpha: 0.4), width: 1.5),
          ),
          child: Text(
            'WAVE ${playerStats.currentWave}/10',
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
        const SizedBox(height: 6),
        // Grimoire button
        _buildGrimoireButton(context),
      ],
    );
  }

  Widget _buildGrimoireButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GrimoireScreen(knownSpells: knownSpells)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Palette.uiDarkPanel,
          border: Border.all(color: Palette.fireMid.withValues(alpha: 0.4), width: 1.5),
        ),
        child: const Icon(Icons.menu_book, size: 28, color: Palette.fireGold),
      ),
    );
  }

  Widget _buildComboTracker() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: currentCombo.map((g) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Palette.fireDeep.withValues(alpha: 0.6),
                    border: Border.all(color: Palette.fireGold.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    g.displayName.toUpperCase(),
                    style: const TextStyle(
                      color: Palette.fireGold,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              value: 1.0 - timeoutProgress,
              color: Palette.fireGold,
              backgroundColor: Palette.bgMid.withValues(alpha: 0.4),
              minHeight: 3,
            ),
          ),
        ],
      ),
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
          // XP bar
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
