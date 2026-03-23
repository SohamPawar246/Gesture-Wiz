import 'package:flutter/material.dart';

import '../game/palette.dart';
import '../models/gesture_cursor_controller.dart';
import '../models/player_stats.dart';
import '../systems/hand_tracking/fallback_tracking_service.dart';
import '../systems/hand_tracking/tracking_service.dart';
import 'gesture_cursor_overlay.dart';
import 'glitch_text.dart';

class CameraPermissionScreen extends StatefulWidget {
  final PlayerStats playerStats;
  final TrackingService trackingService;
  final VoidCallback onPermissionHandled;
  final GestureCursorController? cursorController;

  const CameraPermissionScreen({
    super.key,
    required this.playerStats,
    required this.trackingService,
    required this.onPermissionHandled,
    this.cursorController,
  });

  @override
  State<CameraPermissionScreen> createState() => _CameraPermissionScreenState();
}

class _CameraPermissionScreenState extends State<CameraPermissionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _isRequesting = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Widget _gestureWrap({required Widget child, required VoidCallback onTap}) {
    final ctrl = widget.cursorController;
    if (ctrl == null) return child;
    return GestureTapTarget(controller: ctrl, onTap: onTap, child: child);
  }

  Future<void> _handleAuthorize() async {
    if (_isRequesting) return;
    setState(() {
      _isRequesting = true;
      _errorMsg = null;
    });

    final success = await widget.trackingService.requestCameraPermission();

    if (!mounted) return;

    if (success) {
      await widget.playerStats.setHasSeenCameraPermission(true);
      widget.onPermissionHandled();
    } else {
      setState(() {
        _isRequesting = false;
        _errorMsg = "CAMERA ACCESS DENIED BY OS.\nFALLING BACK TO MANUAL OVERRIDES.";
      });
      // Force fallback mode if applicable
      if (widget.trackingService is FallbackTrackingService) {
        (widget.trackingService as FallbackTrackingService).forceMouseMode = true;
      }
      
      // Auto-proceed after showing error
      Future.delayed(const Duration(seconds: 3), () async {
        if (!mounted) return;
        await widget.playerStats.setHasSeenCameraPermission(true);
        widget.onPermissionHandled();
      });
    }
  }

  Future<void> _handleOverride() async {
    if (_isRequesting) return;
    // Force fallback mode
    if (widget.trackingService is FallbackTrackingService) {
      (widget.trackingService as FallbackTrackingService).forceMouseMode = true;
    }
    await widget.playerStats.setHasSeenCameraPermission(true);
    widget.onPermissionHandled();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.cursorController;

    final body = Stack(
      children: [
        // Background
        Container(
          color: Palette.bgDeep,
        ),
        // Scanlines overlay (simple dark tint instead of missing image asset)
        IgnorePointer(
          child: Container(
            color: Palette.scanLine,
          ),
        ),

        // Main Dialog
        Center(
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0A120A),
              border: Border.all(
                color: const Color(0xFF44FF44),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF44FF44).withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const GlitchText(
                  text: 'UPLINK ESTABLISHMENT',
                  style: TextStyle(
                    color: Color(0xFF44FF44),
                    fontFamily: 'monospace',
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                  ),
                  glitchIntensity: 0.2,
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: const Color(0xFF44FF44).withValues(alpha: 0.5)),
                const SizedBox(height: 24),
                
                const Text(
                  'HAND-TRACKING VISUAL FEEDS REQUIRED TO BYPASS FIREWALL.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Palette.uiWhite,
                    fontFamily: 'monospace',
                    fontSize: 16,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'THIS PROTOCOL REQUIRES WEBCAM ACCESS TO TRANSLATE PHYSICAL GESTURES INTO NETWORK COMMANDS. NO DATA LEAVES YOUR LOCAL TERMINAL.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF88AA88),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),

                if (_isRequesting && _errorMsg == null) ...[
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, child) => Text(
                      'ESTABLISHING CONNECTION...',
                      style: TextStyle(
                        color: const Color(0xFF44FF44).withValues(alpha: 0.5 + 0.5 * _pulseCtrl.value),
                        fontFamily: 'monospace',
                        fontSize: 14,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ],

                if (_errorMsg != null) ...[
                  const SizedBox(height: 32),
                  GlitchText(
                    text: _errorMsg!,
                    style: const TextStyle(
                      color: Palette.impactRed,
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    glitchIntensity: 0.8,
                  ),
                ],

                if (!_isRequesting && _errorMsg == null) ...[
                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _gestureWrap(
                        onTap: _handleAuthorize,
                        child: _AuthButton(
                          label: '[AUTHORIZE FEED]',
                          color: const Color(0xFF44FF44),
                          onTap: _handleAuthorize,
                          isPrimary: true,
                        ),
                      ),
                      const SizedBox(width: 24),
                      _gestureWrap(
                        onTap: _handleOverride,
                        child: _AuthButton(
                          label: '[MOUSE OVERRIDE]',
                          color: const Color(0xFF88AA88),
                          onTap: _handleOverride,
                          isPrimary: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Palette.bgDeep,
      body: ctrl != null
          ? AnimatedBuilder(
              animation: ctrl,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  (ctrl.faceX - 0.5) * ctrl.parallaxH,
                  (ctrl.faceY - 0.5) * ctrl.parallaxV,
                ),
                child: child,
              ),
              child: body,
            )
          : body,
    );
  }
}

class _AuthButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _AuthButton({
    required this.label,
    required this.color,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.2)
                : widget.color.withValues(alpha: widget.isPrimary ? 0.05 : 0.02),
            border: Border.all(
              color: widget.color.withValues(alpha: _hovered ? 1.0 : 0.5),
              width: widget.isPrimary ? 2 : 1,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? Palette.uiWhite : widget.color,
              fontFamily: 'monospace',
              fontSize: widget.isPrimary ? 16 : 14,
              fontWeight: widget.isPrimary ? FontWeight.w900 : FontWeight.w500,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}
