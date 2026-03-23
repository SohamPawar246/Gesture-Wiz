import 'dart:math';
import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../models/gesture_cursor_controller.dart';
import 'gesture_cursor_overlay.dart';
import 'glitch_text.dart';

/// Animated main menu — cyberpunk surveillance terminal aesthetic.
/// Neon cyan/magenta on deep void black with floating data particles.
class MainMenuScreen extends StatefulWidget {
  final VoidCallback onPlayPressed;
  final VoidCallback onHowToPlay;
  final VoidCallback onStory;
  final VoidCallback? onSettings;
  final GestureCursorController? controller;

  const MainMenuScreen({
    super.key,
    required this.onPlayPressed,
    required this.onHowToPlay,
    required this.onStory,
    this.onSettings,
    this.controller,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with TickerProviderStateMixin {
  late final AnimationController _particleCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeInCtrl;
  late final AnimationController _scanCtrl;
  final List<_DataParticle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 32),
    )
      ..addListener(_tickParticles)
      ..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _fadeInCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    for (int i = 0; i < 90; i++) {
      _particles.add(_DataParticle.random(_rng, randomizeY: true));
    }
  }

  void _tickParticles() {
    setState(() {
      for (final p in _particles) {
        p.update(0.032);
        if (p.y < -0.05 || p.alpha <= 0 || p.size <= 0.3) {
          p.reset(_rng);
        }
      }
    });
  }

