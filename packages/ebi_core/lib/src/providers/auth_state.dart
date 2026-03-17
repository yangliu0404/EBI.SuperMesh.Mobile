import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_models/ebi_models.dart';
import 'package:ebi_core/src/auth/auth_repository.dart';
import 'package:ebi_core/src/auth/token_storage.dart';
import 'package:ebi_core/src/auth/tenant_storage.dart';
import 'package:ebi_core/src/network/api_exception.dart';

/// Authentication state.
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final Tenant? currentTenant;
  final List<Tenant> availableTenants;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.currentTenant,
    this.availableTenants = const [],
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    Tenant? currentTenant,
    List<Tenant>? availableTenants,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      currentTenant: currentTenant ?? this.currentTenant,
      availableTenants: availableTenants ?? this.availableTenants,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Manages authentication state using Riverpod.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final TokenStorage _tokenStorage;
  final TenantStorage _tenantStorage;

  AuthNotifier({
    required AuthRepository authRepository,
    required TokenStorage tokenStorage,
    required TenantStorage tenantStorage,
  })  : _authRepository = authRepository,
        _tokenStorage = tokenStorage,
        _tenantStorage = tenantStorage,
        super(const AuthState());

  /// Check if the user has a stored valid token.
  Future<void> checkAuthStatus() async {
    final hasToken = await _tokenStorage.hasValidToken();
    if (hasToken) {
      try {
        final user = await _authRepository.getProfile();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
      } on ApiException catch (e) {
        // Only clear tokens on explicit 401 (truly unauthorized).
        // Network errors should NOT destroy the session.
        if (e.errorCode == 'UNAUTHORIZED') {
          await _tokenStorage.clearTokens();
          state = state.copyWith(status: AuthStatus.unauthenticated);
        } else {
          // Network timeout / connection error — keep token, still authenticated.
          state = state.copyWith(status: AuthStatus.authenticated);
        }
      } catch (_) {
        // Unknown error — preserve session, let user retry later.
        state = state.copyWith(status: AuthStatus.authenticated);
      }
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Fetch available tenants for the login dropdown.
  Future<void> loadTenants() async {
    try {
      final tenants = await _authRepository.getTenants();
      state = state.copyWith(availableTenants: tenants);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load tenants');
    }
  }

  /// Find a tenant by name via ABP API.
  Future<Tenant?> findTenantByName(String name) async {
    if (name.trim().isEmpty) return null;
    try {
      final result = await _authRepository.findTenantByName(name.trim());
      if (result.success) {
        final tenant = result.toTenant();
        if (tenant != null) {
          selectTenant(tenant);
        }
        return tenant;
      }
      state = state.copyWith(error: 'Tenant "$name" not found');
      return null;
    } catch (e) {
      state = state.copyWith(error: 'Failed to find tenant');
      return null;
    }
  }

  /// Select a tenant.
  void selectTenant(Tenant? tenant) {
    state = state.copyWith(currentTenant: tenant);
  }

  /// Clear tenant selection.
  void clearTenant() {
    state = AuthState(
      status: state.status,
      user: state.user,
      currentTenant: null,
      availableTenants: state.availableTenants,
      isLoading: state.isLoading,
      error: null,
    );
  }

  /// Log in with username/password.
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Save tenant before login so the TenantInterceptor picks it up.
      if (state.currentTenant != null) {
        await _tenantStorage.saveTenant(
          tenantId: state.currentTenant!.id,
          tenantName: state.currentTenant!.name,
        );
      } else {
        await _tenantStorage.clearTenant();
      }

      final tokens = await _authRepository.login(
        username: username,
        password: password,
        tenantId: state.currentTenant?.id,
      );

      await _tokenStorage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      final user = await _authRepository.getProfile();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Reloads the current user profile from the server and updates state.
  Future<void> fetchUserInfo() async {
    try {
      final user = await _authRepository.getProfile();
      state = state.copyWith(user: user);
    } catch (e) {
      // Ignore failure, keep existing user state for now.
    }
  }

  /// Called by ApiClient when token refresh fails — force back to login.
  Future<void> sessionExpired() async {
    await _tokenStorage.clearTokens();
    await _tenantStorage.clearTenant();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Log out.
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authRepository.logout();
    } catch (_) {
      // Ignore logout API errors
    }
    await _tokenStorage.clearTokens();
    await _tenantStorage.clearTenant();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
