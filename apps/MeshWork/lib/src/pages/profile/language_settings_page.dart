import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';

/// Language selection settings page.
class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = ref.watch(localizationProvider);

    // Use backend languages if available, otherwise fall back to enum.
    final backendLanguages = l10n.languages;
    final useBackendLanguages = backendLanguages.isNotEmpty;

    return Scaffold(
      appBar: EbiAppBar(title: ref.L('Language')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: useBackendLanguages
            ? backendLanguages.length
            : AppLanguage.values.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, index) {
          if (useBackendLanguages) {
            final lang = backendLanguages[index];
            final isSelected =
                settings.language.cultureName == lang.cultureName;
            return ListTile(
              title: Text(lang.displayName, style: EbiTextStyles.bodyLarge),
              subtitle:
                  Text(lang.cultureName, style: EbiTextStyles.bodySmall),
              trailing: isSelected
                  ? const Icon(Icons.check, color: EbiColors.primaryBlue)
                  : null,
              onTap: () {
                ref
                    .read(localizationProvider.notifier)
                    .changeLanguage(lang.cultureName);
              },
            );
          } else {
            final lang = AppLanguage.values[index];
            final isSelected = settings.language == lang;
            return ListTile(
              title: Text(lang.label, style: EbiTextStyles.bodyLarge),
              subtitle:
                  Text(lang.cultureName, style: EbiTextStyles.bodySmall),
              trailing: isSelected
                  ? const Icon(Icons.check, color: EbiColors.primaryBlue)
                  : null,
              onTap: () {
                ref
                    .read(localizationProvider.notifier)
                    .changeLanguage(lang.cultureName);
              },
            );
          }
        },
      ),
    );
  }
}
