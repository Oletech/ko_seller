import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

import '../model/app_notification.dart';

typedef AppNotificationHandler = Future<void> Function(
  AppNotification notification,
);

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _escrowChannel =
      AndroidNotificationChannel(
    'seller_escrow_flow',
    'Seller escrow flow',
    description:
        'Order payment, escrow, delivery responsibility, and payout updates.',
    importance: Importance.high,
  );

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  bool _initialized = false;

  Future<void> initialize({
    required AppNotificationHandler onNotification,
    AppNotificationHandler? onNotificationOpened,
  }) async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final notification = _notificationFromData(data);
        await onNotification(notification);
        if (onNotificationOpened != null) {
          await onNotificationOpened(notification);
        }
      },
    );

    final androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.createNotificationChannel(_escrowChannel);

    await _requestPermission();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = _notificationFromMessage(message);
      await onNotification(notification);
      await showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final notification = _notificationFromMessage(message);
      await onNotification(notification);
      if (onNotificationOpened != null) {
        await onNotificationOpened(notification);
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final notification = _notificationFromMessage(initialMessage);
      await onNotification(notification);
      if (onNotificationOpened != null) {
        await onNotificationOpened(notification);
      }
    }
  }

  Future<String?> getToken() => _messaging.getToken();

  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  Future<void> deleteToken() => _messaging.deleteToken();

  Future<void> showLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title'] as String? ??
        'Seller update';
    final body = message.notification?.body ??
        message.data['body'] as String? ??
        message.data['message'] as String? ??
        'Open Kariakoo Seller for details.';
    final payload = jsonEncode(message.data);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _escrowChannel.id,
        _escrowChannel.name,
        channelDescription: _escrowChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.status,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> _requestPermission() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return;
    }

    final androidImplementation =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
  }

  AppNotification _notificationFromMessage(RemoteMessage message) {
    final title = message.notification?.title ??
        message.data['title'] as String? ??
        'Seller update';
    final body = message.notification?.body ??
        message.data['body'] as String? ??
        message.data['message'] as String? ??
        'Open Kariakoo Seller for details.';
    return _notificationFromData({
      ...message.data,
      'id': message.messageId,
      'title': title,
      'message': body,
    });
  }

  AppNotification _notificationFromData(Map<String, dynamic> data) {
    return AppNotification(
      id: '${data['id'] ?? data['notificationId'] ?? const Uuid().v4()}',
      type: NotificationTypeParser.fromString('${data['type'] ?? ''}'),
      title: '${data['title'] ?? 'Seller update'}',
      message:
          '${data['message'] ?? data['body'] ?? 'Open Kariakoo Seller for details.'}',
      createdAt:
          DateTime.tryParse('${data['createdAt'] ?? ''}') ?? DateTime.now(),
      orderId: '${data['orderId'] ?? ''}',
      orderDocumentId: '${data['orderDocumentId'] ?? ''}',
      targetTab: _resolveTargetTab(data),
      action: '${data['action'] ?? data['event'] ?? ''}',
    );
  }

  int? _resolveTargetTab(Map<String, dynamic> data) {
    final rawTab = data['targetTab'] ?? data['tab'];
    if (rawTab is int) return rawTab;

    final normalizedTab = '$rawTab'.trim().toLowerCase();
    switch (normalizedTab) {
      case '0':
      case 'home':
        return 0;
      case '1':
      case 'order':
      case 'orders':
        return 1;
      case '2':
      case 'shipping':
      case 'delivery':
        return 2;
      case '3':
      case 'account':
      case 'settings':
        return 3;
    }

    final status =
        '${data['status'] ?? data['orderStatus'] ?? ''}'.trim().toLowerCase();
    final action =
        '${data['action'] ?? data['event'] ?? ''}'.trim().toLowerCase();

    if (status == 'outfordelivery' ||
        status == 'delivered' ||
        status == 'preparingshipment' ||
        status == 'escrowfunded' ||
        action.contains('shipping') ||
        action.contains('delivery')) {
      return 2;
    }

    if ('${data['orderId'] ?? data['orderDocumentId'] ?? ''}'
        .trim()
        .isNotEmpty) {
      return 1;
    }

    return null;
  }
}
