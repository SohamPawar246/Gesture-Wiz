import 'package:flutter/material.dart';

import '../models/gesture_cursor_controller.dart';
import 'gesture_cursor_overlay.dart';

/// Briefing screen shown after completing a node, with typewriter effect.
class NodeBriefingScreen extends StatefulWidget {
  final String briefingText;
  final bool isFinalNode;
  final VoidCallback onContinue;
  final GestureCursorController? controller;

  const NodeBriefingScreen({
    super.key,
    required this.briefingText,
    this.isFinalNode = false,
    required this.onContinue,
    this.controller,
  });

  @override
  State<NodeBriefingScreen> createState() => _NodeBriefingScreenState();
}

class _NodeBriefingScreenState extends State<NodeBriefingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _typewriterCtrl;
  late final AnimationController _cursorBlink;
  late final AnimationController _fadeInCtrl;

  String _visibleText = '';
  bool _fullyRevealed = false;

  @override
  void initState() {
    super.initState();

    _fadeInCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _cursorBlink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);

    _typewriterCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.briefingText.length * 30),
    )..addListener(_onType);

    _typewriterCtrl.forward();
  }

  void _onType() {
    final len = (_typewriterCtrl.value * widget.briefingText.length).round();
    if (len != _visibleText.length) {
      setState(() {
        _visibleText = widget.briefingText.substring(0, len);
        _fullyRevealed = len >= widget.briefingText.length;
      });
    }
  }

  void _skipOrContinue() {
    if (!_fullyRevealed) {
      _typewriterCtrl.value = 1.0;
      setState(() {
        _visibleText = widget.briefingText;
        _fullyRevealed = true;
      });
    } else {
      widget.onContinue();
    }
  }

  @override
  void dispose() {
    _typewriterCtrl.dispose();
    _cursorBlink.dispose();
    _fadeInCtrl.dispose();
    super.dispose();
  }

  Widget _wrapGesture({required Widget child, required VoidCallback onTap}) {
    final ctrl = widget.controller;
    if (ctrl == null) return child;
    return GestureTapTarget(controller: ctrl, onTap: onTap, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isFinalNode
        ? const Color(0xFFFFD700)
        : const Color(0xFF44FF44);
    final headerText = widget.isFinalNode
        ? 'MISSION COMPLETE'
        : 'SECTOR REPORT';

    return Scaffold(
      backgroundColor: const Color(0xFF040808),
      body: GestureDetector(
        onTap: _skipOrContinue,
        behavior: HitTestBehavior.opaque,
        child: FadeTransition(
          opacity: _fadeInCtrl,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Terminal header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.45),
                          width: 1,
                        ),
                        color: widget.isFinalNode
                            ? const Color(0xFF111100)
                            : const Color(0xFF001100),
                      ),
                      child: Text(
                        headerText,
                        style: TextStyle(
                          color: accentColor,
                          fontFamily: 'monospace',
                          fontSize: 11,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Briefing terminal box
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 520),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isFinalNode
                              ? const Color(0xCC181200)
                              : const Color(0xCC001800),
                          border: Border.all(
                            color: widget.isFinalNode
                                ? const Color(0xFF665522)
                                : const Color(0xFF226622),
                            width: 1,
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _cursorBlink,
                          builder: (context, _) {
                            return RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  color: widget.isFinalNode
                                      ? const Color(0xFFBBAA77)
                                      : const Color(0xFF77BB77),
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  height: 1.6,
                                  letterSpacing: 0.5,
                                ),
                                children: [
                                  TextSpan(text: _visibleText),
                                  if (!_fullyRevealed)
                                    TextSpan(
                                      text: '\u2588',
                                      style: TextStyle(
                                        color: accentColor.withValues(
                                          alpha: _cursorBlink.value,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Continue / Skip button
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: _wrapGesture(
                        onTap: _skipOrContinue,
                        child: _BriefingButton(
                          label: _fullyRevealed ? 'CONTINUE' : 'SKIP',
                          icon: _fullyRevealed
                              ? Icons.play_arrow
                              : Icons.fast_forward,
                          color: accentColor,
                          onTap: _skipOrContinue,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      _fullyRevealed
                          ? 'PRESS ANYWHERE OR CLICK TO CONTINUE'
                          : 'PRESS ANYWHERE TO SKIP',
                      style: const TextStyle(
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
        ),
      ),
    );
  }
}

class _BriefingButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;

  const _BriefingButton({
    required this.label,
    this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_BriefingButton> createState() => _BriefingButtonState();
}

class _BriefingButtonState extends State<_BriefingButton> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.18)
                : widget.color.withValues(alpha: 0.04),
            border: Border.all(
              color: widget.color.withValues(alpha: _hovered ? 0.9 : 0.5),
              width: 1.5,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: _hovered ? Colors.white : widget.color,
                  size: 18,
                ),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovered ? Colors.white : widget.color,
                  fontFamily: 'monospace',
                  fontSize: 16,
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
  }
}
