/// Chat room types.
enum ChatRoomType { direct, group, channel }

/// Represents a chat room — private, group, or channel.
class ChatRoom {
  final String id;
  final String name;
  final ChatRoomType type;
  final String? avatar;
  final String? tenantName;
  final String? orderId;
  final String? projectId;
  final List<String> memberIds;
  final int memberCount;
  final String? lastMessage;
  final String? lastMessageId;
  final String? lastSenderName;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isOnline;
  final DateTime createdAt;

  const ChatRoom({
    required this.id,
    required this.name,
    this.type = ChatRoomType.channel,
    this.avatar,
    this.tenantName,
    this.orderId,
    this.projectId,
    required this.memberIds,
    this.memberCount = 0,
    this.lastMessage,
    this.lastMessageId,
    this.lastSenderName,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isOnline = false,
    required this.createdAt,
  });

  bool get isDirect => type == ChatRoomType.direct;
  bool get isGroup => type == ChatRoomType.group;
  bool get isChannel => type == ChatRoomType.channel;

  ChatRoom copyWith({
    String? id,
    String? name,
    ChatRoomType? type,
    String? avatar,
    String? tenantName,
    String? orderId,
    String? projectId,
    List<String>? memberIds,
    int? memberCount,
    String? lastMessage,
    String? lastMessageId,
    String? lastSenderName,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isOnline,
    DateTime? createdAt,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      avatar: avatar ?? this.avatar,
      tenantName: tenantName ?? this.tenantName,
      orderId: orderId ?? this.orderId,
      projectId: projectId ?? this.projectId,
      memberIds: memberIds ?? this.memberIds,
      memberCount: memberCount ?? this.memberCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastSenderName: lastSenderName ?? this.lastSenderName,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isOnline: isOnline ?? this.isOnline,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ChatRoomType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChatRoomType.channel,
      ),
      avatar: json['avatar'] as String?,
      tenantName: json['tenant_name'] as String?,
      orderId: json['order_id'] as String?,
      projectId: json['project_id'] as String?,
      memberIds: (json['member_ids'] as List).cast<String>(),
      memberCount: json['member_count'] as int? ?? 0,
      lastMessage: json['last_message'] as String?,
      lastMessageId: json['last_message_id'] as String?,
      lastSenderName: json['last_sender_name'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      isPinned: json['is_pinned'] as bool? ?? false,
      isMuted: json['is_muted'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'avatar': avatar,
        'tenant_name': tenantName,
        'order_id': orderId,
        'project_id': projectId,
        'member_ids': memberIds,
        'member_count': memberCount,
        'last_message': lastMessage,
        'last_message_id': lastMessageId,
        'last_sender_name': lastSenderName,
        'last_message_at': lastMessageAt?.toIso8601String(),
        'unread_count': unreadCount,
        'is_pinned': isPinned,
        'is_muted': isMuted,
        'is_online': isOnline,
        'created_at': createdAt.toIso8601String(),
      };
}
