import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../models/gesture_cursor_controller.dart';
import 'gesture_cursor_overlay.dart';

class TutorialScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final GestureCursorController? controller;

  const TutorialScreen({super.key, required this.onComplete, this.controller});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;

  static const List<_TutorialStep> _steps = [
    _TutorialStep(
      icon: '☝',
      emoji: true,
      title: 'POINT',
      subtitle: 'FIRE BOLT',
      description:
          'Extend your INDEX FINGER\nto cast a fire bolt.\nTargets the nearest enemy.',
      color: Color(0xFFFF6622),
    ),
    _TutorialStep(
      icon: '✊',
      emoji: true,
      title: 'FIST',
      subtitle: 'FORCE PUSH',
      description: 'Clench your fist\nto release a powerful\nAoE force wave.',
      color: Color(0xFF9944FF),
    ),
    _TutorialStep(
      icon: '🖐',
      emoji: true,
      title: 'OPEN PALM',
      subtitle: 'WARD SHIELD',
      description: 'Hold your palm open\nto block incoming\nenemy spells.',
      color: Color(0xFF44DDFF),
    ),
    _TutorialStep(
      icon: '✌',
      emoji: true,
      title: 'V SIGN',
      subtitle: 'OVERWATCH PULSE',
      description:
          'Flash a V sign\nto unleash your ULTIMATE —\neliminate all enemies!',
      color: Color(0xFFFFFF44),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _steps.length - 1) {
      _slideCtrl.forward(from: 0);
      setState(() => _step++);
    } else {
      widget.onComplete();
    }
  }

  void _skip() => widget.onComplete();

  Widget _gestureWrap({required Widget child, required VoidCallback onTap}) {
    final ctrl = widget.controller;
    if (ctrl == null) return child;
    return GestureTapTarget(controller: ctrl, onTap: onTap, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final ctrl = widget.controller;

    final body = Stack(
      children: [
        // Background gradient
        Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF040808),
                        Color(0xFF0A0F0F),
                        Color(0xFF180808),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),

                // Bottom fire glow
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 150,
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0x55CC3300), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
        // Content
        SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PYROMANCER',
                        style: TextStyle(
                          color: Palette.fireGold,
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                      _gestureWrap(
                        onTap: _skip,
                        child: GestureDetector(
                          onTap: _skip,
                          child: const Text(
                            'SKIP  →',
                            style: TextStyle(
                              color: Palette.uiGrey,
                              fontFamily: 'monospace',
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Step indicators
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: List.generate(_steps.length, (i) {
                      final active = i == _step;
                      final done = i < _step;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: done
                                ? Palette.fireGold
                                : active
                                ? step.color
                                : Palette.uiGrey.withValues(alpha: 0.3),
                            boxShadow: active
                                ? [
                                    BoxShadow(
                                      color: step.color.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const Spacer(flex: 2),

                // Card
                _gestureWrap(
                  onTap: _next,
                  child: GestureDetector(
                    onTap: _next,
                    child: AnimatedBuilder(
                    animation: _slideCtrl,
                    builder: (context, child) {
                      final slide = CurvedAnimation(
                        parent: _slideCtrl,
                        curve: Curves.easeOut,
                      ).value;
                      return Transform.translate(
                        offset: Offset(30 * (1 - slide), 0),
                        child: Opacity(
                          opacity: slide.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 400,
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: const Color(0xDD060C0C),
                        border: Border.all(
                          color: step.color.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: step.color.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Gesture icon
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (context, _) {
                              final glow = 0.5 + 0.5 * _pulseCtrl.value;
                              return Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: step.color.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: step.color.withValues(
                                      alpha: glow * 0.7,
                                    ),
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: step.color.withValues(
                                        alpha: glow * 0.3,
                                      ),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    step.icon,
                                    style: const TextStyle(fontSize: 48),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),

                          // Gesture name
                          Text(
                            step.title,
                            style: TextStyle(
                              color: step.color,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              letterSpacing: 6,
                              shadows: [
                                Shadow(
                                  blurRadius: 14,
                                  color: step.color.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Action name
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: step.color.withValues(alpha: 0.12),
                              border: Border.all(
                                color: step.color.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              step.subtitle,
                              style: TextStyle(
                                color: step.color.withValues(alpha: 0.9),
                                fontFamily: 'monospace',
                                fontSize: 12,
                                letterSpacing: 3,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Description
                          Text(
                            step.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFBBBBBB),
                              fontFamily: 'monospace',
                              fontSize: 14,
                              height: 1.7,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Continue prompt
                          Text(
                            _step < _steps.length - 1
                                ? 'TAP TO CONTINUE  →'
                                : '▶  TAP TO ENTER THE DUNGEON',
                            style: TextStyle(
                              color: Palette.fireGold.withValues(alpha: 0.65),
                              fontFamily: 'monospace',
                              fontSize: 11,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ],
    );

    return Scaffold(
      backgroundColor: Palette.bgDeep,
      body: ctrl != null
          ? AnimatedBuilder(
              animation: ctrl,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  (ctrl.faceX - 0.5) * 65.0,
                  (ctrl.faceY - 0.5) * 35.0,
                ),
                child: child,
              ),
              child: body,
            )
          : body,
    );
  }
}

class _TutorialStep {
  final String icon;
  final bool emoji;
  final String title;
  final String subtitle;
  final String description;
  final Color color;

  const _TutorialStep({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
  });
}
