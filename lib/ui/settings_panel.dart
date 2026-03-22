import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../models/difficulty.dart';
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
  static const _mint = Color(0xFF7BFFA7);
  static const _aqua = Color(0xFF48FFD8);
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
            builder: (context, _) => _buildPanel(context),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final s = widget.settings;
    final viewport = MediaQuery.sizeOf(context);
    final panelWidth = (viewport.width - 24).clamp(300.0, 460.0);
    final maxPanelHeight = (viewport.height * 0.9).clamp(420.0, 760.0);

    return Container(
      width: panelWidth,
      constraints: BoxConstraints(maxHeight: maxPanelHeight),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _panelBg,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC081414), Color(0xDD040B0B)],
        ),
        border: Border.all(color: _green.withValues(alpha: 0.45), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.2),
            blurRadius: 44,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: _aqua.withValues(alpha: 0.08),
            blurRadius: 70,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -38,
            right: -28,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _aqua.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green.withValues(alpha: 0.05),
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = (constraints.maxWidth - 2).clamp(
                280.0,
                430.0,
              );
              return Align(
                alignment: Alignment.topCenter,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(1.0)),
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SETTINGS',
                            style: TextStyle(
                              color: _mint,
                              fontFamily: 'monospace',
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 5,
                              shadows: [
                                Shadow(
                                  blurRadius: 18,
                                  color: _green.withValues(alpha: 0.65),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'CALIBRATE THE EYE PROTOCOL',
                            style: TextStyle(
                              color: _dimGreen,
                              fontFamily: 'monospace',
                              fontSize: 8,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _divider(),
                          const SizedBox(height: 9),

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
                          const SizedBox(height: 6),

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
                          const SizedBox(height: 6),

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
                          const SizedBox(height: 8),
                          _divider(),
                          const SizedBox(height: 7),

                          _difficultyRow(s),
                          const SizedBox(height: 8),
                          _divider(),
                          const SizedBox(height: 7),

                          Row(
                            children: [
                              Expanded(
                                child: _toggleButton(
                                  label: 'MUTE BGM',
                                  icon: s.bgmMuted
                                      ? Icons.music_off
                                      : Icons.music_note,
                                  isActive: s.bgmMuted,
                                  onTap: () => s.setBgmMuted(!s.bgmMuted),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _toggleButton(
                                  label: 'MUTE ALL',
                                  icon: s.allMuted
                                      ? Icons.volume_off
                                      : Icons.volume_up,
                                  isActive: s.allMuted,
                                  onTap: () => s.setAllMuted(!s.allMuted),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),

                          Row(
                            children: [
                              Expanded(
                                child: _toggleButton(
                                  label: s.useMouseMode
                                      ? 'MOUSE MODE ON'
                                      : 'MOUSE MODE OFF',
                                  icon: s.useMouseMode
                                      ? Icons.mouse
                                      : Icons.pan_tool,
                                  isActive: s.useMouseMode,
                                  activeColor: const Color(0xFFFF7E6B),
                                  onTap: () =>
                                      s.setUseMouseMode(!s.useMouseMode),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _toggleButton(
                                  label: 'SHOW FPS',
                                  icon: s.showFps
                                      ? Icons.speed
                                      : Icons.speed_outlined,
                                  isActive: s.showFps,
                                  activeColor: _aqua,
                                  onTap: () => s.setShowFps(!s.showFps),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          _divider(),
                          const SizedBox(height: 9),

                          _gestureWrap(
                            onTap: widget.onClose,
                            child: _CloseButton(onTap: widget.onClose),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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
            _aqua.withValues(alpha: 0.3),
            _green.withValues(alpha: 0.75),
            _aqua.withValues(alpha: 0.3),
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
        const SizedBox(height: 5),
        Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                leftHint,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: _dimGreen,
                  fontFamily: 'monospace',
                  fontSize: 8,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 6),
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
            const SizedBox(width: 6),
            SizedBox(
              width: 58,
              child: Text(
                rightHint,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _dimGreen,
                  fontFamily: 'monospace',
                  fontSize: 8,
                  letterSpacing: 1,
                ),
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
    Color? activeColor,
  }) {
    return _gestureWrap(
      onTap: onTap,
      child: _ToggleWidget(
        label: label,
        icon: icon,
        isActive: isActive,
        onTap: onTap,
        activeColor: activeColor,
      ),
    );
  }

  Widget _difficultyRow(SettingsManager s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DIFFICULTY',
          style: TextStyle(
            color: _green,
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: Difficulty.values.map((d) {
            final isSelected = s.difficulty == d;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: _gestureWrap(
                  onTap: () => s.setDifficulty(d),
                  child: _DifficultyButton(
                    difficulty: d,
                    isSelected: isSelected,
                    onTap: () => s.setDifficulty(d),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 5),
        Center(
          child: Text(
            s.difficulty.description,
            style: const TextStyle(
              color: _dimGreen,
              fontFamily: 'monospace',
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

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
              height: 16,
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

class _ToggleWidget extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color? activeColor;

  const _ToggleWidget({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.activeColor,
  });

  @override
  State<_ToggleWidget> createState() => _ToggleWidgetState();
}

class _ToggleWidgetState extends State<_ToggleWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor ?? const Color(0xFF7BFFA7);
    final inactiveColor = const Color(0xFF3D8F56);
    final color = widget.isActive ? activeColor : inactiveColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isActive
                ? color.withValues(alpha: 0.16)
                : color.withValues(alpha: _hovered ? 0.12 : 0.05),
            border: Border.all(
              color: color.withValues(
                alpha: _hovered || widget.isActive ? 0.85 : 0.45,
              ),
              width: 1.3,
            ),
            boxShadow: _hovered || widget.isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: color, size: 16),
              const SizedBox(width: 7),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: color,
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 10),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.4,
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

class _DifficultyButton extends StatefulWidget {
  final Difficulty difficulty;
  final bool isSelected;
  final VoidCallback onTap;

  const _DifficultyButton({
    required this.difficulty,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DifficultyButton> createState() => _DifficultyButtonState();
}

class _DifficultyButtonState extends State<_DifficultyButton> {
  bool _hovered = false;

  Color get _color {
    switch (widget.difficulty) {
      case Difficulty.easy:
        return const Color(0xFF44CC44);
      case Difficulty.normal:
        return const Color(0xFFCCCC44);
      case Difficulty.hard:
        return const Color(0xFFCC4444);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? color.withValues(alpha: 0.2)
                : color.withValues(alpha: _hovered ? 0.1 : 0.03),
            border: Border.all(
              color: color.withValues(
                alpha: widget.isSelected ? 0.9 : (_hovered ? 0.6 : 0.3),
              ),
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.difficulty.displayName,
              style: TextStyle(
                color: widget.isSelected || _hovered
                    ? color
                    : color.withValues(alpha: 0.7),
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
