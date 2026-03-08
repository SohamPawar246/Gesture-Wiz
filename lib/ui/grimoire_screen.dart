import 'package:flutter/material.dart';

import '../models/spell.dart';
import '../game/palette.dart';
import '../systems/gesture/gesture_type.dart';

/// Displays the player's available actions and their gesture mappings.
/// Replaces the old Grimoire spell-combo screen.
class GrimoireScreen extends StatelessWidget {
  final List<GameAction> knownActions;

  const GrimoireScreen({super.key, required this.knownActions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bgDeep,
      appBar: AppBar(
        title: const Text(
          'ACTIONS',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            color: Palette.fireGold,
          ),
        ),
        backgroundColor: Palette.bgDark,
        iconTheme: const IconThemeData(color: Palette.fireGold),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: knownActions.length,
        itemBuilder: (context, index) {
          final action = knownActions[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Palette.uiDarkPanel,
              border: Border.all(
                color: action.effectColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Color indicator
                Container(width: 8, height: 40, color: action.effectColor),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.name.toUpperCase(),
                        style: TextStyle(
                          color: action.effectColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gesture: ${action.gesture.displayName} | Mana: ${action.manaCost.toInt()} | Cooldown: ${action.cooldown}s',
                        style: const TextStyle(
                          color: Palette.uiGrey,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
