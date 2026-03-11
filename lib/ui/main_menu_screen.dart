import 'dart:math';
import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../models/gesture_cursor_controller.dart';
import 'gesture_cursor_overlay.dart';

/// Epic animated main menu screen with fire particles, glowing title, and gesture reference.
class MainMenuScreen extends StatefulWidget {
  final VoidCallback onPlayPressed;
  final VoidCallback onHowToPlay;
  final VoidCallback onStory;
  final GestureCursorController? controller;

  const MainMenuScreen({
    super.key,
    required this.onPlayPressed,
    required this.onHowToPlay,
    required this.onStory,
    this.controller,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fireCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeInCtrl;
  final List<_FireParticle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    _fireCtrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 32),
          )
          ..addListener(_tickParticles)
          ..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeInCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    for (int i = 0; i < 80; i++) {
      _particles.add(_FireParticle.random(_rng, randomizeY: true));
    }
  }

  void _tickParticles() {
    setState(() {
      for (final p in _particles) {
        p.update(0.032);
        if (p.y < -0.05 || p.alpha <= 0 || p.size <= 0.5) {
          p.reset(_rng);
        }
      }
    });
  }

  /// Wraps [child] in a [GestureTapTarget] if a cursor controller is present.
  Widget _gestureWrap({required Widget child, required VoidCallback onTap}) {
    final ctrl = widget.controller;
    if (ctrl == null) return child;
    return GestureTapTarget(controller: ctrl, onTap: onTap, child: child);
  }

  @override
  void dispose() {
    _fireCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeInCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    final body = Stack(
      children: [
        // Deep atmospheric background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF040808), Color(0xFF0A0F0F), Color(0xFF180808)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),

        // Fire particles layer
        CustomPaint(
          painter: _FireParticlePainter(_particles),
          child: const SizedBox.expand(),
        ),

        // Bottom fire gradient
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 200,
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0x88CC3300), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        // Content
        FadeTransition(
          opacity: _fadeInCtrl,
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Big Brother surveillance tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF44FF44).withValues(alpha: 0.45),
                        width: 1,
                      ),
                      color: const Color(0xFF001100),
                    ),
                    child: const Text(
                      '👁  BIG BROTHER IS WATCHING  👁',
                      style: TextStyle(
                        color: Color(0xFF44FF44),
                        fontFamily: 'monospace',
                        fontSize: 11,
                        letterSpacing: 3.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ═══ MAIN TITLE ═══
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, _) {
                      final glow = 0.65 + 0.35 * _pulseCtrl.value;
                      return Column(
                        children: [
                          Text(
                            'PYRO',
                            style: TextStyle(
                              color: Palette.fireWhite,
                              fontFamily: 'monospace',
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 16.0,
                              height: 0.9,
                              shadows: [
                                Shadow(
                                  blurRadius: 30 * glow,
                                  color: Palette.fireDeep.withValues(
                                    alpha: 0.9 * glow,
                                  ),
                                ),
                                Shadow(
                                  blurRadius: 60 * glow,
                                  color: Palette.fireMid.withValues(
                                    alpha: 0.5 * glow,
                                  ),
                                ),
                                Shadow(
                                  blurRadius: 100 * glow,
                                  color: Palette.fireGold.withValues(
                                    alpha: 0.3 * glow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'MANCER',
                            style: TextStyle(
                              color: Palette.fireGold,
                              fontFamily: 'monospace',
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 16.0,
                              height: 0.9,
                              shadows: [
                                Shadow(
                                  blurRadius: 30 * glow,
                                  color: Palette.fireDeep.withValues(
                                    alpha: 0.9 * glow,
                                  ),
                                ),
                                Shadow(
                                  blurRadius: 80 * glow,
                                  color: Palette.fireGold.withValues(
                                    alpha: 0.6 * glow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  // Divider line
                  SizedBox(
                    width: 320,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 1,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Palette.fireGold,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          color: const Color(0xFF0A0F0F),
                          child: const Text(
                            '✦',
                            style: TextStyle(
                              color: Palette.fireGold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    '"SNAP YOUR FINGERS. RESIST THEM ALL."',
                    style: TextStyle(
                      color: Palette.uiGrey,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      letterSpacing: 2.0,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Buttons
                  _gestureWrap(
                    onTap: widget.onPlayPressed,
                    child: _MenuButton(
                      label: '▶   ENTER THE DUNGEON',
                      color: Palette.fireGold,
                      onTap: widget.onPlayPressed,
                      pulse: _pulseCtrl,
                      isPrimary: true,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _gestureWrap(
                        onTap: widget.onStory,
                        child: _MenuButton(
                          label: '📜  STORY',
                          color: const Color(0xFF44FF44),
                          onTap: widget.onStory,
                          pulse: null,
                          isPrimary: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _gestureWrap(
                        onTap: widget.onHowToPlay,
                        child: _MenuButton(
                          label: '?   HOW TO PLAY',
                          color: Palette.fireMid,
                          onTap: widget.onHowToPlay,
                          pulse: null,
                          isPrimary: false,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Gesture quick-reference
                  _GestureReference(),

                  const SizedBox(height: 12),

                  const Text(
                    'WEBCAM ACTIVE — BIG BROTHER IS WATCHING  •  OR USE MOUSE',
                    style: TextStyle(
                      color: Color(0xFF335533),
                      fontFamily: 'monospace',
                      fontSize: 9,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),
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

// ══════════════════════════════════════════
// Menu Button
// ══════════════════════════════════════════
class _MenuButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final AnimationController? pulse;
  final bool isPrimary;

  const _MenuButton({
    required this.label,
    required this.color,
    required this.onTap,
    required this.pulse,
    required this.isPrimary,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Widget inner = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isPrimary ? 48 : 40,
            vertical: widget.isPrimary ? 18 : 14,
          ),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.18)
                : widget.color.withValues(
                    alpha: widget.isPrimary ? 0.08 : 0.04,
                  ),
            border: Border.all(
              color: widget.color.withValues(alpha: _hovered ? 0.9 : 0.5),
              width: widget.isPrimary ? 2.0 : 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? Palette.fireWhite : widget.color,
              fontFamily: 'monospace',
              fontSize: widget.isPrimary ? 20 : 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.0,
              shadows: _hovered
                  ? [
                      Shadow(
                        blurRadius: 12,
                        color: widget.color.withValues(alpha: 0.8),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );

    if (widget.pulse != null) {
      return AnimatedBuilder(
        animation: widget.pulse!,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(
                  alpha: 0.12 * widget.pulse!.value,
                ),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: inner,
        ),
      );
    }
    return inner;
  }
}

// ══════════════════════════════════════════
// Gesture Quick Reference Bar
// ══════════════════════════════════════════
class _GestureReference extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const gestures = [
      ('☝', 'FIRE BOLT', Color(0xFFFF6622)),
      ('✊', 'FORCE PUSH', Color(0xFF8844FF)),
      ('🖐', 'WARD SHIELD', Color(0xFF44DDFF)),
      ('✌', 'OVERWATCH', Color(0xFFFFFF44)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xBB050A0A),
        border: Border.all(
          color: Palette.fireMid.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < gestures.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 36,
                color: Palette.fireMid.withValues(alpha: 0.2),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
            _GestureChip(
              icon: gestures[i].$1,
              label: gestures[i].$2,
              color: gestures[i].$3,
            ),
          ],
        ],
      ),
    );
  }
}

class _GestureChip extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _GestureChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: 'monospace',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════
// Fire Particle System
// ══════════════════════════════════════════
class _FireParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  double phase;
  final Color color;

  _FireParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.phase,
    required this.color,
  });

  static const List<Color> _colors = [
    Palette.fireDeep,
    Palette.fireMid,
    Palette.fireGold,
    Palette.fireBright,
  ];

  factory _FireParticle.random(Random rng, {bool randomizeY = false}) {
    return _FireParticle(
      x: rng.nextDouble(),
      y: randomizeY ? rng.nextDouble() : 1.0 + rng.nextDouble() * 0.2,
      vx: (rng.nextDouble() - 0.5) * 0.006,
      vy: -(0.003 + rng.nextDouble() * 0.015),
      size: 1.5 + rng.nextDouble() * 5.0,
      alpha: 0.2 + rng.nextDouble() * 0.8,
      phase: rng.nextDouble() * pi * 2,
      color: _colors[rng.nextInt(_colors.length)],
    );
  }

  void reset(Random rng) {
    x = rng.nextDouble();
    y = 1.0 + rng.nextDouble() * 0.1;
    vx = (rng.nextDouble() - 0.5) * 0.006;
    vy = -(0.003 + rng.nextDouble() * 0.015);
    size = 1.5 + rng.nextDouble() * 5.0;
    alpha = 0.2 + rng.nextDouble() * 0.8;
  }

  void update(double dt) {
    x += vx + sin(phase + y * 8) * 0.0015;
    y += vy;
    alpha -= dt * 0.35;
    size -= dt * 1.8;
    phase += dt * 4.0;
  }
}

class _FireParticlePainter extends CustomPainter {
  final List<_FireParticle> particles;
  _FireParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.alpha <= 0 || p.size <= 0) continue;
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.alpha.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size.clamp(0.5, 20.0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FireParticlePainter old) => true;
}
