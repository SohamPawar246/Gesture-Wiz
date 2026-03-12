import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A text widget with a cyberpunk glitch effect.
/// Periodically distorts characters and shifts color channels.
class GlitchText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double glitchFrequency; // Glitches per second
  final double glitchIntensity; // 0.0–1.0

  const GlitchText({
    super.key,
    required this.text,
    required this.style,
    this.glitchFrequency = 2.0,
    this.glitchIntensity = 0.5,
  });

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration? _prevElapsed;
  final Random _rng = Random();

  double _timer = 0;
  double _nextGlitchAt = 0;
  bool _glitching = false;
  double _glitchTimer = 0;

  // Glitch params for current active glitch
  double _offsetX = 0;
  double _offsetY = 0;
  String _displayText = '';
  double _redShift = 0;
  double _blueShift = 0;
  int _corruptStart = 0;
  int _corruptLen = 0;

  static const String _glitchChars = '!@#\$%^&*<>_-+=|/\\~';

  @override
  void initState() {
    super.initState();
    _displayText = widget.text;
    _scheduleNextGlitch();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(GlitchText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _displayText = widget.text;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _scheduleNextGlitch() {
    final interval = 1.0 / widget.glitchFrequency;
    _nextGlitchAt = _timer + interval * 0.5 + _rng.nextDouble() * interval;
  }

  void _tick(Duration elapsed) {
    final dt = _prevElapsed != null
        ? (elapsed - _prevElapsed!).inMicroseconds / 1000000.0
        : 0.016;
    _prevElapsed = elapsed;
    _timer += dt;

    if (_glitching) {
      _glitchTimer -= dt;
      if (_glitchTimer <= 0) {
        _glitching = false;
        setState(() {
          _displayText = widget.text;
          _offsetX = 0;
          _offsetY = 0;
          _redShift = 0;
          _blueShift = 0;
        });
        _scheduleNextGlitch();
      }
      return;
    }

    if (_timer >= _nextGlitchAt) {
      _startGlitch();
    }
  }

  void _startGlitch() {
    _glitching = true;
    _glitchTimer = 0.05 + _rng.nextDouble() * 0.12; // 50-170ms

    final intensity = widget.glitchIntensity;
    _offsetX = (_rng.nextDouble() - 0.5) * 8.0 * intensity;
    _offsetY = (_rng.nextDouble() - 0.5) * 4.0 * intensity;
    _redShift = (_rng.nextDouble() - 0.5) * 3.0 * intensity;
    _blueShift = (_rng.nextDouble() - 0.5) * 3.0 * intensity;

    // Corrupt a random chunk of text
    final text = widget.text;
    _corruptStart = _rng.nextInt(text.length);
    _corruptLen =
        1 + _rng.nextInt((text.length * 0.3 * intensity).ceil().clamp(1, 5));
    _corruptLen = _corruptLen.clamp(1, text.length - _corruptStart);

    final buf = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i >= _corruptStart && i < _corruptStart + _corruptLen) {
        buf.write(_glitchChars[_rng.nextInt(_glitchChars.length)]);
      } else {
        buf.write(text[i]);
      }
    }

    setState(() {
      _displayText = buf.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_glitching) {
      return Text(_displayText, style: widget.style);
    }

    return Stack(
      children: [
        // Red channel shift
        Transform.translate(
          offset: Offset(_redShift + _offsetX, _offsetY),
          child: Text(
            _displayText,
            style: widget.style.copyWith(
              color: Colors.red.withValues(alpha: 0.4),
            ),
          ),
        ),
        // Blue channel shift
        Transform.translate(
          offset: Offset(_blueShift + _offsetX, -_offsetY),
          child: Text(
            _displayText,
            style: widget.style.copyWith(
              color: Colors.blue.withValues(alpha: 0.4),
            ),
          ),
        ),
        // Main text with slight offset
        Transform.translate(
          offset: Offset(_offsetX, _offsetY),
          child: Text(_displayText, style: widget.style),
        ),
      ],
    );
  }
}
