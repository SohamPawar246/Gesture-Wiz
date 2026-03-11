import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/palette.dart';
import '../models/gesture_cursor_controller.dart';

// ══════════════════════════════════════════════════════════════════════════
// GestureCursorLayer
// A full-screen stack overlay that renders the animated fire cursor on top
// of whatever screen is passed as [child].  Place this as the outermost
// widget for any screen that should support gesture navigation.
// ══════════════════════════════════════════════════════════════════════════
class GestureCursorLayer extends StatelessWidget {
  final Widget child;
  final GestureCursorController controller;

  const GestureCursorLayer({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        _GestureCursorWidget(controller: controller),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// _GestureCursorWidget
// The visible cursor: a pulsing fire orb with a dwell-progress ring.
// ══════════════════════════════════════════════════════════════════════════
class _GestureCursorWidget extends StatefulWidget {
  final GestureCursorController controller;
  const _GestureCursorWidget({required this.controller});

  @override
  State<_GestureCursorWidget> createState() => _GestureCursorWidgetState();
}

class _GestureCursorWidgetState extends State<_GestureCursorWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.isVisible) return const SizedBox.shrink();

    final screen = MediaQuery.of(context).size;
    final cx = widget.controller.posX * screen.width;
    final cy = widget.controller.posY * screen.height;

    // Keep cursor within screen bounds
    const r = 30.0;
    final left = (cx - r).clamp(0.0, screen.width - r * 2);
    final top = (cy - r).clamp(0.0, screen.height - r * 2);

    return Positioned(
      left: left,
      top: top,
      width: r * 2,
      height: r * 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, child) => CustomPaint(
            painter: _CursorPainter(
              dwell: widget.controller.dwellProgress,
              pinching: widget.controller.isPinching,
              pulse: _pulseCtrl.value,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom painter for the cursor ────────────────────────────────────────
class _CursorPainter extends CustomPainter {
  final double dwell;
  final bool pinching;
  final double pulse;

  const _CursorPainter({
    required this.dwell,
    required this.pinching,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    // Outer ambient glow
    canvas.drawCircle(
      c,
      18 + 4 * pulse,
      Paint()
        ..color = const Color(0xFFFF7700).withValues(alpha: 0.12 + 0.08 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    if (dwell > 0.01) {
      // Dwell track ring (dim background)
      canvas.drawCircle(
        c,
        20,
        Paint()
          ..color = const Color(0x33FFFFFF)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );

      // Dwell fill arc — gold, clockwise from top
      canvas.drawArc(
        Rect.fromCenter(center: c, width: 40, height: 40),
        -pi / 2,
        dwell * 2 * pi,
        false,
        Paint()
          ..color = Palette.fireGold.withValues(alpha: 0.9)
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Mid glow
    canvas.drawCircle(
      c,
      pinching ? 10 : 7,
      Paint()
        ..color = (pinching ? Palette.fireWhite : Palette.fireMid).withValues(
          alpha: 0.6 + 0.3 * pulse,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Hard core
    canvas.drawCircle(
      c,
      pinching ? 5 : 3.5,
      Paint()..color = Palette.fireWhite,
    );

    // Crosshair lines (dim, subtle)
    final xp = Paint()
      ..color = Palette.fireWhite.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(c.dx - 12, c.dy), Offset(c.dx - 6, c.dy), xp);
    canvas.drawLine(Offset(c.dx + 6, c.dy), Offset(c.dx + 12, c.dy), xp);
    canvas.drawLine(Offset(c.dx, c.dy - 12), Offset(c.dx, c.dy - 6), xp);
    canvas.drawLine(Offset(c.dx, c.dy + 6), Offset(c.dx, c.dy + 12), xp);

    // Pinch flash ring
    if (pinching) {
      canvas.drawCircle(
        c,
        14,
        Paint()
          ..color = Palette.fireGold.withValues(alpha: 0.5 + 0.3 * pulse)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CursorPainter old) =>
      old.dwell != dwell || old.pinching != pinching || old.pulse != pulse;
}

// ══════════════════════════════════════════════════════════════════════════
// GestureTapTarget
// Wraps any button widget and makes it respond to the gesture cursor.
// Hover for [dwellSeconds] → auto-click. Pinch while hovering → instant click.
// ══════════════════════════════════════════════════════════════════════════
class GestureTapTarget extends StatefulWidget {
  final Widget child;
  final GestureCursorController controller;
  final VoidCallback onTap;

  /// How many seconds of continuous hover before auto-triggering.
  final double dwellSeconds;

  const GestureTapTarget({
    super.key,
    required this.child,
    required this.controller,
    required this.onTap,
    this.dwellSeconds = 1.2,
  });

  @override
  State<GestureTapTarget> createState() => _GestureTapTargetState();
}

class _GestureTapTargetState extends State<GestureTapTarget>
    with SingleTickerProviderStateMixin {
  final GlobalKey _key = GlobalKey();

  double _dwell = 0.0;
  bool _isHovered = false;
  bool _hasFired = false;
  double _cooldown = 0.0;
  Duration? _prevElapsed;
  late final Ticker _ticker;

  // Unique ID to coordinate with the controller's dwell slot
  late final int _myId;

  @override
  void initState() {
    super.initState();
    _myId = identityHashCode(this);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    widget.controller.endDwell(_myId);
    super.dispose();
  }

  void _tick(Duration elapsed) {
    if (!mounted) return;

    final dt = _prevElapsed != null
        ? (elapsed - _prevElapsed!).inMicroseconds / 1000000.0
        : 0.016;
    _prevElapsed = elapsed;

    // ── Bounds check ──────────────────────────────────────────────────
    final ctx = _key.currentContext;
    final renderBox = ctx?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final screen = MediaQuery.of(context).size;
    final cursorPx = Offset(
      widget.controller.posX * screen.width,
      widget.controller.posY * screen.height,
    );
    final origin = renderBox.localToGlobal(Offset.zero);
    final boxSize = renderBox.size;

    final inside =
        widget.controller.isVisible &&
        cursorPx.dx >= origin.dx &&
        cursorPx.dx <= origin.dx + boxSize.width &&
        cursorPx.dy >= origin.dy &&
        cursorPx.dy <= origin.dy + boxSize.height;

    // ── Cooldown ──────────────────────────────────────────────────────
    if (_cooldown > 0) {
      _cooldown -= dt;
      if (_cooldown <= 0) _hasFired = false;
    }

    // ── Dwell progress ────────────────────────────────────────────────
    double newDwell = _dwell;
    final globalReady = widget.controller.globalCooldown <= 0;
    if (inside && _cooldown <= 0 && globalReady) {
      newDwell = (_dwell + dt / widget.dwellSeconds).clamp(0.0, 1.0);
    } else if (!inside) {
      newDwell = 0.0; // instant reset when cursor leaves
    } else {
      newDwell = (_dwell - dt * 2.5).clamp(0.0, 1.0); // decay during cooldown
    }

    // Coordinate dwell display with controller
    if (inside) {
      if (!_isHovered) widget.controller.startDwell(_myId);
      widget.controller.updateDwell(_myId, newDwell);
    } else {
      if (_isHovered) {
        // Cursor just left — immediately clear dwell and re-arm for next hover
        newDwell = 0.0;
        _hasFired = false;
        widget.controller.endDwell(_myId);
      }
    }

    // ── Fire on dwell complete ────────────────────────────────────────
    if (inside && newDwell >= 1.0 && !_hasFired && _cooldown <= 0) {
      _fire(newDwell = 0.0);
    }

    // ── Fire on pinch ─────────────────────────────────────────────────
    if (inside &&
        widget.controller.pinchJustFired &&
        !_hasFired &&
        _cooldown <= 0 &&
        globalReady) {
      _fire(newDwell = 0.0);
    }

    // ── State update ──────────────────────────────────────────────────
    if (newDwell != _dwell || inside != _isHovered) {
      setState(() {
        _dwell = newDwell;
        _isHovered = inside;
      });
    } else {
      _dwell = newDwell;
      _isHovered = inside;
    }
  }

  void _fire(double afterDwell) {
    _hasFired = true;
    _cooldown = 0.9;
    widget.controller.triggerGlobalCooldown(0.8);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _key,
      decoration: _isHovered
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Palette.fireGold.withValues(
                    alpha: 0.18 + 0.25 * _dwell,
                  ),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      child: Stack(
        children: [
          widget.child,
          // Hover glow overlay
          if (_isHovered)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Palette.fireGold.withValues(
                        alpha: 0.35 + 0.45 * _dwell,
                      ),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
