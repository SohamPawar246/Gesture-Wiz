import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../models/gesture_cursor_controller.dart';
import '../systems/settings_manager.dart';
import 'gesture_cursor_overlay.dart';

class SettingsPanel extends StatefulWidget {
  final SettingsManager settings;
  final GestureCursorController? controller;
  final VoidCallback onClose;

  const SettingsPanel({
    super.key,
    required this.settings,
    this.controller,
    required this.onClose,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  static const _green = Color(0xFF44FF44);
  static const _dimGreen = Color(0xFF2F6A45);
  static const _panelBg = Color(0xF0060C0C);

  Widget _gestureWrap({required Widget child, required VoidCallback onTap}) {
    final ctrl = widget.controller;
    if (ctrl == null) return child;
    return GestureTapTarget(
      controller: ctrl,
      onTap: onTap,
      dwellSeconds: 0.8,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: const Color(0xCC000000),
        child: Center(
          child: ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) => _buildPanel(),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    final s = widget.settings;

    return Container(
      width: 440,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        color: _panelBg,
        border: Border.all(color: _green.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            'SETTINGS',
            style: TextStyle(
              color: _green,
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              shadows: [
                Shadow(blurRadius: 16, color: _green.withValues(alpha: 0.7)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _divider(),
          const SizedBox(height: 18),

          // Hand sensitivity
          _sliderRow(
            label: 'HAND SENSITIVITY',
            leftHint: 'SMOOTH',
            rightHint: 'SNAPPY',
            steps: 7,
            value: s.handSensitivity,
            min: 0.30,
            max: 0.95,
            onChanged: s.setHandSensitivity,
          ),
          const SizedBox(height: 14),

          // Face sensitivity
          _sliderRow(
            label: 'FACE SENSITIVITY',
            leftHint: 'DEFAULT',
            rightHint: 'ULTRA MAX',
            steps: 7,
            value: s.faceSensitivity,
            min: 0.0,
            max: 1.0,
            onChanged: s.setFaceSensitivity,
          ),
          const SizedBox(height: 14),

          // Resolution / Pixelation
          _sliderRow(
            label: 'RESOLUTION',
            leftHint: 'CRISP',
            rightHint: 'RETRO',
            steps: 7,
            value: s.pixelationLevel,
            min: 1.0,
            max: 4.0,
            onChanged: s.setPixelationLevel,
          ),
          const SizedBox(height: 18),
          _divider(),
          const SizedBox(height: 14),

          // Audio toggles
          Row(
            children: [
              Expanded(
                child: _toggleButton(
                  label: 'MUTE BGM',
                  icon: s.bgmMuted ? Icons.music_off : Icons.music_note,
                  isActive: s.bgmMuted,
                  onTap: () => s.setBgmMuted(!s.bgmMuted),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _toggleButton(
                  label: 'MUTE ALL',
                  icon: s.allMuted ? Icons.volume_off : Icons.volume_up,
                  isActive: s.allMuted,
                  onTap: () => s.setAllMuted(!s.allMuted),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          _divider(),
          const SizedBox(height: 14),

          // Close button
          _gestureWrap(
            onTap: widget.onClose,
            child: _CloseButton(onTap: widget.onClose),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            _green.withValues(alpha: 0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required String leftHint,
    required String rightHint,
    required int steps,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _green,
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              leftHint,
              style: const TextStyle(
                color: _dimGreen,
                fontFamily: 'monospace',
                fontSize: 8,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SegmentedBar(
                steps: steps,
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
                controller: widget.controller,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              rightHint,
              style: const TextStyle(
                color: _dimGreen,
                fontFamily: 'monospace',
                fontSize: 8,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _toggleButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return _gestureWrap(
      onTap: onTap,
      child: _ToggleWidget(
        label: label,
        icon: icon,
        isActive: isActive,
        onTap: onTap,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Segmented Bar — each segment is a GestureTapTarget-compatible tap zone.
// ══════════════════════════════════════════════════════════════════════════
class _SegmentedBar extends StatelessWidget {
  final int steps;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final GestureCursorController? controller;

  const _SegmentedBar({
    required this.steps,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps, (i) {
        final stepValue = min + (max - min) * (i / (steps - 1));
        final isActive = value >= stepValue - (max - min) / (steps - 1) * 0.5;

        Widget segment = MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => onChanged(stepValue),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(
                        0xFF44FF44,
                      ).withValues(alpha: 0.7 + 0.3 * (i / (steps - 1)))
                    : const Color(0xFF0E1A1A),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF44FF44).withValues(alpha: 0.6)
                      : const Color(0xFF1A2E2E),
                  width: 0.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFF44FF44).withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        );

        if (controller != null) {
          segment = GestureTapTarget(
            controller: controller!,
            onTap: () => onChanged(stepValue),
            dwellSeconds: 0.6,
            child: segment,
          );
        }

        return Expanded(child: segment);
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Toggle Widget
// ══════════════════════════════════════════════════════════════════════════
class _ToggleWidget extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleWidget({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ToggleWidget> createState() => _ToggleWidgetState();
}

class _ToggleWidgetState extends State<_ToggleWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? const Color(0xFFFF4444)
        : const Color(0xFF44FF44);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isActive
                ? color.withValues(alpha: 0.15)
                : color.withValues(alpha: _hovered ? 0.1 : 0.04),
            border: Border.all(
              color: color.withValues(
                alpha: _hovered || widget.isActive ? 0.8 : 0.4,
              ),
              width: 1.5,
            ),
            boxShadow: _hovered || widget.isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Close Button
// ══════════════════════════════════════════════════════════════════════════
class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF44FF44);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? color.withValues(alpha: 0.15)
                : color.withValues(alpha: 0.05),
            border: Border.all(
              color: color.withValues(alpha: _hovered ? 0.9 : 0.5),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.close,
                color: _hovered ? Palette.uiWhite : color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'CLOSE',
                style: TextStyle(
                  color: _hovered ? Palette.uiWhite : color,
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  shadows: _hovered
                      ? [
                          Shadow(
                            blurRadius: 12,
                            color: color.withValues(alpha: 0.8),
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
  }
}
