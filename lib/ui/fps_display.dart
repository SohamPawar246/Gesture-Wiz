import 'package:flutter/material.dart';
import '../systems/performance_monitor.dart';
import '../ui/palette.dart';

/// Displays FPS and performance metrics overlay
class FpsDisplay extends StatelessWidget {
  const FpsDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PerformanceMonitor.instance,
      builder: (context, _) {
        final monitor = PerformanceMonitor.instance;

        return Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _getStatusColor(monitor.status),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // FPS line
                _buildMetricRow(
                  'FPS',
                  monitor.currentFps.toStringAsFixed(1),
                  _getStatusColor(monitor.status),
                ),

                // Frame time
                _buildMetricRow(
                  'Frame',
                  '${monitor.avgFrameTime.toStringAsFixed(1)}ms',
                  Palette.uiWhite.withOpacity(0.7),
                ),

                // Min-Max FPS
                _buildMetricRow(
                  'Range',
                  '${monitor.minFps.toStringAsFixed(0)}-${monitor.maxFps.toStringAsFixed(0)}',
                  Palette.uiWhite.withOpacity(0.5),
                ),

                // Entities
                if (monitor.totalEntities > 0)
                  _buildMetricRow(
                    'Entities',
                    '${monitor.totalEntities}',
                    Palette.uiWhite.withOpacity(0.5),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontFamily: 'VT323',
            fontSize: 14,
            color: Palette.uiWhite.withOpacity(0.6),
            height: 1.2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'VT323',
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(PerformanceStatus status) {
    switch (status) {
      case PerformanceStatus.excellent:
        return Palette.healthGreen;
      case PerformanceStatus.good:
        return Palette.uiMana;
      case PerformanceStatus.warning:
        return Colors.orange;
      case PerformanceStatus.critical:
        return Palette.enemyRed;
    }
  }
}

/// Compact FPS counter (just the number)
class CompactFpsDisplay extends StatelessWidget {
  const CompactFpsDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PerformanceMonitor.instance,
      builder: (context, _) {
        final monitor = PerformanceMonitor.instance;

        return Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '${monitor.currentFps.toStringAsFixed(0)} FPS',
              style: TextStyle(
                fontFamily: 'VT323',
                fontSize: 16,
                color: _getStatusColor(monitor.status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(PerformanceStatus status) {
    switch (status) {
      case PerformanceStatus.excellent:
        return Palette.healthGreen;
      case PerformanceStatus.good:
        return Palette.uiMana;
      case PerformanceStatus.warning:
        return Colors.orange;
      case PerformanceStatus.critical:
        return Palette.enemyRed;
    }
  }
}
