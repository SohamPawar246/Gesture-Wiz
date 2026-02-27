import 'package:flutter/material.dart';

import '../game/palette.dart';

class GameOverScreen extends StatelessWidget {
  final bool isVictory;
  final int score;
  final int kills;
  final int wave;
  final VoidCallback onRestart;

  const GameOverScreen({
    super.key,
    required this.isVictory,
    required this.score,
    required this.kills,
    required this.wave,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.bgDeep.withValues(alpha: 0.92),
      child: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Palette.uiDarkPanel,
            border: Border.all(
              color: isVictory ? Palette.fireGold : Palette.impactRed,
              width: 2.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                isVictory ? 'VICTORY' : 'GAME OVER',
                style: TextStyle(
                  color: isVictory ? Palette.fireGold : Palette.impactRed,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: 6.0,
                  shadows: [
                    Shadow(
                      blurRadius: 16,
                      color: isVictory ? Palette.fireDeep : Palette.impactRed,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Stats
              _statRow('SCORE', '$score'),
              const SizedBox(height: 12),
              _statRow('KILLS', '$kills'),
              const SizedBox(height: 12),
              _statRow('WAVE', '$wave / 10'),
              const SizedBox(height: 36),

              // Restart button
              GestureDetector(
                onTap: onRestart,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: Palette.fireDeep.withValues(alpha: 0.6),
                    border: Border.all(color: Palette.fireGold, width: 2),
                  ),
                  child: const Text(
                    'PLAY AGAIN',
                    style: TextStyle(
                      color: Palette.fireGold,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 4.0,
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

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Palette.uiGrey,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Palette.uiWhite,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
