import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notifications/data/models/notification.dart';
import '../../features/notifications/data/providers/notification_provider.dart';
import '../../features/notifications/presentation/common/screens/notification_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  NotificationService(this._notificationProvider);

  final NotificationProvider _notificationProvider;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'equiprent_notifications',
    'Thông báo EquipRent',
    description: 'Thông báo từ hệ thống EquipRent',
    importance: Importance.max,
  );

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Xin quyền nhận thông báo.
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Khởi tạo local notification.
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _openNotificationScreen();
      },
    );

    // Tạo notification channel trên Android.
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_channel);

    // Lấy FCM token của thiết bị.
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');

    // Theo dõi token thay đổi.
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token updated: $newToken');
    });

    // Nhận thông báo khi ứng dụng đang mở.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Người dùng nhấn thông báo khi app đang chạy nền.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _addNotification(message);
      _openNotificationScreen();
    });

    // Người dùng nhấn thông báo để mở app từ trạng thái đã đóng.
    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      _addNotification(initialMessage);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openNotificationScreen();
      });
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _addNotification(message);

    final notification = message.notification;

    if (notification == null) return;

    // FCM không tự hiển thị notification khi app đang foreground.
    await _localNotifications.show(
      id: message.messageId.hashCode,
      title: notification.title ?? 'Thông báo EquipRent',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  void _addNotification(RemoteMessage message) {
    final notification = message.notification;

    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Thông báo EquipRent';

    final body = notification?.body ?? message.data['body']?.toString() ?? '';

    final id =
        message.data['notificationId']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final userId = message.data['userId']?.toString() ?? '';

    _notificationProvider.addNotification(
      Notification(
        id: id,
        userId: userId,
        title: title,
        content: body,
        createdAt: message.sentTime ?? DateTime.now(),
        isRead: false,
      ),
    );
  }

  void _openNotificationScreen() {
    final navigator = appNavigatorKey.currentState;

    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(builder: (_) => const NotificationScreen()),
    );
  }
}
