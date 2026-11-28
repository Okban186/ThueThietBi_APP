import 'package:flutter/material.dart' hide Notification;
import 'package:provider/provider.dart';
import 'package:thuethietbi_app/core/theme/app_colors.dart';

import '../../../data/providers/notification_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationProvider>().loadNotifications(
          silent: context.read<NotificationProvider>().notifications.isNotEmpty,
        );
      }
    });
  }

  (IconData, Color) _iconForType(String? type) {
    final upper = (type ?? '').toUpperCase();
    if (upper.contains('PAYMENT') || upper.contains('DEPOSIT') || upper.contains('SETTLE')) {
      return (Icons.payments_outlined, AppColors.success);
    }
    if (upper.contains('INCIDENT') || upper.contains('PENALTY') || upper.contains('DAMAGED')) {
      return (Icons.warning_amber_rounded, AppColors.error);
    }
    if (upper.contains('RETRIEVAL') || upper.contains('DELIVERY') || upper.contains('HANDOVER')) {
      return (Icons.local_shipping_outlined, AppColors.info);
    }
    if (upper.contains('MAINTENANCE')) {
      return (Icons.build_circle_outlined, AppColors.warning);
    }
    if (upper.contains('CONTRACT')) {
      return (Icons.description_outlined, AppColors.primary);
    }
    return (Icons.notifications_outlined, AppColors.primary);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, child) {
              return TextButton(
                onPressed: provider.hasUnread ? provider.markAllAsRead : null,
                child: const Text('Đọc tất cả'),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, child) {
          final notifications = provider.notifications;

          if (provider.isLoading && notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 56,
                      color: theme.disabledColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => provider.loadNotifications(),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => provider.loadNotifications(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 64,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bạn chưa có thông báo nào',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadNotifications(silent: true),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final (icon, iconColor) = _iconForType(notification.type);

                return Material(
                  color: notification.isRead
                      ? theme.colorScheme.surface
                      : theme.colorScheme.primary.withValues(alpha: 0.06),
                  child: InkWell(
                    onTap: () {
                      provider.markAsRead(notification.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: iconColor.withValues(alpha: 0.12),
                            child: Icon(icon, color: iconColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: notification.isRead
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.content,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                if (notification.createdAt != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatDate(notification.createdAt!),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!notification.isRead)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 5),
                              child: Icon(
                                Icons.circle,
                                size: 9,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final date = dateTime.toLocal();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year lúc $hour:$minute';
  }
}
