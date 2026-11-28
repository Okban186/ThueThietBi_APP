import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../auth/auth_session.dart';
import '../../features/notifications/data/datasources/notification_api.dart';
import '../../features/notifications/data/models/notification.dart';
import '../../features/notifications/data/providers/notification_provider.dart';
import '../../features/notifications/presentation/common/screens/notification_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  NotificationService(
    this._notificationProvider,
    this._notificationApi,
    this._authSession,
  );

  final NotificationProvider _notificationProvider;
  final NotificationApi _notificationApi;
  final AuthSession _authSession;

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
  String? _currentToken;
  String? _lastSyncedUserId;

  String get _platformCode {
    if (kIsWeb) return 'WEB';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'IOS',
      TargetPlatform.android => 'ANDROID',
      _ => 'OTHER',
    };
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Lắng nghe thay đổi phiên đăng nhập để tự động đăng ký FCM token & tải danh sách thông báo.
    _authSession.addListener(_onAuthChanged);

    if (!kIsWeb) {
      // Xin quyền nhận thông báo (Android 13+ / iOS).
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Khởi tạo local notification để hiển thị pop-up khi app đang mở foreground.
      const initializationSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (_) {
          _openNotificationScreen();
        },
      );

      // Tạo notification channel trên Android (khớp ChannelId trên Backend).
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_channel);

      // Lấy FCM token của thiết bị.
      try {
        _currentToken = await _messaging.getToken();
        debugPrint('FCM Token: $_currentToken');
      } catch (e) {
        debugPrint('Không lấy được FCM Token: $e');
      }

      // Theo dõi token thay đổi và tự đồng bộ lên Backend.
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token updated: $newToken');
        _currentToken = newToken;
        _registerTokenIfAuthenticated(newToken);
      });

      // Nhận thông báo khi ứng dụng đang mở.
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Người dùng nhấn thông báo khi app đang chạy nền.
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _addNotification(message);
        _notificationProvider.loadNotifications(silent: true);
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

    // Nếu phiên đăng nhập đã khôi phục sẵn khi mở app -> đồng bộ ngay.
    _onAuthChanged();
  }

  void _onAuthChanged() {
    final user = _authSession.currentUser;
    if (user != null && _authSession.isAuthenticated) {
      if (_lastSyncedUserId != user.id) {
        _lastSyncedUserId = user.id;
        syncForCurrentUser();
      }
    } else if (_lastSyncedUserId != null) {
      _lastSyncedUserId = null;
      _notificationProvider.clearNotifications();
    }
  }

  /// Đồng bộ FCM token lên Backend và tải danh sách thông báo từ DB cho người dùng hiện tại.
  Future<void> syncForCurrentUser() async {
    if (!_authSession.isAuthenticated) return;

    await _notificationProvider.loadNotifications(silent: true);

    if (kIsWeb) return;
    try {
      _currentToken ??= await _messaging.getToken();
      final token = _currentToken;
      if (token != null && token.isNotEmpty) {
        await _registerTokenIfAuthenticated(token);
      }
    } catch (e) {
      debugPrint('Lỗi đồng bộ FCM token: $e');
    }
  }

  Future<void> _registerTokenIfAuthenticated(String token) async {
    if (!_authSession.isAuthenticated || token.trim().isEmpty) return;
    try {
      await _notificationApi.registerDevice(
        fcmToken: token,
        platform: _platformCode,
      );
      debugPrint('Đã đăng ký FCM token lên Backend thành công.');
    } catch (e) {
      debugPrint('Không đăng ký được FCM token lên Backend: $e');
    }
  }

  /// Gỡ FCM token khỏi tài khoản hiện tại trước khi đăng xuất để tránh nhận nhầm thông báo của tài khoản cũ.
  Future<void> unregisterCurrentDevice() async {
    try {
      final token = _currentToken ?? (kIsWeb ? null : await _messaging.getToken());
      if (token != null && token.isNotEmpty && _authSession.isAuthenticated) {
        await _notificationApi.unregisterDevice(token);
      }
    } catch (_) {
      // Không chặn đăng xuất nếu mạng yếu.
    } finally {
      _lastSyncedUserId = null;
      _notificationProvider.clearNotifications();
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _addNotification(message);
    _notificationProvider.loadNotifications(silent: true);

    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Thông báo EquipRent';
    final body =
        notification?.body ?? message.data['body']?.toString() ?? '';

    if (title.isEmpty && body.isEmpty) return;

    // FCM không tự hiển thị banner khi app đang foreground -> dùng local notification.
    await _localNotifications.show(
      id: (message.messageId ?? DateTime.now().toIso8601String()).hashCode,
      title: title,
      body: body,
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
    final type = message.data['type']?.toString();

    _notificationProvider.addNotification(
      Notification(
        id: id,
        userId: userId,
        title: title,
        content: body,
        type: type,
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
