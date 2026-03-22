import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/src/localization/localization_service.dart';
import 'package:ebi_core/src/localization/abp_localization_models.dart';
import 'package:ebi_core/src/providers/core_providers.dart';
import 'package:ebi_core/src/providers/settings_providers.dart';
import 'package:ebi_core/src/utils/logger.dart';
import 'package:ebi_storage/ebi_storage.dart';

/// Localization state holding the service instance and load status.
class LocalizationState {
  final LocalizationService service;
  final bool isLoaded;
  final bool isChanging;
  final String currentCulture;

  const LocalizationState({
    required this.service,
    this.isLoaded = false,
    this.isChanging = false,
    this.currentCulture = 'en',
  });

  LocalizationState copyWith({
    LocalizationService? service,
    bool? isLoaded,
    bool? isChanging,
    String? currentCulture,
  }) {
    return LocalizationState(
      service: service ?? this.service,
      isLoaded: isLoaded ?? this.isLoaded,
      isChanging: isChanging ?? this.isChanging,
      currentCulture: currentCulture ?? this.currentCulture,
    );
  }

  /// Shorthand to localize a key.
  String L(String key, {String? resourceName}) {
    return service.localize(key, resourceName: resourceName);
  }

  /// Localize with specific resource name.
  String Lr(String resourceName, String key) {
    return service.localize(key, resourceName: resourceName);
  }

  /// Localize with parameter substitution.
  String LArgs(String key, Map<String, String> args, {String? resourceName}) {
    return service.localizeWithArgs(key,
        resourceName: resourceName, args: args);
  }

  /// Available languages.
  List<AbpLanguageInfo> get languages => service.languages;

  /// Current culture info.
  AbpCurrentCulture? get currentCultureInfo => service.currentCulture;

  /// Timing info.
  AbpTimingInfo? get timingInfo => service.timingInfo;

  /// Get Flutter Locale from current culture.
  /// Maps ABP culture names (e.g., 'zh-Hans') to Flutter Locale with scriptCode.
  Locale get locale {
    final parts = currentCulture.split('-');
    if (parts.length >= 2) {
      // ABP uses script codes like 'zh-Hans', 'zh-Hant'
      return Locale.fromSubtags(
        languageCode: parts[0],
        scriptCode: parts.sublist(1).join('-'),
      );
    }
    return Locale(parts[0]);
  }
}

/// Manages localization lifecycle.
class LocalizationNotifier extends StateNotifier<LocalizationState> {
  final Ref _ref;

  LocalizationNotifier(this._ref)
      : super(LocalizationState(
          service: LocalizationService(
            apiClient: _ref.read(apiClientProvider),
          ),
        ));

  /// Load localization for the given culture.
  /// If [cultureName] is null, uses the current settings language.
  Future<void> load([String? cultureName]) async {
    // Inject DB cache DAO if available (optional layer).
    AppCacheDao? cacheDao;
    try {
      cacheDao = _ref.read(appCacheDaoProvider);
    } catch (_) {}
    state.service.cacheDao = cacheDao;

    final culture =
        cultureName ?? _ref.read(settingsProvider).language.cultureName;
    try {
      await state.service.load(culture);
      state = state.copyWith(isLoaded: true, currentCulture: culture);
      AppLogger.info('Localization loaded for: $culture');
    } catch (e) {
      AppLogger.error('Failed to load localization for $culture', e);
    }
  }

  /// Change language: persist setting, reload localization, and update
  /// Accept-Language header for future API calls.
  Future<void> changeLanguage(String cultureName) async {
    // Signal loading state so UI can show a spinner.
    state = state.copyWith(isChanging: true);
    // Update the settings (persisted via SharedPreferences).
    _ref.read(settingsProvider.notifier).setLanguageByCulture(cultureName);
    // Reload localization from backend with new culture.
    await load(cultureName);
    state = state.copyWith(isChanging: false);
  }
}

/// Main localization provider.
final localizationProvider =
    StateNotifierProvider<LocalizationNotifier, LocalizationState>((ref) {
  return LocalizationNotifier(ref);
});

/// Convenience provider: just the L function.
final localizeFunctionProvider = Provider<String Function(String)>((ref) {
  final state = ref.watch(localizationProvider);
  return (key) => state.L(key);
});
