import 'package:flutter/material.dart';

import '../game/palette.dart';

/// Full-screen epilepsy / photosensitivity warning.
///
/// Lifecycle: 1 s fade-in → 2.5 s hold → 1 s fade-out → calls [onComplete].
class EpilepsyWarningScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const EpilepsyWarningScreen({super.key, required this.onComplete});

  @override
  State<EpilepsyWarningScreen> createState() => _EpilepsyWarningScreenState();
}

class _EpilepsyWarningScreenState extends State<EpilepsyWarningScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Duration breakdown (total 4.5 s):
  static const double _fadeInEnd = 1.0 / 4.5; // 0 → 1 s
  static const double _fadeOutStart = 3.5 / 4.5; // 3.5 s → 4.5 s

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 4500),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onComplete();
          }
        });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _opacity(double t) {
    if (t < _fadeInEnd) return t / _fadeInEnd;
    if (t > _fadeOutStart) return (1.0 - t) / (1.0 - _fadeOutStart);
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final opacity = _opacity(_ctrl.value).clamp(0.0, 1.0);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Opacity(
            opacity: opacity,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0000),
                    border: Border.all(
                      color: const Color(0xFFFF2222),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55FF0000),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning icon
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFFF3333),
                        size: 52,
                      ),

                      const SizedBox(height: 16),

                      // Title
                      const Text(
                        'EPILEPSY WARNING',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFF3333),
                          fontFamily: 'monospace',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 5,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Container(
                        height: 1,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFFFF3333),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Body text
                      const Text(
                        'This game contains rapidly flashing lights,\n'
                        'bright colour transitions, and strobing\n'
                        'visual effects that may trigger seizures\n'
                        'or cause discomfort in photosensitive individuals.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFCCCCCC),
                          fontFamily: 'monospace',
                          fontSize: 13,
                          height: 1.75,
                          letterSpacing: 0.4,
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'If you or anyone nearby has a history of\n'
                        'epilepsy or light-triggered seizures,\n'
                        'please consult a doctor before playing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF999999),
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.75,
                          letterSpacing: 0.4,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Dismiss hint
                      Text(
                        'CONTINUING IN A MOMENT…',
                        style: TextStyle(
                          color: Palette.fireGold.withValues(alpha: 0.5),
                          fontFamily: 'monospace',
                          fontSize: 10,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
