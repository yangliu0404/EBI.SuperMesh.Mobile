import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/src/providers/settings_state.dart';

/// Settings state notifier provider.
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
