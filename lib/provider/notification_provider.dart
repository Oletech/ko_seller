import 'package:flutter/material.dart';

import '../model/app_notification.dart';
import '../services/local_storage_service.dart';
import '../services/push_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    required LocalStorageService storage,
    required PushNotificationService pushNotificationService,
  })  : _storage = storage,
        _pushNotificationService = pushNotificationService {
    _loadNotifications();
    _initializePushNotifications();
  }

  final LocalStorageService _storage;
  final PushNotificationService _pushNotificationService;
  final List<AppNotification> _notifications = [];
  AppNotification? _pendingNavigation;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount =>
      _notifications.where((notification) => !notification.read).length;
  AppNotification? get pendingNavigation => _pendingNavigation;

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
    if (_notifications.any((element) => element.id == notification.id)) {
      return;
    }
    _notifications.insert(0, notification);
    await _persist();
    notifyListeners();
  }

  Future<void> _initializePushNotifications() async {
    await _pushNotificationService.initialize(
      onNotification: push,
      onNotificationOpened: openNotification,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final index =
        _notifications.indexWhere((element) => element.id == notificationId);
    if (index == -1) return;
    _notifications[index] = _notifications[index].copyWith(read: true);
    await _persist();
    notifyListeners();
  }

  Future<void> openNotification(AppNotification notification) async {
    _pendingNavigation = notification;
    final index =
        _notifications.indexWhere((element) => element.id == notification.id);
    if (index != -1 && !_notifications[index].read) {
      _notifications[index] = _notifications[index].copyWith(read: true);
      await _persist();
    }
    notifyListeners();
  }

  AppNotification? consumePendingNavigation() {
    final pending = _pendingNavigation;
    _pendingNavigation = null;
    return pending;
  }

  bool hasUnreadForOrder({
    required String orderId,
    required String orderDocumentId,
  }) {
    return _notifications.any(
      (notification) =>
          !notification.read &&
          ((orderId.isNotEmpty && notification.orderId == orderId) ||
              (orderDocumentId.isNotEmpty &&
                  notification.orderDocumentId == orderDocumentId)),
    );
  }

  Future<void> markOrderNotificationsAsRead({
    required String orderId,
    required String orderDocumentId,
  }) async {
    var changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      final matchesOrder =
          (orderId.isNotEmpty && _notifications[i].orderId == orderId) ||
              (orderDocumentId.isNotEmpty &&
                  _notifications[i].orderDocumentId == orderDocumentId);
      if (matchesOrder && !_notifications[i].read) {
        _notifications[i] = _notifications[i].copyWith(read: true);
        changed = true;
      }
    }
    if (!changed) return;
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
