import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:ebi_core/src/network/api_client.dart';
import 'package:ebi_core/src/network/api_endpoints.dart';
import 'package:ebi_core/src/localization/abp_localization_models.dart';
import 'package:ebi_core/src/utils/logger.dart';

/// Service that loads and manages localization resources.
///
/// Priority: ABP backend first, local JSON fallback second.
class LocalizationService {
  final ApiClient _apiClient;

  /// Merged flat texts: { key: translatedValue }.
  /// All resources are flattened into a single map for quick lookup.
  Map<String, String> _texts = {};

  /// Per-resource texts: { resourceName: { key: value } }.
  Map<String, Map<String, String>> _resourceTexts = {};

  /// Available languages from the backend.
  List<AbpLanguageInfo> _languages = [];

  /// Current culture info from ABP.
  AbpCurrentCulture? _currentCulture;

  /// Timing info from ABP.
  AbpTimingInfo? _timingInfo;

  /// Default resource name from ABP configuration.
  String? _defaultResourceName;

  LocalizationService({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// All merged texts (flat).
  Map<String, String> get texts => _texts;

  /// Per-resource texts.
  Map<String, Map<String, String>> get resourceTexts => _resourceTexts;

  /// Available languages.
  List<AbpLanguageInfo> get languages => _languages;

  /// Current culture info.
  AbpCurrentCulture? get currentCulture => _currentCulture;

  /// Timing info.
  AbpTimingInfo? get timingInfo => _timingInfo;

  /// Default resource name.
  String? get defaultResourceName => _defaultResourceName;

  /// Load localization for the given culture.
  ///
  /// 1. Try to fetch from ABP backend `/api/abp/application-localization`.
  /// 2. If that fails, fall back to local JSON asset.
  /// 3. Also loads languages and timing from `/api/abp/application-configuration`.
  Future<void> load(String cultureName) async {
    Map<String, Map<String, String>> remoteTexts = {};
    bool remoteSuccess = false;

    // 1. Try ABP backend (primary source).
    try {
      remoteTexts = await _loadFromBackend(cultureName);
      remoteSuccess = true;
    } catch (e) {
      AppLogger.warning('Failed to load localization from backend: $e');
    }

    // 2. Load local fallback.
    Map<String, Map<String, String>> localTexts = {};
    try {
      localTexts = await _loadFromLocal(cultureName);
    } catch (e) {
      AppLogger.debug('No local localization for $cultureName: $e');
    }

    // 3. Merge: local as base, remote overwrites.
    _resourceTexts = _mergeResources(localTexts, remoteTexts);

    // 4. Flatten all resources into a single map.
    _texts = _flattenResources(_resourceTexts);

    // 5. Always try to load application configuration for languages, timing,
    //    etc. This endpoint is typically public and provides the available
    //    language list even before authentication.
    try {
      AppLogger.debug('[L10n] Loading app config...');
      await _loadAppConfig();
      AppLogger.debug('[L10n] App config loaded, languages: ${_languages.length}');
    } catch (e, st) {
      AppLogger.warning('Failed to load app configuration: $e\n$st');
    }
  }

  /// Fetch localization from ABP backend.
  Future<Map<String, Map<String, String>>> _loadFromBackend(
      String cultureName) async {
    final response = await _apiClient.get(
      ApiEndpoints.abpApplicationLocalization,
      queryParameters: {
        'cultureName': cultureName,
        'onlyDynamics': false,
      },
    );

    var data = response.data as Map<String, dynamic>;
    // Unwrap ABP WrapResult format { code, message, result }.
    if (data.containsKey('result') && data['result'] is Map<String, dynamic>) {
      data = data['result'] as Map<String, dynamic>;
    }
    final result = AbpLocalizationResult.fromJson(data);

    // Recursively merge base resources.
    final merged = _mergeBaseResources(result.resources);

    return merged.map((key, resource) {
      return MapEntry(key, Map<String, String>.from(resource.texts));
    });
  }

  /// Recursively merge base resources into each resource.
  Map<String, AbpLocalizationResource> _mergeBaseResources(
      Map<String, AbpLocalizationResource> resources) {
    final Map<String, AbpLocalizationResource> merged = {};

    for (final key in resources.keys) {
      merged[key] = _recursivelyMerge(key, resources, {});
    }
    return merged;
  }

  AbpLocalizationResource _recursivelyMerge(
    String resourceName,
    Map<String, AbpLocalizationResource> resources,
    Set<String> visited,
  ) {
    if (visited.contains(resourceName)) {
      return const AbpLocalizationResource();
    }
    visited.add(resourceName);

    final resource = resources[resourceName];
    if (resource == null) {
      return const AbpLocalizationResource();
    }

    final mergedTexts = <String, String>{};

    // First, merge base resources (lower priority).
    for (final baseName in resource.baseResources) {
      final baseResource = _recursivelyMerge(baseName, resources, visited);
      mergedTexts.addAll(baseResource.texts);
    }

    // Then, add own texts (higher priority, overwrites base).
    mergedTexts.addAll(resource.texts);

    return AbpLocalizationResource(
      texts: mergedTexts,
      baseResources: resource.baseResources,
    );
  }

  /// Load localization from local JSON asset.
  Future<Map<String, Map<String, String>>> _loadFromLocal(
      String cultureName) async {
    final jsonStr = await rootBundle
        .loadString('assets/locales/$cultureName.json', cache: false);
    final data = json.decode(jsonStr) as Map<String, dynamic>;

    // Local JSON format: flat { key: value } or nested { resource: { key: value } }.
    final result = <String, Map<String, String>>{};

    for (final entry in data.entries) {
      if (entry.value is Map) {
        // Nested: resource -> { key: value }
        final resourceMap = (entry.value as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v?.toString() ?? ''));
        result[entry.key] = resourceMap;
      } else {
        // Flat: put into a default resource.
        result.putIfAbsent('_default', () => {});
        result['_default']![entry.key] = entry.value?.toString() ?? '';
      }
    }
    return result;
  }

  /// Merge two resource maps. [overlay] takes priority over [base].
  Map<String, Map<String, String>> _mergeResources(
    Map<String, Map<String, String>> base,
    Map<String, Map<String, String>> overlay,
  ) {
    final merged = <String, Map<String, String>>{};

    // Add all base resources.
    for (final entry in base.entries) {
      merged[entry.key] = Map<String, String>.from(entry.value);
    }

    // Merge overlay on top.
    for (final entry in overlay.entries) {
      if (merged.containsKey(entry.key)) {
        merged[entry.key]!.addAll(entry.value);
      } else {
        merged[entry.key] = Map<String, String>.from(entry.value);
      }
    }

    return merged;
  }

  /// Flatten all resource maps into a single key->value map.
  Map<String, String> _flattenResources(
      Map<String, Map<String, String>> resources) {
    final flat = <String, String>{};
    for (final resource in resources.values) {
      flat.addAll(resource);
    }
    return flat;
  }

  /// Load application configuration for languages, current culture, timing.
  Future<void> _loadAppConfig() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.abpApplicationConfiguration,
      );
      var data = response.data as Map<String, dynamic>;
      AppLogger.debug('[L10n] appConfig raw keys: ${data.keys.toList()}');
      // Unwrap ABP WrapResult format { code, message, result }.
      if (data.containsKey('result') && data['result'] is Map<String, dynamic>) {
        data = data['result'] as Map<String, dynamic>;
        AppLogger.debug('[L10n] unwrapped result keys: ${data.keys.toList()}');
      }

