import 'package:flutter/material.dart';

import '../models/spell.dart';
import '../systems/gesture/gesture_type.dart';
import '../game/palette.dart';

class GrimoireScreen extends StatelessWidget {
  final List<Spell> knownSpells;

  const GrimoireScreen({super.key, required this.knownSpells});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.bgDeep,
      appBar: AppBar(
        title: const Text(
          'GRIMOIRE',
          style: TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            letterSpacing: 6.0,
            color: Palette.fireGold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Palette.fireGold),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: knownSpells.length,
        itemBuilder: (context, index) {
          final spell = knownSpells[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Palette.uiDarkPanel,
              border: Border.all(
                color: spell.effectColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      spell.name.toUpperCase(),
                      style: TextStyle(
                        color: spell.effectColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        letterSpacing: 3.0,
                      ),
                    ),
                    Text(
                      'MANA: ${spell.manaCost.toInt()}',
                      style: const TextStyle(
                        color: Palette.uiMana,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'GESTURE SEQUENCE:',
                  style: TextStyle(
                    color: Palette.uiGrey,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: spell.requiredGestures.map((g) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Palette.fireDeep.withValues(alpha: 0.4),
                        border: Border.all(color: Palette.fireMid.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        g.displayName.toUpperCase(),
                        style: const TextStyle(
                          color: Palette.fireGold,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
