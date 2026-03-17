import 'package:ebi_models/ebi_models.dart';

import 'notification_repository.dart';

/// Mock implementation of [NotificationRepository] with realistic supply-chain
/// notifications for early development.
class MockNotificationRepository implements NotificationRepository {
  late List<NotificationItem> _notifications;

  MockNotificationRepository() {
    final now = DateTime.now();
    _notifications = [
      NotificationItem(
        id: 'notif-001',
        title: 'Shipment ETD Updated',
        body:
            'Container MSKU-2847561 for PO-2024-0089 has departed Ningbo port. ETA: Feb 25.',
        type: NotificationType.shipping,
        isRead: false,
        referenceId: 'SH-20240210',
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
      NotificationItem(
        id: 'notif-002',
        title: 'New Purchase Order',
        body:
            'PO-2024-0102 received from Delta Corp. 3,500 units of SKU-A100.',
        type: NotificationType.order,
        isRead: false,
        referenceId: 'PO-2024-0102',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      NotificationItem(
        id: 'notif-003',
        title: 'Approval Required',
        body:
            'Payment request #PR-0045 for \$12,800 submitted by Alice Wang awaits your approval.',
        type: NotificationType.approval,
        isRead: false,
        referenceId: 'PR-0045',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      NotificationItem(
        id: 'notif-004',
        title: 'Production Milestone',
        body:
            'Alpha Sample Review batch completed. 98.5% pass rate. Ready for final QC.',
        type: NotificationType.production,
        isRead: false,
        referenceId: 'PROD-0034',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      NotificationItem(
        id: 'notif-005',
        title: 'Quotation Approved',
        body:
            'BKR has approved quotation QT-2024-0067. Total value: \$45,200.',
        type: NotificationType.quotation,
        isRead: true,
        referenceId: 'QT-2024-0067',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      NotificationItem(
        id: 'notif-006',
        title: 'Customs Clearance Complete',
        body:
            'Shipment SH-20240215 cleared customs at Los Angeles port.',
        type: NotificationType.shipping,
        isRead: true,
        referenceId: 'SH-20240215',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      NotificationItem(
        id: 'notif-007',
        title: 'Order Status Changed',
        body:
            "PO-2024-0088 status changed from 'In Production' to 'QC Pending'.",
        type: NotificationType.order,
        isRead: true,
        referenceId: 'PO-2024-0088',
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
      NotificationItem(
        id: 'notif-008',
        title: 'System Maintenance',
        body:
            'Scheduled maintenance on Feb 15, 2:00-4:00 AM UTC. Services may be briefly unavailable.',
        type: NotificationType.system,
        isRead: true,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      NotificationItem(
        id: 'notif-009',
        title: 'QC Report Ready',
        body:
            'Inspection report for PO-2024-0076 has been uploaded. 2 minor defects noted.',
        type: NotificationType.production,
        isRead: true,
        referenceId: 'PO-2024-0076',
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
      ),
      NotificationItem(
        id: 'notif-010',
        title: 'Leave Request Approved',
        body:
            'Your leave request for Feb 20-22 has been approved by Manager.',
        type: NotificationType.approval,
        isRead: true,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      NotificationItem(
        id: 'notif-011',
        title: 'Quotation Revision Needed',
        body:
            'MTI requested revision on QT-2024-0071. Updated specs attached.',
        type: NotificationType.quotation,
        isRead: false,
        referenceId: 'QT-2024-0071',
        createdAt: now.subtract(const Duration(days: 2, hours: 6)),
      ),
      NotificationItem(
        id: 'notif-012',
        title: 'New Message in Project Chat',
        body:
            'Emma Zhang mentioned you in Alpha Sample Review group.',
        type: NotificationType.chat,
        isRead: true,
        referenceId: 'room-003',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  @override
  Future<List<NotificationItem>> getNotifications({
    NotificationType? filter,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (filter == null) return List.unmodifiable(_notifications);

    return List.unmodifiable(
      _notifications.where((n) => n.type == filter),
    );
  }

  @override
  Future<void> markAsRead(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    _notifications = _notifications.map((n) {
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
  }

  @override
  Future<void> markAllAsRead() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    _notifications = _notifications.map((n) {
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
  }

  @override
  Future<int> getUnreadCount() async {
    return _notifications.where((n) => !n.isRead).length;
  }

  @override
  void dispose() {
    // No resources to clean up in mock.
  }
}
