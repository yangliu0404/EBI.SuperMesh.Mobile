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
      appBar: const EbiAppBar(title: 'Notifications'),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _sectionHeader('GENERAL'),
          EbiCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive push notifications'),
                  value: prefs.pushEnabled,
                  activeColor: EbiColors.primaryBlue,
                  onChanged: (v) => notifier.setPushEnabled(v),
                ),
                const Divider(height: 1, indent: 16),
                SwitchListTile(
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Receive email notifications'),
                  value: prefs.emailEnabled,
                  activeColor: EbiColors.primaryBlue,
                  onChanged: (v) => notifier.setEmailEnabled(v),
                ),
                const Divider(height: 1, indent: 16),
                SwitchListTile(
                  title: const Text('Sound'),
                  subtitle: const Text('Play sound for notifications'),
                  value: prefs.soundEnabled,
                  activeColor: EbiColors.primaryBlue,
                  onChanged: (v) => notifier.setSoundEnabled(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _sectionHeader('NOTIFICATION TYPES'),
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
                      title: Text(_typeLabel(type)),
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

  String _typeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return 'Orders';
      case NotificationType.quotation:
        return 'Quotations';
      case NotificationType.production:
        return 'Production';
      case NotificationType.shipping:
        return 'Shipping';
      case NotificationType.approval:
        return 'Approvals';
      case NotificationType.chat:
        return 'Chat Messages';
      case NotificationType.system:
        return 'System';
    }
  }
}
