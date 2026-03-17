import 'package:ebi_models/ebi_models.dart';
import 'package:ebi_core/src/network/api_client.dart';
import 'package:ebi_core/src/network/api_endpoints.dart';
import 'package:ebi_core/src/notifications/notification_repository.dart';

/// Real ABP backend implementation of [NotificationRepository].
class AbpNotificationRepository implements NotificationRepository {
  final ApiClient _apiClient;

  AbpNotificationRepository(this._apiClient);

  @override
  Future<List<NotificationItem>> getNotifications({
    NotificationType? filter,
  }) async {
    final queryParams = <String, dynamic>{
      'SkipCount': 0,
      'MaxResultCount': 50,
    };
    if (filter != null) {
      queryParams['Type'] = filter.name;
    }

    final response = await _apiClient.get(
      ApiEndpoints.notifications,
      queryParameters: queryParams,
    );

    final data = response.data;

    // ABP paged result: { totalCount, items }
    if (data is Map<String, dynamic> && data.containsKey('items')) {
      final items = data['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => _parseNotification(e as Map<String, dynamic>))
          .toList();
    }

    // Direct list response fallback.
    if (data is List) {
      return data
          .map((e) => _parseNotification(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  @override
  Future<void> markAsRead(String id) async {
    await _apiClient.put(
      '${ApiEndpoints.notifications}/$id/read',
    );
  }

  @override
  Future<void> markAllAsRead() async {
    await _apiClient.post(ApiEndpoints.notificationMarkAllRead);
  }

  @override
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.notifications,
        queryParameters: {
          'IsRead': false,
          'MaxResultCount': 0,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['totalCount'] as int? ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  void dispose() {
    // No resources to clean up for REST-based repository.
    // SignalR connection cleanup would go here in future.
  }

  /// Parse ABP notification format to our model.
  NotificationItem _parseNotification(Map<String, dynamic> json) {
    // Try standard ABP notification fields.
    final id = (json['id'] ?? json['notificationId'] ?? '').toString();
    final title = json['title'] as String? ??
        json['notificationName'] as String? ??
        '';
    final body = json['body'] as String? ??
        json['data']?.toString() ??
        '';

    // Map notification type.
    final typeStr = json['type'] as String? ??
        json['notificationType'] as String? ??
        'system';
    final type = NotificationType.values.firstWhere(
      (e) => e.name == typeStr.toLowerCase(),
      orElse: () => NotificationType.system,
    );

    final isRead = json['isRead'] as bool? ??
        json['is_read'] as bool? ??
        (json['state'] == 1);

    final referenceId = json['referenceId'] as String? ??
        json['reference_id'] as String?;

    DateTime createdAt;
    try {
      createdAt = DateTime.parse(
        json['creationTime'] as String? ??
            json['created_at'] as String? ??
            json['createdAt'] as String? ??
            DateTime.now().toIso8601String(),
      );
    } catch (_) {
      createdAt = DateTime.now();
    }

    return NotificationItem(
      id: id,
      title: title,
      body: body,
      type: type,
      isRead: isRead,
      referenceId: referenceId,
      createdAt: createdAt,
    );
  }
}
