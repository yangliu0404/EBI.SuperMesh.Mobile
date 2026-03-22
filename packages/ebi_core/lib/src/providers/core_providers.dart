import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/src/auth/auth_repository.dart';
import 'package:ebi_core/src/auth/abp_auth_repository.dart';
import 'package:ebi_core/src/auth/token_storage.dart';
import 'package:ebi_core/src/auth/tenant_storage.dart';
import 'package:ebi_core/src/config/app_config.dart';
import 'package:ebi_core/src/network/api_client.dart';
import 'package:ebi_core/src/providers/auth_state.dart';
import 'package:ebi_core/src/providers/settings_providers.dart';

/// Client ID provider — overridden per-app in main.dart.
final clientIdProvider = Provider<String>((ref) {
  return AppConfig.meshWorkClientId; // default; overridden by app
});

/// Token storage provider.
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// Tenant storage provider.
final tenantStorageProvider = Provider<TenantStorage>((ref) {
  return TenantStorage();
});

/// API client provider.
final apiClientProvider = Provider<ApiClient>((ref) {
  final clientId = ref.read(clientIdProvider);
  final tokenStorage = ref.read(tokenStorageProvider);
  final tenantStorage = ref.read(tenantStorageProvider);
  return ApiClient(
    clientId: clientId,
    tokenStorage: tokenStorage,
    tenantStorage: tenantStorage,
    getLanguage: () => ref.read(settingsProvider).language.cultureName,
  );
});

/// Auth repository provider — now uses AbpAuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  final tokenStorage = ref.read(tokenStorageProvider);
  final clientId = ref.read(clientIdProvider);
  return AbpAuthRepository(
    dio: apiClient.dio,
    tokenStorage: tokenStorage,
    clientId: clientId,
  );
});

/// Auth state notifier provider.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(
    authRepository: ref.read(authRepositoryProvider),
    tokenStorage: ref.read(tokenStorageProvider),
    tenantStorage: ref.read(tenantStorageProvider),
  );
  // Wire session-expiry: when token refresh fails, force logout.
  // Done here (not in apiClientProvider) to avoid circular dependency.
  ref.read(apiClientProvider).onSessionExpired = () {
    notifier.sessionExpired();
  };
  return notifier;
});
