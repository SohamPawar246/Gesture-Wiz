import 'package:flutter/material.dart';

import '../game/palette.dart';

class TutorialScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const TutorialScreen({super.key, required this.onComplete});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _step = 0;

  static const List<_TutorialStep> _steps = [
    _TutorialStep(
      icon: Icons.pinch,
      title: 'READY TO SNAP',
      description: 'Pinch your THUMB and\nMIDDLE FINGER together',
      color: Palette.fireGold,
    ),
    _TutorialStep(
      icon: Icons.touch_app,
      title: 'SNAP!',
      description: 'Slide fingers to snap\nand leave INDEX POINTING',
      color: Palette.fireBright,
    ),
    _TutorialStep(
      icon: Icons.local_fire_department,
      title: 'FIREBALL!',
      description: 'Pinch → Point = SNAP!\nSnap at enemies to\ncast FIREBALL!',
      color: Palette.impactRed,
    ),
  ];

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];

    return Container(
      color: Palette.bgDeep,
      child: Center(
        child: GestureDetector(
          onTap: _next,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Container(
              key: ValueKey(_step),
              width: 400,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Palette.uiDarkPanel,
                border: Border.all(color: step.color.withValues(alpha: 0.5), width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Step indicator
                  Text(
                    '${_step + 1} / ${_steps.length}',
                    style: const TextStyle(
                      color: Palette.uiGrey,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Icon
                  Icon(step.icon, size: 64, color: step.color),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    step.title,
                    style: TextStyle(
                      color: step.color,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 4,
                      shadows: [
                        Shadow(blurRadius: 12, color: step.color.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    step.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Palette.uiWhite,
                      fontFamily: 'monospace',
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Continue hint
                  Text(
                    _step < _steps.length - 1 ? 'TAP TO CONTINUE →' : 'TAP TO START GAME →',
                    style: TextStyle(
                      color: Palette.fireGold.withValues(alpha: 0.6),
                      fontFamily: 'monospace',
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialStep {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
