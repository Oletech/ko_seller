import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

enum NotificationType { order, payment, review, report, system }

class AppNotification extends Equatable {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.read = false,
  });

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? read,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? const Uuid().v4(),
      type: NotificationType.values.firstWhere(
        (element) => element.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
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
  List<Object?> get props => [id, type, title, message, createdAt, read];
}
