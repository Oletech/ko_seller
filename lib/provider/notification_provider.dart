import 'package:flutter/material.dart';

import '../model/app_notification.dart';
import '../services/local_storage_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({required LocalStorageService storage})
      : _storage = storage {
    _loadNotifications();
  }

  final LocalStorageService _storage;
  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount =>
      _notifications.where((notification) => !notification.read).length;

  void _loadNotifications() {
    final stored = _storage.readNotifications();
    _notifications
      ..clear()
      ..addAll(stored);
    if (_notifications.isEmpty) {
      _notifications.addAll(_seed());
      _persist();
    }
    notifyListeners();
  }

  List<AppNotification> _seed() {
    return [
      AppNotification.systemMessage(
        'Karibu Kariakoo Online!',
        'Set up your store profile and publish your first product.',
      ),
      AppNotification(
        id: 'order-intro',
        type: NotificationType.order,
        title: 'New order ready for confirmation',
        message: 'Alice funded escrow for the Grocery Combo order.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }

  Future<void> push(AppNotification notification) async {
    _notifications.insert(0, notification);
    await _persist();
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    final index =
        _notifications.indexWhere((element) => element.id == notificationId);
    if (index == -1) return;
    _notifications[index] = _notifications[index].copyWith(read: true);
    await _persist();
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].read) {
        _notifications[i] = _notifications[i].copyWith(read: true);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String notificationId) async {
    _notifications.removeWhere((element) => element.id == notificationId);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage.saveNotifications(_notifications);
  }
}
