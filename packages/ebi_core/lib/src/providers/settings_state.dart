import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_models/ebi_models.dart';

/// Supported app languages.
enum AppLanguage {
  english('English', 'en'),
  chinese('中文', 'zh'),
  japanese('日本語', 'ja'),
  korean('한국어', 'ko');

  final String label;
  final String code;
  const AppLanguage(this.label, this.code);
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

/// Manages settings state (in-memory mock, no persistence yet).
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void setLanguage(AppLanguage language) {
    state = state.copyWith(language: language);
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