  Widget _gestureWrap({required Widget child, required VoidCallback onTap}) {
    final ctrl = widget.controller;
    if (ctrl == null) return child;
    return GestureTapTarget(controller: ctrl, onTap: onTap, child: child);
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeInCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;

    final body = Stack(
      children: [
        // ── Deep void background ────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF030308),
                Color(0xFF080812),
                Color(0xFF020208),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // ── Data particle layer ─────────────────────────────────
        CustomPaint(
          painter: _DataParticlePainter(_particles),
          child: const SizedBox.expand(),
        ),

        // ── Animated scan line sweeping across ─────────────────
        AnimatedBuilder(
          animation: _scanCtrl,
          builder: (context, child) {
            return IgnorePointer(
              child: CustomPaint(
                painter: _ScanLinePainter(_scanCtrl.value),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),

        // ── Bottom cyan glow ────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 180,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Palette.neonCyan.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Top edge glow ───────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 2,
          child: IgnorePointer(
            child: Container(color: Palette.neonCyan.withValues(alpha: 0.4)),
          ),
        ),

        // ── Content ─────────────────────────────────────────────
        FadeTransition(
          opacity: _fadeInCtrl,
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Surveillance tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Palette.neonCyan.withValues(alpha: 0.45),
                        width: 1,
                      ),
                      color: Palette.neonCyan.withValues(alpha: 0.04),
                    ),
                    child: GlitchText(
                      text: 'BIG BROTHER IS WATCHING',
                      style: TextStyle(
                        color: Palette.neonCyan,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        letterSpacing: 3.5,
                      ),
                      glitchFrequency: 1.0,
                      glitchIntensity: 0.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── MAIN TITLE ────────────────────────────────
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) {
                      final glow = 0.65 + 0.35 * _pulseCtrl.value;
                      return Column(
                        children: [
                          Text(
                            'THE EYE',
                            style: TextStyle(
                              color: Palette.cyanBright,
                              fontFamily: 'monospace',
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 12.0,
                              height: 0.9,
                              shadows: [
                                Shadow(
                                  blurRadius: 24 * glow,
                                  color: Palette.neonCyan.withValues(
                                    alpha: 0.85 * glow,
                                  ),
                                ),
                                Shadow(
                                  blurRadius: 60 * glow,
                                  color: Palette.cyanDeep.withValues(
                                    alpha: 0.5 * glow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'PROTOCOL',
                            style: TextStyle(
                              color: Palette.neonMagenta,
                              fontFamily: 'monospace',
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 12.0,
                              height: 0.9,
                              shadows: [
                                Shadow(
                                  blurRadius: 28 * glow,
                                  color: Palette.neonMagenta.withValues(
                                    alpha: 0.8 * glow,
                                  ),
                                ),
                                Shadow(
                                  blurRadius: 72 * glow,
                                  color: Palette.pinkDim.withValues(
                                    alpha: 0.45 * glow,
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

                  // Divider with eye icon
                  SizedBox(
                    width: 320,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Palette.neonCyan,
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          color: const Color(0xFF030308),
                          child: Icon(
                            Icons.remove_red_eye,
                            color: Palette.neonCyan,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '"SNAP YOUR FINGERS. RESIST THEM ALL."',
                    style: TextStyle(
                      color: Palette.cyanDim.withValues(alpha: 0.6),
                      fontFamily: 'monospace',
                      fontSize: 11,
                      letterSpacing: 2.0,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Primary button
                  _gestureWrap(
                    onTap: widget.onPlayPressed,
                    child: _MenuButton(
                      label: 'ENTER THE GRID',
                      icon: Icons.play_arrow,
                      color: Palette.neonCyan,
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
                          label: 'STORY',
                          icon: Icons.menu_book,
                          color: Palette.neonCyan,
                          onTap: widget.onStory,
                          pulse: null,
                          isPrimary: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _gestureWrap(
                        onTap: widget.onHowToPlay,
                        child: _MenuButton(
                          label: 'HOW TO PLAY',
                          icon: Icons.help_outline,
                          color: Palette.cyanDim,
                          onTap: widget.onHowToPlay,
                          pulse: null,
                          isPrimary: false,
                        ),
                      ),
                      if (widget.onSettings != null) ...[
                        const SizedBox(width: 12),
                        _gestureWrap(
                          onTap: widget.onSettings!,
                          child: _MenuButton(
                            label: 'SETTINGS',
                            icon: Icons.settings,
                            color: Palette.cyanDim,
                            onTap: widget.onSettings!,
                            pulse: null,
                            isPrimary: false,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  _GestureReference(),

                  const SizedBox(height: 12),

                  Text(
                    'WEBCAM ACTIVE — BIG BROTHER IS WATCHING  •  OR USE MOUSE',
                    style: TextStyle(
                      color: Palette.cyanDeep.withValues(alpha: 0.6),
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
      backgroundColor: Palette.bgVoid,
      body: ctrl != null
          ? AnimatedBuilder(
              animation: ctrl,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  (ctrl.faceX - 0.5) * ctrl.parallaxH,
                  (ctrl.faceY - 0.5) * ctrl.parallaxV,
                ),
                child: child,
              ),
              child: body,
            )
          : body,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Menu Button
// ══════════════════════════════════════════════════════════════════
class _MenuButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;
  final AnimationController? pulse;
  final bool isPrimary;

  const _MenuButton({
    required this.label,
    this.icon,
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
                ? widget.color.withValues(alpha: 0.15)
                : widget.color.withValues(
                    alpha: widget.isPrimary ? 0.07 : 0.04,
                  ),
            border: Border.all(
              color: widget.color.withValues(alpha: _hovered ? 0.9 : 0.45),
              width: widget.isPrimary ? 2.0 : 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.35),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: _hovered ? Palette.dataWhite : widget.color,
                  size: widget.isPrimary ? 22 : 18,
                ),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovered ? Palette.dataWhite : widget.color,
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
            ],
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
                  alpha: 0.10 * widget.pulse!.value,
                ),
                blurRadius: 36,
                spreadRadius: 6,
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

// ══════════════════════════════════════════════════════════════════
// Gesture Quick Reference Bar
// ══════════════════════════════════════════════════════════════════
class _GestureReference extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const gestures = [
      (Icons.bolt, 'DATA SPIKE', Palette.neonCyan),
      (Icons.shield, 'FIREWALL', Palette.dataBlue),
      (Icons.link, 'HACK GRIP', Palette.neonPink),
      (Icons.radio_button_checked, 'ZERO DAY', Palette.alertAmber),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Palette.bgPanel.withValues(alpha: 0.85),
        border: Border.all(
          color: Palette.neonCyan.withValues(alpha: 0.22),
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
                color: Palette.neonCyan.withValues(alpha: 0.18),
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
  final IconData icon;
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
        Icon(icon, color: color, size: 22),
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

// ══════════════════════════════════════════════════════════════════
// Scan Line Sweep Painter
// ══════════════════════════════════════════════════════════════════
class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = progress * (size.height + 60) - 30;
    final rect = Rect.fromLTWH(0, y - 15, size.width, 30);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Palette.neonCyan.withValues(alpha: 0.04),
            Palette.neonCyan.withValues(alpha: 0.06),
            Palette.neonCyan.withValues(alpha: 0.04),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════════
// Digital Data Particle System
// ══════════════════════════════════════════════════════════════════
class _DataParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  double phase;
  final Color color;
  final bool isRect; // rectangular pixel vs circle

  _DataParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.phase,
    required this.color,
    required this.isRect,
  });

  static const List<Color> _colors = [
    Palette.neonCyan,
    Palette.cyanDim,
    Palette.neonMagenta,
    Palette.neonPink,
    Palette.dataPurple,
    Palette.dataBlue,
  ];

  factory _DataParticle.random(Random rng, {bool randomizeY = false}) {
    return _DataParticle(
      x: rng.nextDouble(),
      y: randomizeY ? rng.nextDouble() : 1.05,
      vx: (rng.nextDouble() - 0.5) * 0.004,
      vy: -(0.002 + rng.nextDouble() * 0.012),
      size: 1.0 + rng.nextDouble() * 4.0,
      alpha: 0.15 + rng.nextDouble() * 0.55,
      phase: rng.nextDouble() * pi * 2,
      color: _colors[rng.nextInt(_colors.length)],
      isRect: rng.nextBool(),
    );
  }

  void reset(Random rng) {
    x = rng.nextDouble();
    y = 1.05;
    vx = (rng.nextDouble() - 0.5) * 0.004;
    vy = -(0.002 + rng.nextDouble() * 0.012);
    size = 1.0 + rng.nextDouble() * 4.0;
    alpha = 0.15 + rng.nextDouble() * 0.55;
  }

  void update(double dt) {
    x += vx + sin(phase + y * 6) * 0.001;
    y += vy;
    alpha -= dt * 0.25;
    size -= dt * 0.8;
    phase += dt * 2.5;
  }
}

class _DataParticlePainter extends CustomPainter {
  final List<_DataParticle> particles;
  _DataParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.alpha <= 0 || p.size <= 0) continue;
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.alpha.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      final cx = p.x * size.width;
      final cy = p.y * size.height;

      if (p.isRect) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: p.size.clamp(0.3, 8.0),
            height: p.size.clamp(0.3, 8.0) * 0.5,
          ),
          paint,
        );
      } else {
        canvas.drawCircle(
          Offset(cx, cy),
          p.size.clamp(0.3, 6.0),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DataParticlePainter old) => true;
}
