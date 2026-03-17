import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Appearance / theme mode settings page.
class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: const EbiAppBar(title: 'Appearance'),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: AppAppearance.values.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, index) {
          final mode = AppAppearance.values[index];
          final isSelected = settings.appearance == mode;
          return ListTile(
            leading: Icon(
              _iconFor(mode),
              color: isSelected
                  ? EbiColors.primaryBlue
                  : EbiColors.textSecondary,
            ),
            title: Text(mode.label, style: EbiTextStyles.bodyLarge),
            trailing: isSelected
                ? const Icon(Icons.check, color: EbiColors.primaryBlue)
                : null,
            onTap: () {
              ref.read(settingsProvider.notifier).setAppearance(mode);
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(AppAppearance mode) {
    switch (mode) {
      case AppAppearance.system:
        return Icons.brightness_auto;
      case AppAppearance.light:
        return Icons.light_mode;
      case AppAppearance.dark:
        return Icons.dark_mode;
    }
  }
}
