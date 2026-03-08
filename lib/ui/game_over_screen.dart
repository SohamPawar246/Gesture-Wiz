import 'dart:math';
import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../models/gesture_cursor_controller.dart';
import 'gesture_cursor_overlay.dart';

class GameOverScreen extends StatefulWidget {
  final bool isVictory;
  final int score;
  final int kills;
  final int wave;
  final VoidCallback onRestart;
  final VoidCallback onMainMenu;
  final GestureCursorController? controller;

  const GameOverScreen({
    super.key,
    required this.isVictory,
    required this.score,
    required this.kills,
    required this.wave,
    required this.onRestart,
    required this.onMainMenu,
    this.controller,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _particleCtrl;
  final List<_EndParticle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _particleCtrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 50),
          )
          ..addListener(_tickParticles)
          ..repeat();

    for (int i = 0; i < 40; i++) {
      _particles.add(_EndParticle.random(_rng, widget.isVictory));
    }
  }

  void _tickParticles() {
    setState(() {
      for (final p in _particles) {
        p.update(0.05);
        if (p.alpha <= 0 || p.size <= 0.3) {
          p.reset(_rng, widget.isVictory);
        }
      }
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isVictory ? Palette.fireGold : Palette.impactRed;
    final title = widget.isVictory ? 'VICTORY' : 'GAME OVER';
    final subtitle = widget.isVictory
        ? 'THE DUNGEON HAS FALLEN'
        : 'THE DARKNESS CONSUMED YOU';
    final ctrl = widget.controller;

    final body = Stack(
      children: [
        // Backdrop
        Container(color: const Color(0xEE030808)),

        // Particles
        CustomPaint(
          painter: _EndParticlePainter(_particles),
          child: const SizedBox.expand(),
        ),

        // Content
        Center(
          child: AnimatedBuilder(
            animation: _entranceCtrl,
            builder: (context, child) {
              final t = CurvedAnimation(
                parent: _entranceCtrl,
                curve: Curves.easeOutBack,
              ).value;
              return Transform.scale(
                scale: 0.7 + 0.3 * t,
                child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decorative top line
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, _) {
                    return Container(
                      width: 380,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            accentColor.withValues(
                              alpha: 0.5 + 0.5 * _pulseCtrl.value,
                            ),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.6),
                            blurRadius: 8 + 8 * _pulseCtrl.value,
                          ),
                        ],
                      ),
                    );
                  },
                ),

                Container(
                  width: 380,
                  padding: const EdgeInsets.fromLTRB(36, 32, 36, 36),
                  decoration: BoxDecoration(
                    color: const Color(0xF0060C0C),
                    border: Border(
                      left: BorderSide(
                        color: accentColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      right: BorderSide(
                        color: accentColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      bottom: BorderSide(
                        color: accentColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (context, _) {
                          final glow = 0.6 + 0.4 * _pulseCtrl.value;
                          return Text(
                            title,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              letterSpacing: 8.0,
                              shadows: [
                                Shadow(
                                  blurRadius: 20 * glow,
                                  color: accentColor.withValues(alpha: glow),
                                ),
                                Shadow(
                                  blurRadius: 50 * glow,
                                  color: accentColor.withValues(
                                    alpha: 0.4 * glow,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 6),

                      Text(
                        subtitle,
                        style: TextStyle(
                          color: accentColor.withValues(alpha: 0.6),
                          fontFamily: 'monospace',
                          fontSize: 11,
                          letterSpacing: 3.0,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Stats divider
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              accentColor.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      _statRow('SCORE', '${widget.score}', Palette.fireGold),
                      const SizedBox(height: 10),
                      _statRow('KILLS', '${widget.kills}', Palette.impactRed),
                      const SizedBox(height: 10),
                      _statRow(
                        'CHAMBER',
                        '${widget.wave} / 10',
                        Palette.fireMid,
                      ),

                      const SizedBox(height: 20),

                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              accentColor.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Buttons
                      _gestureWrap(
                        onTap: widget.onRestart,
                        child: _ActionButton(
                          label: '▶  PLAY AGAIN',
                          color: Palette.fireGold,
                          onTap: widget.onRestart,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _gestureWrap(
                        onTap: widget.onMainMenu,
                        child: _ActionButton(
                          label: '⌂  MAIN MENU',
                          color: Palette.uiGrey,
                          onTap: widget.onMainMenu,
                        ),
                      ),
                    ],
                  ),
                ),

                // Decorative bottom line
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (context, _) {
                    return Container(
                      width: 380,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            accentColor.withValues(
                              alpha: 0.5 + 0.5 * _pulseCtrl.value,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return ctrl != null
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
        : body;
  }

  Widget _gestureWrap({required Widget child, required VoidCallback onTap}) {
    final ctrl = widget.controller;
    if (ctrl == null) return child;
    return GestureTapTarget(controller: ctrl, onTap: onTap, child: child);
  }

  Widget _statRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Palette.uiGrey,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 3,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 2,
            shadows: [
              Shadow(blurRadius: 8, color: valueColor.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.15)
                : widget.color.withValues(alpha: 0.06),
            border: Border.all(
              color: widget.color.withValues(alpha: _hovered ? 0.8 : 0.4),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: _hovered ? Palette.fireWhite : widget.color,
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 4.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// End-screen particles
class _EndParticle {
  double x, y, vx, vy, size, alpha, phase;
  final Color color;

  _EndParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.phase,
    required this.color,
  });

  factory _EndParticle.random(Random rng, bool victory) {
    final colors = victory
        ? [Palette.fireGold, Palette.fireBright, Palette.fireMid]
        : [Palette.impactRed, Palette.impactPink, Palette.fireDeep];
    return _EndParticle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      vx: (rng.nextDouble() - 0.5) * 0.004,
      vy: -(0.002 + rng.nextDouble() * 0.008),
      size: 1.0 + rng.nextDouble() * 4.0,
      alpha: 0.1 + rng.nextDouble() * 0.5,
      phase: rng.nextDouble() * pi * 2,
      color: colors[rng.nextInt(colors.length)],
    );
  }

  void reset(Random rng, bool victory) {
    x = rng.nextDouble();
    y = 1.05;
    vx = (rng.nextDouble() - 0.5) * 0.004;
    vy = -(0.002 + rng.nextDouble() * 0.008);
    size = 1.0 + rng.nextDouble() * 4.0;
    alpha = 0.1 + rng.nextDouble() * 0.5;
  }

  void update(double dt) {
    x += vx + sin(phase) * 0.001;
    y += vy;
    alpha -= dt * 0.25;
    size -= dt * 1.2;
    phase += dt * 3.0;
  }
}

class _EndParticlePainter extends CustomPainter {
  final List<_EndParticle> particles;
  _EndParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.alpha <= 0 || p.size <= 0) continue;
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size.clamp(0.3, 10.0),
        Paint()
          ..color = p.color.withValues(alpha: p.alpha.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EndParticlePainter old) => true;
}
