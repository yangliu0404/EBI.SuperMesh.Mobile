import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_models/ebi_models.dart';

import '../notifications/notification_repository.dart';
import '../notifications/abp_notification_repository.dart';
import 'core_providers.dart';

/// Notification repository provider — now uses AbpNotificationRepository.
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  final repo = AbpNotificationRepository(apiClient);
  ref.onDispose(repo.dispose);
  return repo;
});

/// Notification list state notifier provider.
final notificationsProvider = StateNotifierProvider<NotificationNotifier,
    AsyncValue<List<NotificationItem>>>((ref) {
  return NotificationNotifier(ref.read(notificationRepositoryProvider));
});

/// Derived unread count from the notification list.
final unreadCountProvider = Provider<int>((ref) {
  final state = ref.watch(notificationsProvider);
  return state.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

/// Manages notification list state including load, refresh, filter, and
/// read-status mutations.
class NotificationNotifier
    extends StateNotifier<AsyncValue<List<NotificationItem>>> {
  final NotificationRepository _repository;
  NotificationType? _currentFilter;

  NotificationNotifier(this._repository)
      : super(const AsyncValue.data([]));

  bool _initialized = false;

  NotificationType? get currentFilter => _currentFilter;

  /// Initialize notifications — call only after user is authenticated.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await load();
  }

  /// Load notifications with an optional type filter.
  Future<void> load({NotificationType? filter}) async {
    state = const AsyncValue.loading();
    try {
      _currentFilter = filter;
      final items = await _repository.getNotifications(filter: filter);
      if (mounted) state = AsyncValue.data(items);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Refresh without showing loading indicator (for pull-to-refresh).
  Future<void> refresh() async {
    try {
      final items =
          await _repository.getNotifications(filter: _currentFilter);
      if (mounted) state = AsyncValue.data(items);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String id) async {
    await _repository.markAsRead(id);
    // Optimistically update local state.
    state.whenData((list) {
      final updated = list.map((n) {
        if (n.id == id && !n.isRead) {
          return NotificationItem(
            id: n.id,
            title: n.title,
            body: n.body,
            type: n.type,
            isRead: true,
            referenceId: n.referenceId,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();
      if (mounted) state = AsyncValue.data(updated);
    });
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    state.whenData((list) {
      final updated = list.map((n) {
        if (!n.isRead) {
          return NotificationItem(
            id: n.id,
            title: n.title,
            body: n.body,
            type: n.type,
            isRead: true,
            referenceId: n.referenceId,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();
      if (mounted) state = AsyncValue.data(updated);
    });
  }

  /// Apply a type filter (null = show all).
  Future<void> filterBy(NotificationType? type) async {
    await load(filter: type);
  }
}
