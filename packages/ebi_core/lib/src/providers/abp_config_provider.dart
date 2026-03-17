import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/src/providers/core_providers.dart';

/// ABP application configuration state.
class AbpAppConfig {
  final Map<String, bool> permissions;
  final Map<String, String> settings;
  final Map<String, Map<String, String>> localization;
  final Map<String, dynamic> raw;

  const AbpAppConfig({
    this.permissions = const {},
    this.settings = const {},
    this.localization = const {},
    this.raw = const {},
  });

  bool hasPermission(String name) => permissions[name] ?? false;
  String? getSetting(String name) => settings[name];
}

/// Notifier that fetches and caches ABP application configuration.
class AbpConfigNotifier extends StateNotifier<AsyncValue<AbpAppConfig>> {
  final Ref _ref;

  AbpConfigNotifier(this._ref) : super(const AsyncValue.loading());

  /// Fetch `/api/abp/application-configuration` and parse permissions/settings.
  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.get(
        '/api/abp/application-configuration',
      );
      final data = response.data as Map<String, dynamic>;

      // Parse permissions: auth.grantedPolicies is Map<String, bool>.
      final authSection = data['auth'] as Map<String, dynamic>? ?? {};
      final grantedPolicies =
          authSection['grantedPolicies'] as Map<String, dynamic>? ?? {};
      final permissions = grantedPolicies
          .map((k, v) => MapEntry(k, v as bool? ?? false));

      // Parse settings: setting.values is Map<String, String>.
      final settingSection =
          data['setting'] as Map<String, dynamic>? ?? {};
      final settingValues =
          settingSection['values'] as Map<String, dynamic>? ?? {};
      final settings =
          settingValues.map((k, v) => MapEntry(k, v?.toString() ?? ''));

      // Parse localization values if present.
      final locSection =
          data['localization'] as Map<String, dynamic>? ?? {};
      final locValues =
          locSection['values'] as Map<String, dynamic>? ?? {};
      final localization = locValues.map((resourceName, resourceMap) {
        final map = (resourceMap as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v?.toString() ?? '')) ??
            <String, String>{};
        return MapEntry(resourceName, map);
      });

      state = AsyncValue.data(AbpAppConfig(
        permissions: permissions,
        settings: settings,
        localization: localization,
        raw: data,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// ABP application configuration provider.
final abpConfigProvider =
    StateNotifierProvider<AbpConfigNotifier, AsyncValue<AbpAppConfig>>(
  (ref) => AbpConfigNotifier(ref),
);
