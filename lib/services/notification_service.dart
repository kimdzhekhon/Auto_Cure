import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../models/error_report.dart';
import '../models/fix_record.dart';

/// In-app notification types.
enum NotificationType { info, success, warning, error }

/// A single notification entry.
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool read;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.read = false,
    this.data,
  });

  AppNotification markAsRead() => AppNotification(
        id: id,
        title: title,
        message: message,
        type: type,
        timestamp: timestamp,
        read: true,
        data: data,
      );

  IconData get icon => switch (type) {
        NotificationType.info => Icons.info_outline,
        NotificationType.success => Icons.check_circle_outline,
        NotificationType.warning => Icons.warning_amber_outlined,
        NotificationType.error => Icons.error_outline,
      };

  Color get color => switch (type) {
        NotificationType.info => Colors.blue,
        NotificationType.success => Colors.green,
        NotificationType.warning => Colors.orange,
        NotificationType.error => Colors.red,
      };
}

/// Manages in-app notifications triggered by agent events.
class NotificationService extends ChangeNotifier {
  final _log = Logger('NotificationService');
  final List<AppNotification> _notifications = [];
  final _controller = StreamController<AppNotification>.broadcast();
  int _idCounter = 0;

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);
  List<AppNotification> get unread =>
      _notifications.where((n) => !n.read).toList();
  int get unreadCount => unread.length;
  Stream<AppNotification> get stream => _controller.stream;

  /// Notify when a new error is detected.
  void onErrorDetected(ErrorReport error) {
    _add(
      title: 'Error Detected: ${error.errorType}',
      message: error.message,
      type: error.severity == ErrorSeverity.critical
          ? NotificationType.error
          : NotificationType.warning,
      data: {'errorId': error.id},
    );
  }

  /// Notify when a fix is successfully applied and verified.
  void onFixVerified(FixRecord fix) {
    _add(
      title: 'Fix Verified',
      message: '${fix.description}\n${fix.filePath}:${fix.lineNumber}',
      type: NotificationType.success,
      data: {'fixId': fix.id},
    );
  }

  /// Notify when a fix fails verification.
  void onFixFailed(FixRecord fix) {
    _add(
      title: 'Fix Failed',
      message: fix.failureReason ?? fix.description,
      type: NotificationType.error,
      data: {'fixId': fix.id},
    );
  }

  /// Notify when a PR is created.
  void onPRCreated(FixRecord fix) {
    _add(
      title: 'PR Created',
      message: fix.prUrl ?? fix.description,
      type: NotificationType.success,
      data: {'fixId': fix.id, 'prUrl': fix.prUrl},
    );
  }

  /// Notify when VM connection is lost.
  void onConnectionLost() {
    _add(
      title: 'VM Connection Lost',
      message: 'Agent lost connection to the Flutter VM service. Attempting to reconnect...',
      type: NotificationType.warning,
    );
  }

  /// Notify when VM connection is restored.
  void onConnectionRestored() {
    _add(
      title: 'VM Connection Restored',
      message: 'Successfully reconnected to the Flutter VM service.',
      type: NotificationType.info,
    );
  }

  /// Notify agent health check status.
  void onHealthCheckFailed(String reason) {
    _add(
      title: 'Health Check Failed',
      message: reason,
      type: NotificationType.error,
    );
  }

  void _add({
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) {
    final notification = AppNotification(
      id: '${++_idCounter}',
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      data: data,
    );
    _notifications.insert(0, notification);
    _controller.add(notification);
    notifyListeners();
    _log.info('[${type.name}] $title: $message');

    // Keep max 200 notifications
    if (_notifications.length > 200) {
      _notifications.removeRange(200, _notifications.length);
    }
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx] = _notifications[idx].markAsRead();
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].read) {
        _notifications[i] = _notifications[i].markAsRead();
      }
    }
    notifyListeners();
  }

  void clear() {
    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