      // Parse languages.
      final locSection =
          data['localization'] as Map<String, dynamic>? ?? {};
      AppLogger.debug('[L10n] locSection keys: ${locSection.keys.toList()}');
      final langList = locSection['languages'] as List<dynamic>? ?? [];
      AppLogger.info('[L10n] Found ${langList.length} languages from backend');
      _languages = langList
          .map((e) => AbpLanguageInfo.fromJson(e as Map<String, dynamic>))
          .toList();

      // Parse current culture.
      final currentCultureJson =
          locSection['currentCulture'] as Map<String, dynamic>?;
      if (currentCultureJson != null) {
        _currentCulture = AbpCurrentCulture.fromJson(currentCultureJson);
      }

      // Parse default resource name.
      _defaultResourceName = locSection['defaultResourceName'] as String?;

      // Parse timing.
      final timingSection = data['timing'] as Map<String, dynamic>?;
      if (timingSection != null) {
        _timingInfo = AbpTimingInfo.fromJson(timingSection);
      }
    } catch (e) {
      AppLogger.warning('Failed to parse app config: $e');
    }
  }

  /// Look up a translation key.
  ///
  /// Search order:
  /// 1. Specific resource (if [resourceName] is provided).
  /// 2. Default resource name (from ABP config).
  /// 3. All resources (flat lookup).
  /// 4. Return [key] itself as fallback.
  String localize(String key, {String? resourceName}) {
    // Try specific resource.
    if (resourceName != null) {
      final value = _resourceTexts[resourceName]?[key];
      if (value != null) return value;
    }

    // Try default resource.
    if (_defaultResourceName != null) {
      final value = _resourceTexts[_defaultResourceName]?[key];
      if (value != null) return value;
    }

    // Try flat lookup across all resources.
    return _texts[key] ?? key;
  }

  /// Look up a translation with parameter substitution.
  ///
  /// Parameters are replaced in the format `{paramName}`.
  String localizeWithArgs(
    String key, {
    String? resourceName,
    Map<String, String> args = const {},
  }) {
    var text = localize(key, resourceName: resourceName);
    for (final entry in args.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  /// Look up with fallback across multiple resources and keys.
  String localizeWithFallback(
    List<String> resourceNames,
    List<String> keys,
    String defaultValue,
  ) {
    for (final resourceName in resourceNames) {
      for (final key in keys) {
        final value = _resourceTexts[resourceName]?[key];
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return defaultValue;
  }
}
