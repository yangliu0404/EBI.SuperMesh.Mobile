/// Notification types.
enum NotificationType {
  order,
  quotation,
  production,
  shipping,
  approval,
  chat,
  system,
}

/// Represents a notification / message item.
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final String? referenceId;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    this.referenceId,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      isRead: json['is_read'] as bool? ?? false,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'is_read': isRead,
        'reference_id': referenceId,
        'created_at': createdAt.toIso8601String(),
      };
}
