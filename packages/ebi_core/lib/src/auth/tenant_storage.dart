import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the selected tenant ID for multi-tenant ABP requests.
class TenantStorage {
  static const _tenantIdKey = 'ebi_tenant_id';
  static const _tenantNameKey = 'ebi_tenant_name';

  final FlutterSecureStorage _storage;

  TenantStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> getTenantId() async {
    return _storage.read(key: _tenantIdKey);
  }

  Future<String?> getTenantName() async {
    return _storage.read(key: _tenantNameKey);
  }

  Future<void> saveTenant({
    required String tenantId,
    required String tenantName,
  }) async {
    await Future.wait([
      _storage.write(key: _tenantIdKey, value: tenantId),
      _storage.write(key: _tenantNameKey, value: tenantName),
    ]);
  }

  Future<void> clearTenant() async {
    await Future.wait([
      _storage.delete(key: _tenantIdKey),
      _storage.delete(key: _tenantNameKey),
    ]);
  }

  Future<bool> hasTenant() async {
    final id = await getTenantId();
    return id != null && id.isNotEmpty;
  }
}
