import 'package:flutter/material.dart';
import 'api_client.dart';
import '../models/notification.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final resp = await ApiClient.instance.getNotifications();
      if (resp['success'] == true) {
        final List data = resp['data']['notifications'];
        _notifications = data.map((n) => NotificationModel.fromJson(n)).toList();
        _unreadCount = resp['data']['unread_count'] ?? 0;
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final resp = await ApiClient.instance.markAllNotificationsRead();
      if (resp['success'] == true) {
        _unreadCount = 0;
        _notifications = _notifications.map((n) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            type: n.type,
            title: n.title,
            body: n.body,
            isRead: true,
            linkId: n.linkId,
            createdAt: n.createdAt,
          );
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking all read: $e');
    }
  }

  void reset() {
    _notifications = [];
    _unreadCount = 0;
    notifyListeners();
  }
}
