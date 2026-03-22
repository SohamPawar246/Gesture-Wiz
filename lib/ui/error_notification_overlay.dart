import 'dart:async';
import 'package:flutter/material.dart';
import '../systems/error_notification_service.dart';
import '../game/palette.dart';

/// Overlay widget that displays error notifications to the user.
///
/// Place this at the top of your widget tree (usually in a Stack)
/// to show notifications over the game content.
class ErrorNotificationOverlay extends StatefulWidget {
  final Widget child;

  const ErrorNotificationOverlay({super.key, required this.child});

  @override
  State<ErrorNotificationOverlay> createState() =>
      _ErrorNotificationOverlayState();
}

class _ErrorNotificationOverlayState extends State<ErrorNotificationOverlay> {
  final List<ErrorNotification> _visibleNotifications = [];
  StreamSubscription<ErrorNotification>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ErrorNotificationService.instance.onNotification.listen((
      notification,
    ) {
      if (mounted) {
        setState(() {
          _visibleNotifications.add(notification);
        });

        // Schedule removal
        Future.delayed(notification.duration, () {
          if (mounted) {
            setState(() {
              _visibleNotifications.remove(notification);
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Notification stack in top-right corner
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _visibleNotifications.map((notification) {
              return _NotificationCard(
                notification: notification,
                onDismiss: () {
                  setState(() {
                    _visibleNotifications.remove(notification);
                  });
                  ErrorNotificationService.instance.dismiss(notification);
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final ErrorNotification notification;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    switch (widget.notification.severity) {
      case ErrorSeverity.info:
        return const Color(0xE0223344);
      case ErrorSeverity.warning:
        return const Color(0xE0443322);
      case ErrorSeverity.error:
        return const Color(0xE0442222);
    }
  }

  Color get _borderColor {
    switch (widget.notification.severity) {
      case ErrorSeverity.info:
        return Palette.uiMana;
      case ErrorSeverity.warning:
        return Palette.fireGold;
      case ErrorSeverity.error:
        return Palette.impactPink;
    }
  }

  IconData get _icon {
    switch (widget.notification.severity) {
      case ErrorSeverity.info:
        return Icons.info_outline;
      case ErrorSeverity.warning:
        return Icons.warning_amber_rounded;
      case ErrorSeverity.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_slideAnimation.value, 0),
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        );
      },
      child: Container(
        width: 320,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: _borderColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon, color: _borderColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.notification.title,
                        style: TextStyle(
                          color: _borderColor,
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.notification.message,
                        style: const TextStyle(
                          color: Palette.uiWhite,
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      if (widget.notification.actionLabel != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            widget.notification.onAction?.call();
                            widget.onDismiss();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: _borderColor),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              widget.notification.actionLabel!,
                              style: TextStyle(
                                color: _borderColor,
                                fontFamily: 'monospace',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.close, color: Palette.uiGrey, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
