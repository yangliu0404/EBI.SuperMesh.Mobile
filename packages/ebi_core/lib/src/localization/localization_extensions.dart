import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/src/localization/localization_provider.dart';

/// Extension on [WidgetRef] for convenient localization access.
extension WidgetRefLocalizationExtensions on WidgetRef {
  /// Localize a key. Usage: `ref.L('DisplayName:Email')`
  String L(String key, {String? resourceName}) {
    return watch(localizationProvider).L(key, resourceName: resourceName);
  }

  /// Localize with resource name. Usage: `ref.Lr('AbpIdentity', 'UserName')`
  String Lr(String resourceName, String key) {
    return watch(localizationProvider).Lr(resourceName, key);
  }

  /// Localize with arguments. Usage: `ref.LArgs('Welcome', {'name': 'John'})`
  String LArgs(String key, Map<String, String> args, {String? resourceName}) {
    return watch(localizationProvider)
        .LArgs(key, args, resourceName: resourceName);
  }
}

/// Extension on [BuildContext] for localization without Riverpod.
///
/// Requires a [LocalizationScope] ancestor in the widget tree.
extension BuildContextLocalizationExtensions on BuildContext {
  /// Localize a key from the nearest [LocalizationScope].
  String L(String key, {String? resourceName}) {
    final state = LocalizationScope.of(this);
    return state?.L(key, resourceName: resourceName) ?? key;
  }

  /// Localize with resource name.
  String Lr(String resourceName, String key) {
    final state = LocalizationScope.of(this);
    return state?.Lr(resourceName, key) ?? key;
  }
}

/// InheritedWidget that makes localization state available via BuildContext.
///
/// Wrap your app (or a subtree) with this to use `context.L('key')`.
class LocalizationScope extends InheritedWidget {
  final LocalizationState _state;

  const LocalizationScope({
    super.key,
    required LocalizationState state,
    required super.child,
  }) : _state = state;

  static LocalizationState? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LocalizationScope>()
        ?._state;
  }

  @override
  bool updateShouldNotify(LocalizationScope oldWidget) {
    return _state.currentCulture != oldWidget._state.currentCulture ||
        _state.isLoaded != oldWidget._state.isLoaded;
  }
}
