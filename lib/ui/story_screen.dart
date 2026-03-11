import 'package:flutter/material.dart';

import '../models/gesture_cursor_controller.dart';
import 'gesture_cursor_overlay.dart';

/// Full-screen story / lore screen with typewriter effect and terminal aesthetic.
class StoryScreen extends StatefulWidget {
  final VoidCallback onContinue;
  final GestureCursorController? controller;

  const StoryScreen({super.key, required this.onContinue, this.controller});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with TickerProviderStateMixin {
  late final AnimationController _typewriterCtrl;
  late final AnimationController _cursorBlink;
  late final AnimationController _fadeInCtrl;

  static const String _storyText =
      'YEAR 2084 \u2014 Big Brother has conquered the world.\n'
      'Surveillance cameras watch every street corner.\n'
      'Your webcam is feeding data to the Ministry right now.\n\n'
      'The Ministry\'s Thought Police are no longer human.\n'
      'Digital constructs \u2014 skulls, eyes, and slimes \u2014\n'
      'patrol the endless dungeon networks beneath the city.\n'
      'They are remnants of erased minds, repurposed as weapons.\n\n'
      'You are one of the last free minds.\n'
      'Captured and thrown into the Ministry\'s deepest prison,\n'
      'you must fight through ten chambers to reach the surface.\n\n'
      'The Resistance taught you the forbidden gestures:\n'
      'hand signs that channel raw energy through the cameras\n'
      'the Ministry uses to watch you. Turn their weapons against them.\n\n'
      'Point to cast fire. Raise your fist to push them back.\n'
      'Open your palm to shield against the darkness.\n'
      'But move carefully \u2014 erratic movements trigger the alarm.\n'
      'If Big Brother notices you, it\'s over.\n\n'
      '\u2014 BIG BROTHER SEES YOUR HANDS \u2014';

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
      duration: Duration(milliseconds: _storyText.length * 28),
    )..addListener(_onType);

    _typewriterCtrl.forward();
  }

  void _onType() {
    final len = (_typewriterCtrl.value * _storyText.length).round();
    if (len != _visibleText.length) {
      setState(() {
        _visibleText = _storyText.substring(0, len);
        _fullyRevealed = len >= _storyText.length;
      });
    }
  }

  void _skipOrContinue() {
    if (!_fullyRevealed) {
      _typewriterCtrl.value = 1.0;
      setState(() {
        _visibleText = _storyText;
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
                          color: const Color(
                            0xFF44FF44,
                          ).withValues(alpha: 0.45),
                          width: 1,
                        ),
                        color: const Color(0xFF001100),
                      ),
                      child: const Text(
                        'INTERCEPTED TRANSMISSION',
                        style: TextStyle(
                          color: Color(0xFF44FF44),
                          fontFamily: 'monospace',
                          fontSize: 11,
                          letterSpacing: 3.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Story terminal box
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 520),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC001800),
                          border: Border.all(
                            color: const Color(0xFF226622),
                            width: 1,
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _cursorBlink,
                          builder: (context, _) {
                            return RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Color(0xFF77BB77),
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
                                        color: Color(
                                          0xFF44FF44,
                                        ).withValues(alpha: _cursorBlink.value),
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

                    // Continue / Skip
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: _wrapGesture(
                        onTap: _skipOrContinue,
                        child: _StoryButton(
                          label: _fullyRevealed ? '▶   CONTINUE' : '⏩  SKIP',
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

// ══════════════════════════════════════════
// Story Button
// ══════════════════════════════════════════
class _StoryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _StoryButton({required this.label, required this.onTap});

  @override
  State<_StoryButton> createState() => _StoryButtonState();
}

class _StoryButtonState extends State<_StoryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const btnColor = Color(0xFF44FF44);
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
                ? btnColor.withValues(alpha: 0.18)
                : btnColor.withValues(alpha: 0.04),
            border: Border.all(
              color: btnColor.withValues(alpha: _hovered ? 0.9 : 0.5),
              width: 1.5,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: btnColor.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? Colors.white : btnColor,
              fontFamily: 'monospace',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.0,
              shadows: _hovered
                  ? [
                      Shadow(
                        blurRadius: 12,
                        color: btnColor.withValues(alpha: 0.8),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
