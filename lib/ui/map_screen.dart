import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/gesture_cursor_controller.dart';
import '../models/map_node.dart';
import '../models/player_stats.dart';
import 'gesture_cursor_overlay.dart';
import 'glitch_text.dart';

class MapScreen extends StatefulWidget {
  final PlayerStats playerStats;
  final GestureCursorController cursorController;
  final void Function(MapNode node) onNodeSelected;

  const MapScreen({
    super.key,
    required this.playerStats,
    required this.cursorController,
    required this.onNodeSelected,
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
  double _zoom = 0.8; // Base zoom

  final double _mapWidth = 2000;
  final double _mapHeight = 2000;

  @override
  void initState() {
    super.initState();
    // Center camera on current node initially
    final currentNode = MapGraph.nodes[widget.playerStats.currentNodeId];
    if (currentNode != null) {
      _cameraOffset = Offset(currentNode.x, currentNode.y);
    }

    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    if (!mounted) return;
    final dt = _prevElapsed != null
        ? (elapsed - _prevElapsed!).inMicroseconds / 1000000.0
        : 0.016;
    _prevElapsed = elapsed;

    // Pan camera if cursor is near edges
    if (!widget.cursorController.isVisible) return;

    final cx = widget.cursorController.posX;
    final cy = widget.cursorController.posY;

    double panX = 0;
    double panY = 0;
    const edgeMargin = 0.15;
    const maxPanSpeed = 600.0; // Logical pixels per second

    if (cx < edgeMargin) {
      panX = -maxPanSpeed * (1 - cx / edgeMargin);
    } else if (cx > 1 - edgeMargin) {
      panX = maxPanSpeed * (1 - (1 - cx) / edgeMargin);
    }

    if (cy < edgeMargin) {
      panY = -maxPanSpeed * (1 - cy / edgeMargin);
    } else if (cy > 1 - edgeMargin) {
      panY = maxPanSpeed * (1 - (1 - cy) / edgeMargin);
    }

    if (panX != 0 || panY != 0) {
      setState(() {
        _cameraOffset += Offset(panX * dt, panY * dt);
        // Clamp to map bounds
        _cameraOffset = Offset(
          _cameraOffset.dx.clamp(0.0, _mapWidth),
          _cameraOffset.dy.clamp(0.0, _mapHeight),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerScreen = Offset(screenSize.width / 2, screenSize.height / 2);

    return Scaffold(
      backgroundColor: Colors.black, // Deep black background for map
      body: Stack(
        children: [
          // 1. Grid & Lines Background Painter
          Positioned.fill(
            child: CustomPaint(
              painter: _MapBackgroundPainter(
                cameraOffset: _cameraOffset,
                zoom: _zoom,
                centerScreen: centerScreen,
                playerStats: widget.playerStats,
              ),
            ),
          ),

          // 2. Nodes as gesture-tappable widgets
          ...MapGraph.nodes.values.map((node) {
            // Render node
            final screenPos =
                centerScreen + (Offset(node.x, node.y) - _cameraOffset) * _zoom;

            final isUnlocked = widget.playerStats.unlockedNodes.contains(
              node.id,
            );
            final isCompleted = widget.playerStats.completedNodes.contains(
              node.id,
            );
            final isCurrent = widget.playerStats.currentNodeId == node.id;

            Color nodeColor;
            if (isCurrent && !isCompleted) {
              nodeColor = Colors.greenAccent; // Active current node
            } else if (isCompleted) {
              nodeColor = Colors.cyanAccent; // Completed
            } else if (isUnlocked) {
              nodeColor = Colors.pinkAccent; // Unlocked next steps
            } else {
              nodeColor = Colors.red.withValues(alpha: 0.3); // Locked
            }

            // Only uncompleted unlocked nodes are playable
            final isPlayable = isUnlocked && !isCompleted;

            return Positioned(
              left: screenPos.dx - 40,
              top: screenPos.dy - 40,
              width: 80,
              height: 80,
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

          // 3. UI Overlay (Titles, legend)
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
        ],
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

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: locked ? Colors.transparent : Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isCurrent ? 3.0 : 2.0),
              boxShadow: locked
                  ? null
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
            ),
            child: nodeIcon,
          ),
          const SizedBox(height: 4),
          Text(
            node.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              shadows: locked ? null : [Shadow(color: color, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBackgroundPainter extends CustomPainter {
  final Offset cameraOffset;
  final double zoom;
  final Offset centerScreen;
  final PlayerStats playerStats;

  _MapBackgroundPainter({
    required this.cameraOffset,
    required this.zoom,
    required this.centerScreen,
    required this.playerStats,
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
      ..color = Colors.cyanAccent.withValues(alpha: 0.1)
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

    // Draw 3D pink buildings
    final seedOffsetX = (cameraOffset.dx / logicalGridSpacing).floor();
    final seedOffsetY = (cameraOffset.dy / logicalGridSpacing).floor();

    for (int i = -2; i <= (size.width / gridSpacing).ceil() + 2; i++) {
      for (int j = -2; j <= (size.height / gridSpacing).ceil() + 2; j++) {
        final gridX = i + seedOffsetX;
        final gridY = j + seedOffsetY;

        final rCell = Random(gridX.abs() * 1000 + gridY.abs());
        if (rCell.nextDouble() > 0.45)
          continue; // 45% chance to have a building

        final depth = 15.0 + rCell.nextDouble() * 45.0; // Building height
        final sizeMult =
            0.5 + rCell.nextDouble() * 0.3; // Building size relative to cell
        final w = logicalGridSpacing * sizeMult;
        final h = logicalGridSpacing * sizeMult;

        final logicalX =
            gridX * logicalGridSpacing + (logicalGridSpacing - w) / 2;
        final logicalY =
            gridY * logicalGridSpacing + (logicalGridSpacing - h) / 2;

        final screenX = centerScreen.dx + (logicalX - cameraOffset.dx) * zoom;
        final screenY = centerScreen.dy + (logicalY - cameraOffset.dy) * zoom;

        // Perspective shift based on distance from center
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

        final colorValue = 0.3 + rCell.nextDouble() * 0.4;
        final baseColor = Colors.pinkAccent.withValues(alpha: colorValue * 0.5);
        final topColor = Colors.pinkAccent.withValues(alpha: colorValue);
        final sideColor = Colors.pinkAccent.shade400.withValues(
          alpha: colorValue * 0.7,
        );

        // Right side or Left side
        if (dx > 0) {
          final leftPath = Path()
            ..moveTo(p0.dx, p0.dy)
            ..lineTo(t0.dx, t0.dy)
            ..lineTo(t3.dx, t3.dy)
            ..lineTo(p3.dx, p3.dy)
            ..close();
          canvas.drawPath(leftPath, Paint()..color = sideColor);
        } else {
          final rightPath = Path()
            ..moveTo(p1.dx, p1.dy)
            ..lineTo(t1.dx, t1.dy)
            ..lineTo(t2.dx, t2.dy)
            ..lineTo(p2.dx, p2.dy)
            ..close();
          canvas.drawPath(rightPath, Paint()..color = sideColor);
        }

        // Front face (facing camera)
        if (dy > 0) {
          final topFacePath = Path()
            ..moveTo(p0.dx, p0.dy)
            ..lineTo(p1.dx, p1.dy)
            ..lineTo(t1.dx, t1.dy)
            ..lineTo(t0.dx, t0.dy)
            ..close();
          canvas.drawPath(topFacePath, Paint()..color = baseColor);
        } else {
          final bottomFacePath = Path()
            ..moveTo(p3.dx, p3.dy)
            ..lineTo(p2.dx, p2.dy)
            ..lineTo(t2.dx, t2.dy)
            ..lineTo(t3.dx, t3.dy)
            ..close();
          canvas.drawPath(bottomFacePath, Paint()..color = baseColor);
        }

        // Top face
        final topPath = Path()
          ..moveTo(t0.dx, t0.dy)
          ..lineTo(t1.dx, t1.dy)
          ..lineTo(t2.dx, t2.dy)
          ..lineTo(t3.dx, t3.dy)
          ..close();
        canvas.drawPath(topPath, Paint()..color = topColor);
      }
    }

    // Draw connection lines between nodes
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

        final p1 =
            centerScreen + (Offset(node.x, node.y) - cameraOffset) * zoom;
        final p2 =
            centerScreen +
            (Offset(targetNode.x, targetNode.y) - cameraOffset) * zoom;

        // Base line
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = lineColor
            ..strokeWidth = lineWidth * zoom
            ..strokeCap = StrokeCap.round,
        );

        // Glow
        if (isUnlockedPath || isCompletedPath) {
          canvas.drawLine(
            p1,
            p2,
            Paint()
              ..color = lineColor.withValues(alpha: 0.4)
              ..strokeWidth = (lineWidth + 6) * zoom
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapBackgroundPainter oldDelegate) {
    return oldDelegate.cameraOffset != cameraOffset ||
        oldDelegate.zoom != zoom ||
        oldDelegate.playerStats != playerStats;
  }
}
