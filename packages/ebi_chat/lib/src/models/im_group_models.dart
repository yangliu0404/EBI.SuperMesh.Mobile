/// Group and user models for the IM chat module.
///
/// Based on the Web frontend's TypeScript: `packages/@abp/im/src/types/chat.ts`
/// and `packages/@abp/im/src/types/friends.ts`.

// ── Group ────────────────────────────────────────────────────────────────

/// Represents a chat group's detail info.
class ImGroup {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? notice;
  final String? description;
  final String? adminUserId;
  final String? tag;
  final int maxUserCount;
  final bool allowAnonymous;
  final bool allowSendMessage;
  final int groupAcceptJoinType;
  final DateTime? creationTime;

  const ImGroup({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.notice,
    this.description,
    this.adminUserId,
    this.tag,
    this.maxUserCount = 200,
    this.allowAnonymous = false,
    this.allowSendMessage = true,
    this.groupAcceptJoinType = 0,
    this.creationTime,
  });

  factory ImGroup.fromJson(Map<String, dynamic> json) {
    return ImGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      notice: json['notice'] as String?,
      description: json['description'] as String?,
      adminUserId: json['adminUserId'] as String?,
      tag: json['tag'] as String?,
      maxUserCount: json['maxUserCount'] as int? ?? 200,
      allowAnonymous: json['allowAnonymous'] as bool? ?? false,
      allowSendMessage: json['allowSendMessage'] as bool? ?? true,
      groupAcceptJoinType: json['groupAcceptJoinType'] as int? ?? 0,
      creationTime: json['creationTime'] != null
          ? DateTime.tryParse(json['creationTime'] as String)
          : null,
    );
  }
}

// ── Group Member ─────────────────────────────────────────────────────────

/// Represents a group member (user card within a group).
class ImGroupMember {
  final String userId;
  final String userName;
  final String? nickName;
  final String? avatarUrl;
  final bool isAdmin;
  final bool isSuperAdmin;
  final bool isMuted;
  final DateTime? silenceEnd;

  const ImGroupMember({
    required this.userId,
    required this.userName,
    this.nickName,
    this.avatarUrl,
    this.isAdmin = false,
    this.isSuperAdmin = false,
    this.isMuted = false,
    this.silenceEnd,
  });

  /// Display name: nickName if available, otherwise userName.
  String get displayName => (nickName?.isNotEmpty == true) ? nickName! : userName;

  factory ImGroupMember.fromJson(Map<String, dynamic> json) {
    return ImGroupMember(
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      nickName: json['nickName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      isAdmin: json['isAdmin'] as bool? ?? false,
      isSuperAdmin: json['isSuperAdmin'] as bool? ?? false,
      isMuted: json['isMuted'] as bool? ?? false,
      silenceEnd: json['silenceEnd'] != null
          ? DateTime.tryParse(json['silenceEnd'] as String)
          : null,
    );
  }
}

// ── User Card ────────────────────────────────────────────────────────────

/// Represents a user's detailed profile card.
class ImUserCard {
  final String userId;
  final String userName;
  final String? nickName;
  final String? name;          // 核心名
  final String? surname;       // 核心姓
  final String? nativeName;    // 类似中文名
  final String? firstName;     // 名
  final String? lastName;      // 姓
  final String? phoneNumber;   // 电话
  final String? email;         // 邮箱
  final String? company;       // 企业/组织
  final String? department;    // 部门
  final String? position;      // 职位
  final String? employeeNumber; // 工号
  final String? avatarUrl;
  final int sex;          // 0=Other, 1=Male, 2=Female
  final int age;
  final String? birthday;
  final String? sign;
  final String? description;
  final bool online;
  final String? lastOnlineTime;

  const ImUserCard({
    required this.userId,
    required this.userName,
    this.nickName,
    this.name,
    this.surname,
    this.nativeName,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.email,
    this.company,
    this.department,
    this.position,
    this.employeeNumber,
    this.avatarUrl,
    this.sex = 0,
    this.age = 0,
    this.birthday,
    this.sign,
    this.description,
    this.online = false,
    this.lastOnlineTime,
  });

  String get displayName => (nickName?.isNotEmpty == true) ? nickName! : userName;

  /// Full real name — "姓名" combined.
  String? get fullName {
    final s = surname ?? '';
    final n = name ?? '';
    if (s.isEmpty && n.isEmpty) return null;
    return '$s$n'.trim();
  }

  String get sexLabel {
    switch (sex) {
      case 1: return '男';
      case 2: return '女';
      default: return '其他';
    }
  }

  String get formattedLastSeen {
    if (online) return '在线';
    if (lastOnlineTime == null) return '离线';
    final then = DateTime.tryParse(lastOnlineTime!);
    if (then == null) return '离线';
    final diff = DateTime.now().difference(then);
    if (diff.isNegative) return '在线';
    if (diff.inMinutes < 1) return '最后在线: 刚刚';
    if (diff.inMinutes < 60) return '最后在线: ${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '最后在线: ${diff.inHours}小时前';
    if (diff.inDays == 1) return '最后在线: 昨天';
    if (diff.inDays < 30) return '最后在线: ${diff.inDays}天前';
    return '最后在线: ${then.month}/${then.day}';
  }

  factory ImUserCard.fromJson(Map<String, dynamic> json) {
    return ImUserCard(
      userId: json['userId'] as String? ?? json['id'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      nickName: json['nickName'] as String?,
      name: json['name'] as String?,
      surname: json['surname'] as String?,
      nativeName: json['nativeName'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      phoneNumber: json['phoneNumber'] as String? ?? json['phone'] as String?,
      email: json['email'] as String?,
      company: json['company'] as String? ?? json['tenantName'] as String?,
      department: json['department'] as String?,
      position: json['position'] as String? ?? json['jobTitle'] as String?,
      employeeNumber: json['employeeNumber'] as String? ?? json['jobNumber'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      sex: json['sex'] as int? ?? 0,
      age: json['age'] as int? ?? 0,
      birthday: json['birthday'] as String?,
      sign: json['sign'] as String?,
      description: json['description'] as String?,
      online: json['online'] as bool? ?? false,
      lastOnlineTime: json['lastOnlineTime'] as String?,
    );
  }
}
