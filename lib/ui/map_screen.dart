import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models/gesture_cursor_controller.dart';
import '../models/map_node.dart';
import '../models/player_stats.dart';
import 'gesture_cursor_overlay.dart';
import 'glitch_text.dart';
import '../game/palette.dart';

class MapScreen extends StatefulWidget {
  final PlayerStats playerStats;
  final GestureCursorController cursorController;
  final void Function(MapNode node) onNodeSelected;
  final VoidCallback onBackToMenu;
  final VoidCallback onOpenUpgrades;

  const MapScreen({
    super.key,
    required this.playerStats,
    required this.cursorController,
    required this.onNodeSelected,
    required this.onBackToMenu,
    required this.onOpenUpgrades,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration? _prevElapsed;

  // The center logical position the camera is looking at
  Offset _cameraOffset = const Offset(1000, 1000);
  final double _zoom = 0.8; // Base zoom

  final double _mapWidth = 2000;
  final double _mapHeight = 2000;

  // ── Scrolling momentum ──────────────────────────────────────────
  Offset _velocity = Offset.zero;
  static const double _friction = 3.5; // velocity decay per second
  static const double _edgePanGraceSeconds = 0.45;
  Offset _stickyEdgePan = Offset.zero;
  double _edgePanGraceRemaining = 0.0;

  // ── Touch drag support ──────────────────────────────────────────
  Offset? _dragStartCamera;
  Offset? _dragStartPoint;
  bool _isDragging = false;

  // ── Cheat code ──────────────────────────────────────────────────
  static const List<String> _cheatSequence = [
    'g',
    'o',
    'd',
    'm',
    'o',
    'd',
    'e',
  ];
  final List<String> _cheatBuffer = [];
  bool _cheatActivated = false;

  // ── VFX state ───────────────────────────────────────────────────
  double _time = 0;
  final Random _rng = Random();
  late final List<_MapParticle> _particles;
  late final List<_DataStream> _dataStreams;

  @override
  void initState() {
    super.initState();
    // Center camera on current node initially
    final currentNode = MapGraph.nodes[widget.playerStats.currentNodeId];
    if (currentNode != null) {
      _cameraOffset = Offset(currentNode.x, currentNode.y);
    }

    // Init VFX particles
    _particles = List.generate(50, (_) => _MapParticle.random(_rng));
    _dataStreams = List.generate(12, (_) => _DataStream.random(_rng));

    _ticker = createTicker(_tick)..start();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final label = event.logicalKey.keyLabel.toLowerCase();
      if (label.length == 1) {
        _cheatBuffer.add(label);
        if (_cheatBuffer.length > _cheatSequence.length) {
          _cheatBuffer.removeAt(0);
        }
        if (!_cheatActivated &&
            _cheatBuffer.length == _cheatSequence.length &&
            _cheatBuffer.join() == _cheatSequence.join()) {
          _cheatActivated = true;
          widget.playerStats.unlockAllNodes();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.black,
                shape: Border.all(color: Colors.greenAccent, width: 1),
                content: const Text(
                  '[ CHEAT ] ALL NODES UNLOCKED',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
                ),
              ),
            );
          }
        }
      }
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    if (!mounted) return;
    final dt = _prevElapsed != null
        ? (elapsed - _prevElapsed!).inMicroseconds / 1000000.0
        : 0.016;
    _prevElapsed = elapsed;

    _time += dt;

    // Update VFX particles
    for (final p in _particles) {
      p.update(dt);
      if (p.alpha <= 0 || p.size <= 0.3) {
        p.reset(_rng);
      }
    }
    for (final ds in _dataStreams) {
      ds.update(dt);
      if (ds.progress > 1.0) ds.reset(_rng);
    }

