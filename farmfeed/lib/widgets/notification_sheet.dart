import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/notification_provider.dart';
import '../../models/notification.dart';
import 'package:intl/intl.dart';

class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Notifications', style: FarmTextStyles.titleLarge),
                if (provider.unreadCount > 0)
                  TextButton(
                    onPressed: () => provider.markAllAsRead(),
                    child: const Text('Mark all read'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: notifications.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return _NotificationTile(notification: notif);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: FarmTextStyles.titleMedium.copyWith(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'No new notifications for you.',
            style: FarmTextStyles.bodySmall.copyWith(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case 'message':
        iconData = Icons.chat_bubble_outline;
        iconColor = FarmColors.primaryGreen;
        break;
      case 'order_update':
        iconData = Icons.shopping_bag_outlined;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.notifications_none;
        iconColor = Colors.blue;
    }

    return Container(
      color: notification.isRead ? null : Colors.green.withOpacity(0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      notification.title,
                      style: FarmTextStyles.titleMedium.copyWith(
                        fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                    Text(
                      DateFormat.jm().format(notification.createdAt),
                      style: FarmTextStyles.bodySmall.copyWith(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: FarmTextStyles.bodySmall.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
