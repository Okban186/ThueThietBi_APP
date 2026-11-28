import 'package:thuethietbi_app/core/network/api_client.dart';

import '../models/notification.dart';

class NotificationListResult {
  const NotificationListResult({
    required this.unreadCount,
    required this.items,
  });

  final int unreadCount;
  final List<Notification> items;
}

class NotificationApi {
  NotificationApi(this._apiClient);

  final ApiClient _apiClient;

  Future<NotificationListResult> getNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final res = await _apiClient.get<Map<String, dynamic>>(
      '/api/notifications',
      queryParameters: {
        'limit': limit,
        if (unreadOnly) 'unreadOnly': true,
      },
    );
    final data = res.data ?? const <String, dynamic>{};
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((e) => Notification.fromJson(e as Map<String, dynamic>))
        .toList();
    final unreadCount =
        (data['unreadCount'] as num?)?.toInt() ??
        items.where((i) => !i.isRead).length;
    return NotificationListResult(unreadCount: unreadCount, items: items);
  }

  Future<int> getUnreadCount() async {
    final res = await _apiClient.get<Map<String, dynamic>>(
      '/api/notifications/unread-count',
    );
    return (res.data?['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<void> markAsRead(String id) async {
    await _apiClient.post<void>('/api/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _apiClient.post<dynamic>('/api/notifications/read-all');
  }

  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
    String? deviceId,
  }) async {
    await _apiClient.post<void>(
      '/api/notifications/devices',
      data: {
        'fcmToken': fcmToken,
        'platform': platform,
        if (deviceId != null && deviceId.trim().isNotEmpty)
          'deviceId': deviceId.trim(),
      },
    );
  }

  Future<void> unregisterDevice(String fcmToken) async {
    await _apiClient.post<void>(
      '/api/notifications/devices/unregister',
      data: {'fcmToken': fcmToken},
    );
  }

  Future<void> sendTestNotification() async {
    await _apiClient.post<dynamic>('/api/notifications/test', data: const {});
  }
}
