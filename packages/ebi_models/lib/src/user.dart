/// User roles within the e-bi system.
enum UserRole { admin, manager, employee, client }

/// Represents a user (employee or client).
class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final UserRole role;
  final String? company;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    required this.role,
    this.company,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.employee,
      ),
      company: json['company'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Create a User from ABP `/connect/userinfo` response.
  factory User.fromUserInfo(Map<String, dynamic> json) {
    final sub = json['sub'] as String? ?? '';
    final givenName = json['given_name'] as String? ?? '';
    final familyName = json['family_name'] as String? ?? '';
    final name = json['name'] as String? ??
        '$givenName $familyName'.trim();

    // Map ABP roles to UserRole.
    final roles = json['role'];
    UserRole role = UserRole.employee;
    if (roles is List && roles.contains('admin')) {
      role = UserRole.admin;
    } else if (roles is String && roles == 'admin') {
      role = UserRole.admin;
    }

    return User(
      id: sub,
      name: name.isNotEmpty ? name : sub,
      email: json['email'] as String? ?? '',
      phone: json['phone_number'] as String?,
      avatar: json['avatar_url'] as String? ?? json['picture'] as String?,
      role: role,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar': avatar,
        'role': role.name,
        'company': company,
        'created_at': createdAt?.toIso8601String(),
      };
}
