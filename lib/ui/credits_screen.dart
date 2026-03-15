import 'dart:math';
import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../models/gesture_cursor_controller.dart';
import 'gesture_cursor_overlay.dart';

class CreditsScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final GestureCursorController? controller;

  const CreditsScreen({super.key, required this.onContinue, this.controller});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _particleCtrl;
  final List<_CreditParticle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )
      ..addListener(_tickParticles)
      ..repeat();

    for (int i = 0; i < 30; i++) {
      _particles.add(_CreditParticle.random(_rng));
    }
  }

  void _tickParticles() {
    setState(() {
      for (final p in _particles) {
        p.update(0.05);
        if (p.alpha <= 0) p.reset(_rng);
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  Widget _wrapGesture({required Widget child, required VoidCallback onTap}) {
    final ctrl = widget.controller;
    if (ctrl == null) return child;
    return GestureTapTarget(controller: ctrl, onTap: onTap, child: child);
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Palette.fireGold;

    return Scaffold(
      backgroundColor: const Color(0xFF030808),
      body: GestureDetector(
        onTap: widget.onContinue,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            CustomPaint(
              painter: _CreditParticlePainter(_particles),
              child: const SizedBox.expand(),
            ),
            FadeTransition(
              opacity: _fadeCtrl,
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (context, _) {
                            final glow = 0.6 + 0.4 * _pulseCtrl.value;
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'THE EYE PROTOCOL',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  letterSpacing: 6,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 20 * glow,
                                      color: accentColor.withValues(
                                        alpha: 0.7 * glow,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'CREDITS',
                          style: TextStyle(
                            color: accentColor.withValues(alpha: 0.5),
                            fontFamily: 'monospace',
                            fontSize: 10,
                            letterSpacing: 6,
                          ),
                        ),

                        const SizedBox(height: 16),
                        _buildDivider(accentColor),
                        const SizedBox(height: 16),

                        _creditSection('DEVELOPED BY', ['SOHAM PAWAR']),
                        const SizedBox(height: 14),
                        _creditSection('BUILT WITH', [
                          'FLUTTER + FLAME  \u2022  MEDIAPIPE  \u2022  DART',
                        ]),
                        const SizedBox(height: 14),
                        _creditSection('INSPIRED BY', [
                          '1984  \u2022  CYBERPUNK  \u2022  RETRO CRT',
                        ]),
                        const SizedBox(height: 14),
                        _creditSection('SPECIAL THANKS', [
                          'PLAYTESTERS  \u2022  OPEN SOURCE  \u2022  JAM ORGANIZERS',
                        ]),

                        const SizedBox(height: 16),
                        _buildDivider(accentColor),
                        const SizedBox(height: 16),

                        Text(
                          'BIG BROTHER HAS BEEN DEFEATED.\nTHE GRID IS FREE.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF44FF44).withValues(
                              alpha: 0.6,
                            ),
                            fontFamily: 'monospace',
                            fontSize: 10,
                            letterSpacing: 2,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: 20),

                        _wrapGesture(
                          onTap: widget.onContinue,
                          child: _CreditsButton(
                            label: 'CONTINUE',
                            color: accentColor,
                            onTap: widget.onContinue,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'PRESS ANYWHERE TO CONTINUE',
                          style: TextStyle(
                            color: Palette.uiGrey.withValues(alpha: 0.4),
                            fontFamily: 'monospace',
                            fontSize: 9,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        return Container(
          width: 280,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                color.withValues(alpha: 0.3 + 0.2 * _pulseCtrl.value),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _creditSection(String title, List<String> lines) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Palette.fireGold.withValues(alpha: 0.55),
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 4,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        for (final line in lines)
          Text(
            line,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFCCCCCC),
              fontFamily: 'monospace',
              fontSize: 12,
              letterSpacing: 1.5,
              height: 1.5,
            ),
          ),
      ],
    );
  }
}

class _CreditsButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CreditsButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_CreditsButton> createState() => _CreditsButtonState();
}

class _CreditsButtonState extends State<_CreditsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.15)
                : widget.color.withValues(alpha: 0.04),
            border: Border.all(
              color: widget.color.withValues(alpha: _hovered ? 0.9 : 0.5),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? Colors.white : widget.color,
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreditParticle {
  double x, y, vy, alpha, size;

  _CreditParticle({
    required this.x,
    required this.y,
    required this.vy,
    required this.alpha,
    required this.size,
  });

  factory _CreditParticle.random(Random rng) {
    return _CreditParticle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      vy: -(0.001 + rng.nextDouble() * 0.005),
      alpha: 0.1 + rng.nextDouble() * 0.3,
      size: 1.0 + rng.nextDouble() * 2.0,
    );
  }

  void reset(Random rng) {
    x = rng.nextDouble();
    y = 1.05;
    vy = -(0.001 + rng.nextDouble() * 0.005);
    alpha = 0.1 + rng.nextDouble() * 0.3;
    size = 1.0 + rng.nextDouble() * 2.0;
  }

  void update(double dt) {
    y += vy;
    alpha -= dt * 0.08;
  }
}

class _CreditParticlePainter extends CustomPainter {
  final List<_CreditParticle> particles;
  _CreditParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.alpha <= 0) continue;
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        Paint()
          ..color = Palette.fireGold.withValues(alpha: p.alpha.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CreditParticlePainter old) => true;
}
