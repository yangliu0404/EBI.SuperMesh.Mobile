/// Represents a chat room tied to an order/project.
class ChatRoom {
  final String id;
  final String name;
  final String? orderId;
  final String? projectId;
  final List<String> memberIds;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime createdAt;

  const ChatRoom({
    required this.id,
    required this.name,
    this.orderId,
    this.projectId,
    required this.memberIds,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    required this.createdAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      orderId: json['order_id'] as String?,
      projectId: json['project_id'] as String?,
      memberIds: (json['member_ids'] as List).cast<String>(),
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order_id': orderId,
        'project_id': projectId,
        'member_ids': memberIds,
        'last_message': lastMessage,
        'last_message_at': lastMessageAt?.toIso8601String(),
        'unread_count': unreadCount,
        'created_at': createdAt.toIso8601String(),
      };
}
