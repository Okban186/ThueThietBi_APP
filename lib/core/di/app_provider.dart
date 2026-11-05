import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:thuethietbi_app/core/config/app_config.dart';

import '../../features/auth/data/datasources/auth_api.dart';
import '../../features/notifications/data/providers/notification_provider.dart';
import '../auth/auth_session.dart';
import '../network/api_client.dart';
import '../notification/notification_service.dart';
import '../storage/secure_storage.dart';

Future<List<SingleChildWidget>> createAppProviders() async {
  // Khởi tạo nơi lưu token.
  final secureStorage = SecureStorage();

  // Khởi tạo trạng thái đăng nhập.
  final authSession = AuthSession(secureStorage: secureStorage);

  // Khôi phục token đã lưu trước đó.
  await authSession.restoreTokens();

  // Khởi tạo HTTP client.
  final apiClient = ApiClient(
    baseUrl: AppConfig.baseUrl,
    tokenStorage: authSession,
  );

  // Khởi tạo API.
  final authApi = AuthApi(apiClient);

  // Khởi tạo quản lý thông báo.
  final notificationProvider = NotificationProvider();

  // Khởi tạo dịch vụ Firebase Notification.
  final notificationService = NotificationService(notificationProvider);

  return [
    ChangeNotifierProvider<AuthSession>.value(value: authSession),

    Provider<ApiClient>.value(value: apiClient),

    Provider<AuthApi>.value(value: authApi),

    ChangeNotifierProvider<NotificationProvider>.value(
      value: notificationProvider,
    ),

    Provider<NotificationService>.value(value: notificationService),
  ];
}
