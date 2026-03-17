import 'package:ebi_models/ebi_models.dart';
import 'package:ebi_core/src/auth/auth_repository.dart';

/// Mock implementation of [AuthRepository] for Phase 0.5 development.
class MockAuthRepository implements AuthRepository {
  static const _mockDelay = Duration(milliseconds: 800);

  @override
  Future<List<Tenant>> getTenants() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      Tenant(id: 'tenant-001', name: 'Acme Corp', displayName: 'Acme Corporation'),
      Tenant(id: 'tenant-002', name: 'GlobalTrade', displayName: 'GlobalTrade Ltd.'),
      Tenant(id: 'tenant-003', name: 'SilkRoad', displayName: 'SilkRoad Manufacturing'),
    ];
  }

  @override
  Future<AuthTokens> login({
    required String username,
    required String password,
    String? tenantId,
  }) async {
    await Future.delayed(_mockDelay);

    // Accept any non-empty credentials for mock
    if (username.isEmpty || password.isEmpty) {
      throw Exception('Username and password are required');
    }

    return const AuthTokens(
      accessToken: 'mock_access_token_phase05',
      refreshToken: 'mock_refresh_token_phase05',
      expiresIn: 3600,
    );
  }

  @override
  Future<FindTenantResult> findTenantByName(String name) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final tenants = await getTenants();
    final match = tenants.where(
      (t) => t.name.toLowerCase() == name.toLowerCase(),
    );
    if (match.isNotEmpty) {
      return FindTenantResult(
        success: true,
        tenantId: match.first.id,
        name: match.first.name,
      );
    }
    return const FindTenantResult(success: false);
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<User> getProfile() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return User(
      id: 'user-001',
      name: 'Brian Chen',
      email: 'brian@e-bi.com',
      role: UserRole.admin,
      company: 'e-bi International',
      createdAt: DateTime(2024, 1, 15),
    );
  }
}
