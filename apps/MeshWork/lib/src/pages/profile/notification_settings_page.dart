import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_models/ebi_models.dart';

/// Notification preferences settings page.
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(settingsProvider).notificationPreferences;
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: EbiAppBar(title: ref.L('Notifications')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _sectionHeader(ref.L('General')),
          EbiCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(ref.L('PushNotifications')),
                  subtitle: Text(ref.L('ReceivePushNotifications')),
                  value: prefs.pushEnabled,
                  activeColor: EbiColors.primaryBlue,
                  onChanged: (v) => notifier.setPushEnabled(v),
                ),
                const Divider(height: 1, indent: 16),
                SwitchListTile(
                  title: Text(ref.L('EmailNotifications')),
                  subtitle: Text(ref.L('ReceiveEmailNotifications')),
                  value: prefs.emailEnabled,
                  activeColor: EbiColors.primaryBlue,
                  onChanged: (v) => notifier.setEmailEnabled(v),
                ),
                const Divider(height: 1, indent: 16),
                SwitchListTile(
                  title: Text(ref.L('Sound')),
                  subtitle: Text(ref.L('PlaySoundForNotifications')),
                  value: prefs.soundEnabled,
                  activeColor: EbiColors.primaryBlue,
                  onChanged: (v) => notifier.setSoundEnabled(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _sectionHeader(ref.L('NotificationTypes')),
          EbiCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: NotificationType.values.asMap().entries.map((entry) {
                final index = entry.key;
                final type = entry.value;
                final enabled = prefs.enabledTypes[type] ?? true;
                return Column(
                  children: [
                    if (index > 0) const Divider(height: 1, indent: 16),
                    SwitchListTile(
                      title: Text(_typeLabel(type, ref)),
                      value: enabled,
                      activeColor: EbiColors.primaryBlue,
                      onChanged: (v) =>
                          notifier.toggleNotificationType(type, v),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
      child: Text(
        title,
        style: EbiTextStyles.labelSmall.copyWith(
          color: EbiColors.textSecondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  String _typeLabel(NotificationType type, WidgetRef ref) {
    switch (type) {
      case NotificationType.order:
        return ref.L('Orders');
      case NotificationType.quotation:
        return ref.L('Quotations');
      case NotificationType.production:
        return ref.L('Production');
      case NotificationType.shipping:
        return ref.L('Shipping');
      case NotificationType.approval:
        return ref.L('Approvals');
      case NotificationType.chat:
        return ref.L('ChatMessages');
      case NotificationType.system:
        return ref.L('System');
    }
  }
}