    // ── Gesture cursor edge-panning ───────────────────────────────
    Offset edgePan = Offset.zero;
    if (!_isDragging) {
      if (widget.cursorController.isVisible) {
        edgePan = _computeEdgePan(
          widget.cursorController.posX,
          widget.cursorController.posY,
        );

        if (edgePan.distance > 0.01) {
          _stickyEdgePan = edgePan;
          _edgePanGraceRemaining = _edgePanGraceSeconds;
        } else {
          _stickyEdgePan = Offset.zero;
          _edgePanGraceRemaining = 0.0;
        }
      } else if (_edgePanGraceRemaining > 0.0) {
        _edgePanGraceRemaining = max(0.0, _edgePanGraceRemaining - dt);
        final factor = _edgePanGraceSeconds == 0
            ? 0.0
            : _edgePanGraceRemaining / _edgePanGraceSeconds;
        edgePan = _stickyEdgePan * factor;

        if (_edgePanGraceRemaining == 0.0) {
          _stickyEdgePan = Offset.zero;
        }
      }
    }

    // ── Apply momentum + edge pan ─────────────────────────────────
    if (!_isDragging) {
      // Combine velocity with edge-pan
      final totalMove = (_velocity + edgePan) * dt;

      if (totalMove.distance > 0.01) {
        // Decay velocity via friction
        final speed = _velocity.distance;
        if (speed > 1.0) {
          final decayed = speed * exp(-_friction * dt);
          _velocity = _velocity * (decayed / speed);
        } else {
          _velocity = Offset.zero;
        }

        setState(() {
          _cameraOffset += totalMove;
          _cameraOffset = Offset(
            _cameraOffset.dx.clamp(0.0, _mapWidth),
            _cameraOffset.dy.clamp(0.0, _mapHeight),
          );
        });
      } else {
        // Still need to rebuild for VFX even when stationary
        setState(() {});
      }
    } else {
      setState(() {}); // rebuild for VFX
    }
  }

  // ── Touch drag handlers ─────────────────────────────────────────
  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
    _dragStartCamera = _cameraOffset;
    _dragStartPoint = details.localPosition;
    _velocity = Offset.zero;
  }

  Offset _computeEdgePan(double cx, double cy) {
    double panX = 0;
    double panY = 0;
    const edgeMargin = 0.12;
    const maxPanSpeed = 700.0;

    if (cx < edgeMargin) {
      final t = 1 - cx / edgeMargin;
      panX = -maxPanSpeed * t * t;
    } else if (cx > 1 - edgeMargin) {
      final t = 1 - (1 - cx) / edgeMargin;
      panX = maxPanSpeed * t * t;
    }

    if (cy < edgeMargin) {
      final t = 1 - cy / edgeMargin;
      panY = -maxPanSpeed * t * t;
    } else if (cy > 1 - edgeMargin) {
      final t = 1 - (1 - cy) / edgeMargin;
      panY = maxPanSpeed * t * t;
    }

    return Offset(panX, panY);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStartCamera == null || _dragStartPoint == null) return;
    final delta = details.localPosition - _dragStartPoint!;
    setState(() {
      _cameraOffset = Offset(
        (_dragStartCamera!.dx - delta.dx / _zoom).clamp(0.0, _mapWidth),
        (_dragStartCamera!.dy - delta.dy / _zoom).clamp(0.0, _mapHeight),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _isDragging = false;
    _dragStartCamera = null;
    _dragStartPoint = null;
    // Transfer fling velocity to momentum (inverted — drag opposite to camera)
    final pxVel = details.velocity.pixelsPerSecond;
    _velocity = Offset(-pxVel.dx / _zoom, -pxVel.dy / _zoom);
    // Clamp to reasonable max
    final maxV = 2000.0;
    if (_velocity.distance > maxV) {
      _velocity = _velocity * (maxV / _velocity.distance);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerScreen = Offset(screenSize.width / 2, screenSize.height / 2);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Stack(
          children: [
            // 1. Grid & Lines Background Painter
            Positioned.fill(
              child: CustomPaint(
                painter: _MapBackgroundPainter(
                  cameraOffset: _cameraOffset,
                  zoom: _zoom,
                  centerScreen: centerScreen,
                  playerStats: widget.playerStats,
                  time: _time,
                  particles: _particles,
                  dataStreams: _dataStreams,
                ),
              ),
            ),

            // 2. Nodes as gesture-tappable widgets
            ...MapGraph.nodes.values.map((node) {
              // Render node
              final screenPos =
                  centerScreen +
                  (Offset(node.x, node.y) - _cameraOffset) * _zoom;

              final isUnlocked = widget.playerStats.unlockedNodes.contains(
                node.id,
              );
              final isCompleted = widget.playerStats.completedNodes.contains(
                node.id,
              );
              final isCurrent = widget.playerStats.currentNodeId == node.id;

              Color nodeColor;
              if (isCurrent && !isCompleted) {
                nodeColor = Colors.greenAccent;
              } else if (isCompleted) {
                nodeColor = Colors.cyanAccent;
              } else if (isUnlocked) {
                nodeColor = Colors.pinkAccent;
              } else {
                nodeColor = Colors.red.withValues(alpha: 0.3);
              }

              final isPlayable = isUnlocked && !isCompleted;

              return Positioned(
                left: screenPos.dx - 50,
                top: screenPos.dy - 50,
                width: 100,
                height: 100,
                child: isPlayable
                    ? GestureTapTarget(
                        controller: widget.cursorController,
                        dwellSeconds: 1.5,
                        onTap: () {
                          widget.onNodeSelected(node);
                        },
                        child: _buildNodeContent(
                          node,
                          nodeColor,
                          isCurrent && !isCompleted,
                          completed: isCompleted,
                        ),
                      )
                    : IgnorePointer(
                        child: _buildNodeContent(
                          node,
                          nodeColor,
                          false,
                          locked: !isCompleted,
                          completed: isCompleted,
                        ),
                      ),
              );
            }),

            // 3. Scanline overlay
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ScanlineOverlayPainter(time: _time),
                ),
              ),
            ),

            // 4. UI Overlay (Titles, legend)
            Positioned(
              top: 40,
              left: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const GlitchText(
                    text: 'THE GRID (2086)',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontFamily: 'monospace',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                    glitchFrequency: 1.5,
                    glitchIntensity: 0.7,
                  ),
                  GlitchText(
                    text: 'NAVIGATE TO PROCEED',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontFamily: 'monospace',
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                    glitchFrequency: 0.8,
                    glitchIntensity: 0.3,
                  ),
                ],
              ),
            ),

            // 4b. Back to Menu button (top-right)
            Positioned(
              top: 40,
              right: 24,
              child: GestureTapTarget(
                controller: widget.cursorController,
                dwellSeconds: 1.2,
                onTap: widget.onBackToMenu,
                child: GestureDetector(
                  onTap: widget.onBackToMenu,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      border: Border.all(
                        color: Colors.cyanAccent.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      '← MENU',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 4c. Augmentations button (top-right, below menu)
            Positioned(
              top: 100,
              right: 24,
              child: GestureTapTarget(
                controller: widget.cursorController,
                dwellSeconds: 1.2,
                onTap: widget.onOpenUpgrades,
                child: GestureDetector(
                  onTap: widget.onOpenUpgrades,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.fireMid.withValues(alpha: 0.8),
                      border: Border.all(color: Palette.bgHighlight),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.fireGold.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Text(
                      'AUGMENTATIONS',
                      style: TextStyle(
                        color: Palette.fireGold,
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 5. Bottom edge glow
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.cyanAccent.withValues(alpha: 0.08),
                        Colors.transparent,
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

  Widget _buildNodeContent(
    MapNode node,
    Color color,
    bool isCurrent, {
    bool locked = false,
    bool completed = false,
  }) {
    Widget? nodeIcon;
    if (locked) {
      nodeIcon = Icon(
        Icons.lock,
        color: color.withValues(alpha: 0.4),
        size: 14,
      );
    } else if (completed) {
      nodeIcon = Icon(Icons.check, color: color, size: 16);
    } else if (isCurrent) {
      nodeIcon = Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
    }

    // Animate the pulse for playable (unlocked, not completed) nodes
    final isPlayable = !locked || completed;
    final pulseIntensity = isCurrent ? 0.5 + 0.5 * sin(_time * 3.0) : 0.0;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: locked ? Colors.transparent : Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isCurrent ? 3.0 : 2.0),
              boxShadow: locked
                  ? null
                  : [
                      BoxShadow(
                        color: color.withValues(
                          alpha: 0.6 + 0.3 * pulseIntensity,
                        ),
                        blurRadius: 10 + 6 * pulseIntensity,
                        spreadRadius: 2 + 3 * pulseIntensity,
                      ),
                      if (isPlayable && !completed)
                        BoxShadow(
                          color: color.withValues(
                            alpha: 0.15 + 0.15 * pulseIntensity,
                          ),
                          blurRadius: 30 + 15 * pulseIntensity,
                          spreadRadius: 8,
                        ),
                    ],
            ),
            child: nodeIcon,
          ),
          const SizedBox(height: 6),
          Text(
            node.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              shadows: locked
                  ? null
                  : [
                      Shadow(color: color, blurRadius: 4),
                      Shadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 12,
                      ),
                    ],
            ),
          ),
          if (!locked)
            Text(
              '${node.totalWaves} WAVES',
              style: TextStyle(
                color: color.withValues(alpha: 0.5),
                fontFamily: 'monospace',
                fontSize: 8,
                letterSpacing: 1,
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Background painter — grid, buildings, connections, particles, data streams
// ══════════════════════════════════════════════════════════════════════════
class _MapBackgroundPainter extends CustomPainter {
  final Offset cameraOffset;
  final double zoom;
  final Offset centerScreen;
  final PlayerStats playerStats;
  final double time;
  final List<_MapParticle> particles;
  final List<_DataStream> dataStreams;

  _MapBackgroundPainter({
    required this.cameraOffset,
    required this.zoom,
    required this.centerScreen,
    required this.playerStats,
    required this.time,
    required this.particles,
    required this.dataStreams,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill deep dark cyberpunk night sky
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF02040A),
    );

    // Grid painting - glowing cyan grid
    final gridPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final logicalGridSpacing = 100.0;
    final gridSpacing = logicalGridSpacing * zoom;
    final startX = (centerScreen.dx - (cameraOffset.dx * zoom)) % gridSpacing;
    final startY = (centerScreen.dy - (cameraOffset.dy * zoom)) % gridSpacing;

    for (double x = startX; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = startY; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ── Animated grid pulse lines (horizontal sweep) ──────────────
    final sweepY = (time * 40) % size.height;
    canvas.drawLine(
      Offset(0, sweepY),
      Offset(size.width, sweepY),
      Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.12)
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ── Data stream lines (animated flowing dashes) ───────────────
    for (final ds in dataStreams) {
      if (ds.progress <= 0) continue;
      final p = ds.progress.clamp(0.0, 1.0);
      final alpha = (0.4 * sin(p * pi)).clamp(0.0, 0.4);
      final screenX = ds.x * size.width;
      final headY = ds.startY + (ds.endY - ds.startY) * p;
      final tailY =
          ds.startY + (ds.endY - ds.startY) * (p - 0.15).clamp(0.0, 1.0);

      canvas.drawLine(
        Offset(screenX, tailY * size.height),
        Offset(screenX, headY * size.height),
        Paint()
          ..color = ds.color.withValues(alpha: alpha)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // Draw 3D pink buildings.
    // Keep coverage uniform, but leave a relatively small buffer so building
    // pop-in is still visible at the edges when the camera scrolls.
    const offscreenMarginWorld = 80.0;
    const drawMarginPx = 40.0;
    const spawnBandPx = 240.0;
    final viewMinX =
        cameraOffset.dx - (centerScreen.dx / zoom) - offscreenMarginWorld;
    final viewMaxX =
        cameraOffset.dx + (centerScreen.dx / zoom) + offscreenMarginWorld;
    final viewMinY =
        cameraOffset.dy - (centerScreen.dy / zoom) - offscreenMarginWorld;
    final viewMaxY =
        cameraOffset.dy + (centerScreen.dy / zoom) + offscreenMarginWorld;

    final minGridX = (viewMinX / logicalGridSpacing).floor();
    final maxGridX = (viewMaxX / logicalGridSpacing).ceil();
    final minGridY = (viewMinY / logicalGridSpacing).floor();
    final maxGridY = (viewMaxY / logicalGridSpacing).ceil();

    for (int gridX = minGridX; gridX <= maxGridX; gridX++) {
      for (int gridY = minGridY; gridY <= maxGridY; gridY++) {
        final cellSeed = ((gridX * 73856093) ^ (gridY * 19349663)) & 0x7fffffff;
        final rCell = Random(cellSeed);
        if (rCell.nextDouble() > 0.45) continue;

        final depth = 15.0 + rCell.nextDouble() * 45.0;
        final sizeMult = 0.5 + rCell.nextDouble() * 0.3;
        final w = logicalGridSpacing * sizeMult;
        final h = logicalGridSpacing * sizeMult;

        final logicalX =
            gridX * logicalGridSpacing + (logicalGridSpacing - w) / 2;
        final logicalY =
            gridY * logicalGridSpacing + (logicalGridSpacing - h) / 2;

        final screenX = centerScreen.dx + (logicalX - cameraOffset.dx) * zoom;
        final screenY = centerScreen.dy + (logicalY - cameraOffset.dy) * zoom;

        final dx = (screenX + (w * zoom) / 2 - centerScreen.dx) * 0.12;
        final dy = (screenY + (h * zoom) / 2 - centerScreen.dy) * 0.12;

        final p0 = Offset(screenX, screenY);
        final p1 = Offset(screenX + w * zoom, screenY);
        final p2 = Offset(screenX + w * zoom, screenY + h * zoom);
        final p3 = Offset(screenX, screenY + h * zoom);

        final t0 = p0 + Offset(dx, dy) - Offset(0, depth * zoom);
        final t1 = p1 + Offset(dx, dy) - Offset(0, depth * zoom);
        final t2 = p2 + Offset(dx, dy) - Offset(0, depth * zoom);
        final t3 = p3 + Offset(dx, dy) - Offset(0, depth * zoom);

        // Skip buildings far outside the screen but keep a light padded band
        // so new buildings can still appear from any direction while panning.
        final minX = min(
          min(min(p0.dx, p1.dx), min(p2.dx, p3.dx)),
          min(min(t0.dx, t1.dx), min(t2.dx, t3.dx)),
        );
        final maxX = max(
          max(max(p0.dx, p1.dx), max(p2.dx, p3.dx)),
          max(max(t0.dx, t1.dx), max(t2.dx, t3.dx)),
        );
        final minY = min(
          min(min(p0.dy, p1.dy), min(p2.dy, p3.dy)),
          min(min(t0.dy, t1.dy), min(t2.dy, t3.dy)),
        );
        final maxY = max(
          max(max(p0.dy, p1.dy), max(p2.dy, p3.dy)),
          max(max(t0.dy, t1.dy), max(t2.dy, t3.dy)),
        );

        if (maxX < -drawMarginPx ||
            minX > size.width + drawMarginPx ||
            maxY < -drawMarginPx ||
            minY > size.height + drawMarginPx) {
          continue;
        }

        // Make edge entry visibly "spawn" as you pan in any direction.
        final center = Offset(
          (p0.dx + p1.dx + p2.dx + p3.dx) / 4,
          (p0.dy + p1.dy + p2.dy + p3.dy) / 4,
        );
        final edgeDistance = min(
          min(center.dx, size.width - center.dx),
          min(center.dy, size.height - center.dy),
        );
        final spawnProgress = (edgeDistance / spawnBandPx).clamp(0.0, 1.0);
        if (spawnProgress <= 0.0) continue;
        final eased = pow(spawnProgress, 1.3).toDouble();
        final spawnScale = 0.45 + 0.55 * eased;

        Offset scaleFrom(Offset point) =>
            center + (point - center) * spawnScale;

        final sp0 = scaleFrom(p0);
        final sp1 = scaleFrom(p1);
        final sp2 = scaleFrom(p2);
        final sp3 = scaleFrom(p3);
        final st0 = scaleFrom(t0);
        final st1 = scaleFrom(t1);
        final st2 = scaleFrom(t2);
        final st3 = scaleFrom(t3);

        final colorValue = 0.3 + rCell.nextDouble() * 0.4;
        final alphaMul = 0.15 + 0.85 * eased;
        final baseColor = Colors.pinkAccent.withValues(
          alpha: colorValue * 0.5 * alphaMul,
        );
        final topColor = Colors.pinkAccent.withValues(
          alpha: colorValue * alphaMul,
        );
        final sideColor = Colors.pinkAccent.shade400.withValues(
          alpha: colorValue * 0.7 * alphaMul,
        );

        if (dx > 0) {
          final leftPath = Path()
            ..moveTo(sp0.dx, sp0.dy)
            ..lineTo(st0.dx, st0.dy)
            ..lineTo(st3.dx, st3.dy)
            ..lineTo(sp3.dx, sp3.dy)
            ..close();
          canvas.drawPath(leftPath, Paint()..color = sideColor);
        } else {
          final rightPath = Path()
            ..moveTo(sp1.dx, sp1.dy)
            ..lineTo(st1.dx, st1.dy)
            ..lineTo(st2.dx, st2.dy)
            ..lineTo(sp2.dx, sp2.dy)
            ..close();
          canvas.drawPath(rightPath, Paint()..color = sideColor);
        }

        if (dy > 0) {
          final topFacePath = Path()
            ..moveTo(sp0.dx, sp0.dy)
            ..lineTo(sp1.dx, sp1.dy)
            ..lineTo(st1.dx, st1.dy)
            ..lineTo(st0.dx, st0.dy)
            ..close();
          canvas.drawPath(topFacePath, Paint()..color = baseColor);
        } else {
          final bottomFacePath = Path()
            ..moveTo(sp3.dx, sp3.dy)
            ..lineTo(sp2.dx, sp2.dy)
            ..lineTo(st2.dx, st2.dy)
            ..lineTo(st3.dx, st3.dy)
            ..close();
          canvas.drawPath(bottomFacePath, Paint()..color = baseColor);
        }

        // Top face
        final topPath = Path()
          ..moveTo(st0.dx, st0.dy)
          ..lineTo(st1.dx, st1.dy)
          ..lineTo(st2.dx, st2.dy)
          ..lineTo(st3.dx, st3.dy)
          ..close();
        canvas.drawPath(topPath, Paint()..color = topColor);

        // Building window lights (tiny cyan dots on face)
        if (rCell.nextDouble() > 0.3) {
          final windowPaint = Paint()
            ..color = Colors.cyanAccent.withValues(
              alpha: (0.2 + 0.3 * sin(time * 1.5 + gridX * 0.7)) * alphaMul,
            );
          final faceCenter = Offset(
            (st0.dx + st1.dx + st2.dx + st3.dx) / 4,
            (st0.dy + st1.dy + st2.dy + st3.dy) / 4,
          );
          canvas.drawCircle(faceCenter, 1.5 * zoom, windowPaint);
        }
      }
    }

    // ── Connection lines between nodes ────────────────────────────
    for (final node in MapGraph.nodes.values) {
      for (final targetId in node.unlocks) {
        final targetNode = MapGraph.nodes[targetId];
        if (targetNode == null) continue;

        final isUnlockedPath = playerStats.unlockedNodes.contains(
          targetNode.id,
        );
        final isCompletedPath =
            playerStats.completedNodes.contains(node.id) &&
            playerStats.completedNodes.contains(targetNode.id);

        Color lineColor;
        double lineWidth;
        if (isCompletedPath) {
          lineColor = Colors.cyanAccent;
          lineWidth = 4.0;
        } else if (isUnlockedPath) {
          lineColor = Colors.pinkAccent;
          lineWidth = 3.0;
        } else {
          lineColor = Colors.red.withValues(alpha: 0.15);
          lineWidth = 2.0;
        }

        final lp1 =
            centerScreen + (Offset(node.x, node.y) - cameraOffset) * zoom;
        final lp2 =
            centerScreen +
            (Offset(targetNode.x, targetNode.y) - cameraOffset) * zoom;

        // Base line
        canvas.drawLine(
          lp1,
          lp2,
          Paint()
            ..color = lineColor
            ..strokeWidth = lineWidth * zoom
            ..strokeCap = StrokeCap.round,
        );

        // Glow
        if (isUnlockedPath || isCompletedPath) {
          canvas.drawLine(
            lp1,
            lp2,
            Paint()
              ..color = lineColor.withValues(alpha: 0.4)
              ..strokeWidth = (lineWidth + 6) * zoom
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );

          // Animated pulse dot traveling along unlocked paths
          if (isUnlockedPath && !isCompletedPath) {
            final t = (time * 0.4) % 1.0;
            final dotPos = Offset(
              lp1.dx + (lp2.dx - lp1.dx) * t,
              lp1.dy + (lp2.dy - lp1.dy) * t,
            );
            canvas.drawCircle(
              dotPos,
              3.0 * zoom,
              Paint()
                ..color = Colors.pinkAccent.withValues(alpha: 0.9)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
            );
            canvas.drawCircle(
              dotPos,
              1.5 * zoom,
              Paint()..color = Colors.white.withValues(alpha: 0.8),
            );
          }
        }
      }
    }

    // ── Floating particles ────────────────────────────────────────
    for (final p in particles) {
      if (p.alpha <= 0 || p.size <= 0) continue;
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        Paint()
          ..color = p.color.withValues(alpha: p.alpha.clamp(0.0, 1.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // ── Vignette overlay ──────────────────────────────────────────
    final vignetteRect = Offset.zero & size;
    canvas.drawRect(
      vignetteRect,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
          stops: const [0.5, 1.0],
        ).createShader(vignetteRect),
    );
  }

  @override
  bool shouldRepaint(covariant _MapBackgroundPainter oldDelegate) => true;
}

// ══════════════════════════════════════════════════════════════════════════
// Scanline overlay — animated CRT-style scanlines
// ══════════════════════════════════════════════════════════════════════════
class _ScanlineOverlayPainter extends CustomPainter {
  final double time;
  _ScanlineOverlayPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    // Slow-moving scanline band
    final bandY = (time * 25) % (size.height + 200) - 100;
    final bandPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.cyanAccent.withValues(alpha: 0.03),
          Colors.cyanAccent.withValues(alpha: 0.06),
          Colors.cyanAccent.withValues(alpha: 0.03),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, bandY - 50, size.width, 100));
    canvas.drawRect(Rect.fromLTWH(0, bandY - 50, size.width, 100), bandPaint);

    // Static scanlines (every 3 pixels)
    final scanPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanlineOverlayPainter old) => true;
}

// ══════════════════════════════════════════════════════════════════════════
// VFX data classes
// ══════════════════════════════════════════════════════════════════════════
class _MapParticle {
  double x, y, vx, vy, size, alpha, phase;
  final Color color;

  _MapParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.phase,
    required this.color,
  });

  static const _colors = [
    Colors.cyanAccent,
    Colors.pinkAccent,
    Color(0xFF44FF88),
    Color(0xFF8844FF),
  ];

  factory _MapParticle.random(Random rng) {
    return _MapParticle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      vx: (rng.nextDouble() - 0.5) * 0.003,
      vy: -(0.001 + rng.nextDouble() * 0.008),
      size: 0.8 + rng.nextDouble() * 2.5,
      alpha: 0.1 + rng.nextDouble() * 0.4,
      phase: rng.nextDouble() * pi * 2,
      color: _colors[rng.nextInt(_colors.length)],
    );
  }

  void reset(Random rng) {
    x = rng.nextDouble();
    y = 1.05 + rng.nextDouble() * 0.1;
    vx = (rng.nextDouble() - 0.5) * 0.003;
    vy = -(0.001 + rng.nextDouble() * 0.008);
    size = 0.8 + rng.nextDouble() * 2.5;
    alpha = 0.1 + rng.nextDouble() * 0.4;
  }

  void update(double dt) {
    x += vx + sin(phase + y * 6) * 0.001;
    y += vy;
    alpha -= dt * 0.15;
    size -= dt * 0.5;
    phase += dt * 2.0;
  }
}

class _DataStream {
  double x;
  double startY;
  double endY;
  double progress;
  double speed;
  Color color;

  _DataStream({
    required this.x,
    required this.startY,
    required this.endY,
    required this.progress,
    required this.speed,
    required this.color,
  });

  static const _colors = [
    Colors.cyanAccent,
    Color(0xFF44FF88),
    Colors.pinkAccent,
  ];

  factory _DataStream.random(Random rng) {
    return _DataStream(
      x: rng.nextDouble(),
      startY: -0.05,
      endY: 1.05,
      progress: rng.nextDouble(), // start at random position
      speed: 0.15 + rng.nextDouble() * 0.3,
      color: _colors[rng.nextInt(_colors.length)],
    );
  }

  void reset(Random rng) {
    x = rng.nextDouble();
    progress = -0.15;
    speed = 0.15 + rng.nextDouble() * 0.3;
    color = _colors[rng.nextInt(_colors.length)];
  }

  void update(double dt) {
    progress += speed * dt;
  }
}
