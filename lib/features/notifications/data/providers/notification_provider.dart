import 'package:flutter/material.dart' hide Notification;
import 'package:thuethietbi_app/core/network/api_error_message.dart';

import '../datasources/notification_api.dart';
import '../models/notification.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._api);

  final NotificationApi _api;

  final List<Notification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<Notification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _unreadCount;

  bool get hasUnread => _unreadCount > 0;

  bool get isLoading => _isLoading;

  String? get error => _error;

  Future<void> loadNotifications({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await _api.getNotifications(limit: 80);
      _notifications
        ..clear()
        ..addAll(result.items);
      _unreadCount = result.unreadCount;
      _error = null;
    } catch (e) {
      if (!silent) {
        _error = apiErrorMessage(
          e,
          fallback: 'Không tải được danh sách thông báo.',
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _api.getUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  void addNotification(Notification notification) {
    final existingIdx = _notifications.indexWhere(
      (item) => item.id == notification.id,
    );
    if (existingIdx != -1) {
      return;
    }

    _notifications.insert(0, notification);
    if (!notification.isRead) {
      _unreadCount++;
    }
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1 || _notifications[index].isRead) {
      return;
    }

    _notifications[index] = _notifications[index].copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
    if (_unreadCount > 0) _unreadCount--;
    notifyListeners();

    try {
      await _api.markAsRead(id);
    } catch (_) {
      // Giữ trạng thái cục bộ để không giật UI, lần tải sau sẽ đồng bộ lại.
    }
  }

  Future<void> markAllAsRead() async {
    if (!hasUnread) return;

    final now = DateTime.now();
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(
          isRead: true,
          readAt: now,
        );
      }
    }
    _unreadCount = 0;
    notifyListeners();

    try {
      await _api.markAllAsRead();
    } catch (_) {}
  }

  Future<void> sendTestNotification() async {
    await _api.sendTestNotification();
    await loadNotifications(silent: true);
  }

  void clearNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
