import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class PixelationWrapper extends StatefulWidget {
  final double level;
  final Widget child;

  const PixelationWrapper({
    super.key,
    required this.level,
    required this.child,
  });

  @override
  State<PixelationWrapper> createState() => _PixelationWrapperState();
}

class _PixelationWrapperState extends State<PixelationWrapper> {
  final GlobalKey _boundaryKey = GlobalKey();
  ui.Image? _snapshot;
  bool _capturing = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    if (widget.level > 1.0) _scheduleCapture();
  }

  @override
  void didUpdateWidget(PixelationWrapper old) {
    super.didUpdateWidget(old);
    if (widget.level > 1.0 && !_scheduled) {
      _scheduleCapture();
    } else if (widget.level <= 1.0) {
      _snapshot?.dispose();
      _snapshot = null;
    }
  }

  void _scheduleCapture() {
    if (_scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || widget.level <= 1.0) return;
      _doCapture();
    });
  }

  Future<void> _doCapture() async {
    if (_capturing || !mounted || widget.level <= 1.0) return;
    _capturing = true;

    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) {
      _capturing = false;
      _scheduleCapture();
      return;
    }

    try {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final ratio = (dpr / widget.level).clamp(0.1, dpr);
      final image = await boundary.toImage(pixelRatio: ratio);
      if (mounted) {
        final old = _snapshot;
        _snapshot = image;
        old?.dispose();
        setState(() {});
        _scheduleCapture();
      } else {
        image.dispose();
      }
    } catch (_) {
      if (mounted) _scheduleCapture();
    }
    _capturing = false;
  }

  @override
  void dispose() {
    _snapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.level <= 1.0) {
      return widget.child;
    }

    if (!_scheduled && !_capturing) {
      _scheduleCapture();
    }

    return Stack(
      children: [
        RepaintBoundary(key: _boundaryKey, child: widget.child),
        if (_snapshot != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RawImage(
                image: _snapshot,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
      ],
    );
  }
}
