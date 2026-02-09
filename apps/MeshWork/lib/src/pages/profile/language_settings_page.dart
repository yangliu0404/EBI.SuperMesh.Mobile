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

    return Scaffold(
      appBar: const EbiAppBar(title: 'Language'),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: AppLanguage.values.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, index) {
          final lang = AppLanguage.values[index];
          final isSelected = settings.language == lang;
          return ListTile(
            title: Text(lang.label, style: EbiTextStyles.bodyLarge),
            subtitle: Text(lang.code, style: EbiTextStyles.bodySmall),
            trailing: isSelected
                ? const Icon(Icons.check, color: EbiColors.primaryBlue)
                : null,
            onTap: () {
              ref.read(settingsProvider.notifier).setLanguage(lang);
            },
          );
        },
      ),
    );
  }
}
