import 'package:flutter/material.dart';
import '../systems/performance_monitor.dart';
import '../game/palette.dart';

/// Displays FPS and performance metrics overlay
class FpsDisplay extends StatelessWidget {
  const FpsDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PerformanceMonitor.instance,
      builder: (context, _) {
        final monitor = PerformanceMonitor.instance;

        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xDD070A0C),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _getStatusColor(monitor.status),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor(
                      monitor.status,
                    ).withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ],
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
                    Palette.uiWhite.withValues(alpha: 0.7),
                  ),

                  // Min-Max FPS
                  _buildMetricRow(
                    'Range',
                    '${monitor.minFps.toStringAsFixed(0)}-${monitor.maxFps.toStringAsFixed(0)}',
                    Palette.uiWhite.withValues(alpha: 0.5),
                  ),

                  // Entities
                  if (monitor.totalEntities > 0)
                    _buildMetricRow(
                      'Entities',
                      '${monitor.totalEntities}',
                      Palette.uiWhite.withValues(alpha: 0.5),
                    ),
                ],
              ),
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
            fontSize: 16,
            color: Palette.uiWhite.withValues(alpha: 0.78),
            height: 1.2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'VT323',
            fontSize: 16,
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
        return const Color(0xFF7BFFA7);
      case PerformanceStatus.good:
        return Palette.uiMana;
      case PerformanceStatus.warning:
        return Colors.orange;
      case PerformanceStatus.critical:
        return Palette.impactRed;
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

        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, right: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xD9070A0C),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _getStatusColor(monitor.status).withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: Text(
                '${monitor.currentFps.toStringAsFixed(0)} FPS',
                style: TextStyle(
                  fontFamily: 'VT323',
                  fontSize: 18,
                  color: _getStatusColor(monitor.status),
                  fontWeight: FontWeight.bold,
                ),
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
        return const Color(0xFF7BFFA7);
      case PerformanceStatus.good:
        return Palette.uiMana;
      case PerformanceStatus.warning:
        return Colors.orange;
      case PerformanceStatus.critical:
        return Palette.impactRed;
    }
  }
}
