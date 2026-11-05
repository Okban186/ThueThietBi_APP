import 'package:flutter/material.dart' hide Notification;

import "../models/notification.dart";

class NotificationProvider extends ChangeNotifier {
  final List<Notification> _notifications = [];

  List<Notification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((item) => !item.isRead).length;

  bool get hasUnread => unreadCount > 0;

  void addNotification(Notification notification) {
    // Không thêm trùng thông báo.
    if (_notifications.any((item) => item.id == notification.id)) {
      return;
    }

    _notifications.insert(0, notification);
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((item) => item.id == id);

    if (index == -1 || _notifications[index].isRead) {
      return;
    }

    _notifications[index] = _notifications[index].copyWith(isRead: true);

    notifyListeners();
  }

  void markAllAsRead() {
    if (!hasUnread) return;

    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }

    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }
}
