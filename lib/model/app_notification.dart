import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum NotificationType { order, payment, review, report, system }

extension NotificationTypeParser on NotificationType {
  static NotificationType fromString(String? raw) {
    return NotificationType.values.firstWhere(
      (element) => element.name == raw,
      orElse: () => NotificationType.system,
    );
  }
}

class AppNotification extends Equatable {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final String orderId;
  final String orderDocumentId;
  final int? targetTab;
  final String action;
  final bool read;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.orderId = '',
    this.orderDocumentId = '',
    this.targetTab,
    this.action = '',
    this.read = false,
  });

  bool get hasNavigationTarget =>
      targetTab != null || orderId.isNotEmpty || orderDocumentId.isNotEmpty;

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    String? orderId,
    String? orderDocumentId,
    int? targetTab,
    String? action,
    bool? read,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
      orderDocumentId: orderDocumentId ?? this.orderDocumentId,
      targetTab: targetTab ?? this.targetTab,
      action: action ?? this.action,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'orderId': orderId,
        'orderDocumentId': orderDocumentId,
        'targetTab': targetTab,
        'action': action,
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? const Uuid().v4(),
      type: NotificationTypeParser.fromString(json['type'] as String?),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      orderId: json['orderId'] as String? ?? '',
      orderDocumentId: json['orderDocumentId'] as String? ?? '',
      targetTab: json['targetTab'] as int?,
      action: json['action'] as String? ?? '',
      read: json['read'] as bool? ?? false,
    );
  }

  static AppNotification systemMessage(String title, String message) {
    return AppNotification(
      id: const Uuid().v4(),
      type: NotificationType.system,
      title: title,
      message: message,
      createdAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        message,
        createdAt,
        orderId,
        orderDocumentId,
        targetTab,
        action,
        read,
      ];
}
