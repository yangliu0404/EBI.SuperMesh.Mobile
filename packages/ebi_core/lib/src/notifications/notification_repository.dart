import 'package:ebi_models/ebi_models.dart';

/// Abstract interface for notification data access.
abstract class NotificationRepository {
  Future<List<NotificationItem>> getNotifications({
    NotificationType? filter,
  });

  Future<void> markAsRead(String id);

  Future<void> markAllAsRead();

  Future<int> getUnreadCount();

  void dispose();
}
