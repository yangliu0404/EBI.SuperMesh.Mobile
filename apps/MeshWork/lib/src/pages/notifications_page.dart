import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_models/ebi_models.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// MeshWork notification list page (titled "Alerts").
class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  NotificationType? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: EbiAppBar(
        title: 'Alerts',
        showBack: false,
        actions: [
          TextButton(
            onPressed: () {
              ref.read(notificationsProvider.notifier).markAllAsRead();
            },
            child: const Text(
              'Mark All Read',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(
            selected: _selectedFilter,
            onSelected: (type) {
              setState(() => _selectedFilter = type);
              ref.read(notificationsProvider.notifier).filterBy(type);
            },
          ),
          Expanded(
            child: notifState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (notifications) {
                if (notifications.isEmpty) {
                  return const EbiEmptyState(
                    icon: Icons.notifications_outlined,
                    title: 'All Caught Up',
                    subtitle: 'No notifications match this filter.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(notificationsProvider.notifier).refresh(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) => _NotificationTile(
                      item: notifications[index],
                      onTap: () => _onNotificationTap(notifications[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onNotificationTap(NotificationItem item) {
    if (!item.isRead) {
      ref.read(notificationsProvider.notifier).markAsRead(item.id);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Navigation coming in Phase 1'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets (private to this file)
// ---------------------------------------------------------------------------

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final NotificationType? selected;
  final ValueChanged<NotificationType?> onSelected;

  static const _filters = <NotificationType?, String>{
    null: 'All',
    NotificationType.order: 'Orders',
    NotificationType.shipping: 'Shipping',
    NotificationType.production: 'QC',
    NotificationType.approval: 'Approval',
    NotificationType.quotation: 'Quotation',
    NotificationType.system: 'System',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: _filters.entries.map((entry) {
            final isSelected = entry.key == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (_) => onSelected(entry.key),
                selectedColor: const Color(0xFF009FE3).withValues(alpha: 0.15),
                checkmarkColor: const Color(0xFF009FE3),
                labelStyle: TextStyle(
                  color: isSelected
                      ? const Color(0xFF009FE3)
                      : Colors.grey.shade700,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: _colorFor(item.type).withValues(alpha: 0.15),
        child: Icon(_iconFor(item.type), color: _colorFor(item.type), size: 20),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: item.isRead ? FontWeight.normal : FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        item.body,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _timeAgo(item.createdAt),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          if (!item.isRead) ...[
            const SizedBox(height: 4),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF009FE3),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(NotificationType type) {
    return switch (type) {
      NotificationType.order => Icons.receipt_long,
      NotificationType.quotation => Icons.request_quote,
      NotificationType.production => Icons.precision_manufacturing,
      NotificationType.shipping => Icons.local_shipping,
      NotificationType.approval => Icons.task_alt,
      NotificationType.chat => Icons.chat_bubble,
      NotificationType.system => Icons.info,
    };
  }

  static Color _colorFor(NotificationType type) {
    return switch (type) {
      NotificationType.order => const Color(0xFFF59E0B),
      NotificationType.quotation => const Color(0xFF8B5CF6),
      NotificationType.production => const Color(0xFF14B8A6),
      NotificationType.shipping => const Color(0xFF3B82F6),
      NotificationType.approval => const Color(0xFF22C55E),
      NotificationType.chat => const Color(0xFF009FE3),
      NotificationType.system => const Color(0xFF6B7280),
    };
  }

  static String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
