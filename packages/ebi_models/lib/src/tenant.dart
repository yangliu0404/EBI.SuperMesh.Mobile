/// Represents an ABP tenant.
class Tenant {
  final String id;
  final String name;
  final String? displayName;
  final bool isAvailable;

  const Tenant({
    required this.id,
    required this.name,
    this.displayName,
    this.isAvailable = true,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['tenantId'] as String,
      name: json['name'] as String,
      displayName: json['displayName'] as String?,
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  /// Parse from ABP `/api/abp/multi-tenancy/tenants/by-name/{name}` response.
  /// Response: `{ success, tenantId, name, isActive }`
  factory Tenant.fromFindResult(Map<String, dynamic> json) {
    return Tenant(
      id: json['tenantId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isAvailable: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'tenantId': id,
        'name': name,
        'displayName': displayName,
        'isAvailable': isAvailable,
      };
}

/// Result from ABP tenant lookup endpoint.
class FindTenantResult {
  final bool success;
  final String? tenantId;
  final String? name;
  final bool isActive;

  const FindTenantResult({
    required this.success,
    this.tenantId,
    this.name,
    this.isActive = true,
  });

  factory FindTenantResult.fromJson(Map<String, dynamic> json) {
    return FindTenantResult(
      success: json['success'] as bool? ?? false,
      tenantId: json['tenantId'] as String?,
      name: json['name'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Tenant? toTenant() {
    if (!success || tenantId == null) return null;
    return Tenant(
      id: tenantId!,
      name: name ?? '',
      isAvailable: isActive,
    );
  }
}
