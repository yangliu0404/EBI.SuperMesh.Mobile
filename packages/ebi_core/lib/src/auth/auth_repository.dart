import 'package:ebi_models/ebi_models.dart';

/// Abstract authentication repository.
/// Implementations: MockAuthRepository, AbpAuthRepository.
abstract class AuthRepository {
  /// Fetch available tenants (for pre-configured lists).
  Future<List<Tenant>> getTenants();

  /// Find a tenant by name via ABP API.
  Future<FindTenantResult> findTenantByName(String name);

  /// Log in with credentials under a specific tenant.
  Future<AuthTokens> login({
    required String username,
    required String password,
    String? tenantId,
  });

  /// Log out and invalidate the current session.
  Future<void> logout();

  /// Get current user profile.
  Future<User> getProfile();
}
