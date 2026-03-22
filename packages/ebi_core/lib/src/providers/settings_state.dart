import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ebi_models/ebi_models.dart';

/// Supported app languages with ABP culture names.
enum AppLanguage {
  english('English', 'en', 'en'),
  chineseSimplified('简体中文', 'zh-Hans', 'zh'),
  chineseTraditional('繁體中文', 'zh-Hant', 'zh'),
  japanese('日本語', 'ja', 'ja'),
  korean('한국어', 'ko', 'ko');

  /// Display label.
  final String label;

  /// ABP culture name (used in API requests).
  final String cultureName;

  /// ISO 639-1 language code (used for Locale).
  final String languageCode;

  const AppLanguage(this.label, this.cultureName, this.languageCode);

  /// Get Flutter Locale.
  Locale get locale {
    final parts = cultureName.split('-');
    if (parts.length >= 2) {
      return Locale.fromSubtags(
        languageCode: parts[0],
        scriptCode: parts.sublist(1).join('-'),
      );
    }
    return Locale(parts[0]);
  }

  /// Find by culture name, returns english as default.
  static AppLanguage fromCultureName(String cultureName) {
    return AppLanguage.values.firstWhere(
      (l) => l.cultureName == cultureName,
      orElse: () => AppLanguage.english,
    );
  }

  /// Backward compatibility alias.
  String get code => cultureName;
}

/// Appearance mode.
enum AppAppearance {
  system('Auto'),
  light('Light'),
  dark('Dark');

  final String label;
  const AppAppearance(this.label);
}

/// Per-type notification preferences.
class NotificationPreferences {
  final Map<NotificationType, bool> enabledTypes;
  final bool pushEnabled;
  final bool emailEnabled;
  final bool soundEnabled;

  const NotificationPreferences({
    this.enabledTypes = const {
      NotificationType.order: true,
      NotificationType.quotation: true,
      NotificationType.production: true,
      NotificationType.shipping: true,
      NotificationType.approval: true,
      NotificationType.chat: true,
      NotificationType.system: true,
    },
    this.pushEnabled = true,
    this.emailEnabled = true,
    this.soundEnabled = true,
  });

  NotificationPreferences copyWith({
    Map<NotificationType, bool>? enabledTypes,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? soundEnabled,
  }) {
    return NotificationPreferences(
      enabledTypes: enabledTypes ?? this.enabledTypes,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}

/// Application settings state.
class SettingsState {
  final AppLanguage language;
  final AppAppearance appearance;
  final NotificationPreferences notificationPreferences;

  const SettingsState({
    this.language = AppLanguage.english,
    this.appearance = AppAppearance.system,
    this.notificationPreferences = const NotificationPreferences(),
  });

  SettingsState copyWith({
    AppLanguage? language,
    AppAppearance? appearance,
    NotificationPreferences? notificationPreferences,
  }) {
    return SettingsState(
      language: language ?? this.language,
      appearance: appearance ?? this.appearance,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
    );
  }
}

/// SharedPreferences key for persisted language.
const _kLanguageKey = 'app_language_culture';

/// Manages settings state with persistence.
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  /// Initialize from persisted storage.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCulture = prefs.getString(_kLanguageKey);
    if (savedCulture != null) {
      final lang = AppLanguage.fromCultureName(savedCulture);
      state = state.copyWith(language: lang);
    }
  }

  void setLanguage(AppLanguage language) {
    state = state.copyWith(language: language);
    _persistLanguage(language.cultureName);
  }

  /// Set language by ABP culture name string.
  void setLanguageByCulture(String cultureName) {
    final lang = AppLanguage.fromCultureName(cultureName);
    setLanguage(lang);
  }

  Future<void> _persistLanguage(String cultureName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageKey, cultureName);
  }

  void setAppearance(AppAppearance appearance) {
    state = state.copyWith(appearance: appearance);
  }

  void toggleNotificationType(NotificationType type, bool enabled) {
    final updated = Map<NotificationType, bool>.from(
      state.notificationPreferences.enabledTypes,
    );
    updated[type] = enabled;
    state = state.copyWith(
      notificationPreferences:
          state.notificationPreferences.copyWith(enabledTypes: updated),
    );
  }

  void setPushEnabled(bool enabled) {
    state = state.copyWith(
      notificationPreferences:
          state.notificationPreferences.copyWith(pushEnabled: enabled),
    );
  }

  void setEmailEnabled(bool enabled) {
    state = state.copyWith(
      notificationPreferences:
          state.notificationPreferences.copyWith(emailEnabled: enabled),
    );
  }

  void setSoundEnabled(bool enabled) {
    state = state.copyWith(
      notificationPreferences:
          state.notificationPreferences.copyWith(soundEnabled: enabled),
    );
  }
}
