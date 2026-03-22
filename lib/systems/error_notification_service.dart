import 'dart:async';
import 'package:flutter/foundation.dart';

/// Severity level for error notifications
enum ErrorSeverity {
  info, // Blue - informational messages
  warning, // Yellow - non-critical issues
  error, // Red - errors that affect functionality
}

/// Represents an error notification to display to the user
class ErrorNotification {
  final String title;
  final String message;
  final ErrorSeverity severity;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final DateTime timestamp;

  ErrorNotification({
    required this.title,
    required this.message,
    this.severity = ErrorSeverity.error,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(seconds: 5),
  }) : timestamp = DateTime.now();
}

/// Service for managing user-facing error notifications.
///
/// Provides a centralized way to report errors to users instead of
/// silently failing. Supports different severity levels and optional
/// retry actions.
class ErrorNotificationService extends ChangeNotifier {
  static final ErrorNotificationService _instance =
      ErrorNotificationService._();
  static ErrorNotificationService get instance => _instance;

  ErrorNotificationService._();

  final List<ErrorNotification> _notifications = [];
  final StreamController<ErrorNotification> _notificationController =
      StreamController<ErrorNotification>.broadcast();

  /// Stream of new notifications for UI listeners
  Stream<ErrorNotification> get onNotification =>
      _notificationController.stream;

  /// Current notifications (for displaying multiple in a stack)
  List<ErrorNotification> get notifications =>
      List.unmodifiable(_notifications);

  /// Report an error to the user
  void reportError({
    required String title,
    required String message,
    ErrorSeverity severity = ErrorSeverity.error,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    final notification = ErrorNotification(
      title: title,
      message: message,
      severity: severity,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );

    _notifications.add(notification);
    _notificationController.add(notification);
    notifyListeners();

    // Auto-dismiss after duration
    Future.delayed(duration, () {
      dismiss(notification);
    });

    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('[${severity.name.toUpperCase()}] $title: $message');
    }
  }

  /// Report an info message
  void info(String title, String message, {Duration? duration}) {
    reportError(
      title: title,
      message: message,
      severity: ErrorSeverity.info,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Report a warning
  void warning(
    String title,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    reportError(
      title: title,
      message: message,
      severity: ErrorSeverity.warning,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Report an error
  void error(
    String title,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    reportError(
      title: title,
      message: message,
      severity: ErrorSeverity.error,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: const Duration(seconds: 8),
    );
  }

  /// Dismiss a specific notification
  void dismiss(ErrorNotification notification) {
    if (_notifications.remove(notification)) {
      notifyListeners();
    }
  }

  /// Dismiss all notifications
  void dismissAll() {
    _notifications.clear();
    notifyListeners();
  }

  /// Clean up
  @override
  void dispose() {
    _notificationController.close();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Common Error Helpers - Pre-defined messages for consistent UX
  // ══════════════════════════════════════════════════════════════════════════

  /// Audio system failed to initialize
  void audioInitFailed({VoidCallback? onRetry}) {
    reportError(
      title: 'Audio Unavailable',
      message:
          'Sound effects could not be loaded. The game will continue without audio.',
      severity: ErrorSeverity.warning,
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }

  /// Webcam/hand tracking unavailable
  void handTrackingUnavailable({VoidCallback? onRetry}) {
    reportError(
      title: 'Hand Tracking Unavailable',
      message:
          'Camera access denied or unavailable. Using mouse controls instead.',
      severity: ErrorSeverity.warning,
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }

  /// Hand tracking lost connection
  void handTrackingLost() {
    reportError(
      title: 'Tracking Lost',
      message: 'Hand tracking temporarily lost. Move your hand back into view.',
      severity: ErrorSeverity.info,
      duration: const Duration(seconds: 3),
    );
  }

  /// Save failed
  void saveFailed({VoidCallback? onRetry}) {
    reportError(
      title: 'Save Failed',
      message: 'Your progress could not be saved. Please try again.',
      severity: ErrorSeverity.error,
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }

  /// Load failed
  void loadFailed({VoidCallback? onRetry}) {
    reportError(
      title: 'Load Failed',
      message: 'Your saved progress could not be loaded. Starting fresh.',
      severity: ErrorSeverity.warning,
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }

  /// Network error
  void networkError(String context, {VoidCallback? onRetry}) {
    reportError(
      title: 'Connection Error',
      message: 'Failed to connect: $context',
      severity: ErrorSeverity.error,
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }
}
