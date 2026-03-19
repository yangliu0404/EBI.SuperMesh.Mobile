/// Chat message types.
enum MessageType { text, image, file, video, audio, system, contactCard, voiceCall, videoCall }

/// Delivery/read status for sent messages.
enum MessageStatus { sending, sent, delivered, read }

/// Represents a single chat message.
class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final MessageType type;
  final String content;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final String? fileExt;
  final int? mediaDuration;
  final DateTime createdAt;
  final MessageStatus status;
  final Map<String, dynamic>? extraProperties;

  // ── Quoted reply fields ──
  final String? quotedMessageId;
  final String? quotedSenderName;
  final String? quotedContent;
  final MessageType? quotedMessageType;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.type,
    required this.content,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.fileExt,
    this.mediaDuration,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.extraProperties,
    this.quotedMessageId,
    this.quotedSenderName,
    this.quotedContent,
    this.quotedMessageType,
  });

  bool isFromUser(String userId) => senderId == userId;

  ChatMessage copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    MessageType? type,
    String? content,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? fileExt,
    int? mediaDuration,
    DateTime? createdAt,
    MessageStatus? status,
    Map<String, dynamic>? extraProperties,
    String? quotedMessageId,
    String? quotedSenderName,
    String? quotedContent,
    MessageType? quotedMessageType,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      type: type ?? this.type,
      content: content ?? this.content,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      fileExt: fileExt ?? this.fileExt,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      extraProperties: extraProperties ?? this.extraProperties,
      quotedMessageId: quotedMessageId ?? this.quotedMessageId,
      quotedSenderName: quotedSenderName ?? this.quotedSenderName,
      quotedContent: quotedContent ?? this.quotedContent,
      quotedMessageType: quotedMessageType ?? this.quotedMessageType,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      senderAvatar: json['sender_avatar'] as String?,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      content: json['content'] as String,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      fileExt: json['file_ext'] as String?,
      mediaDuration: json['media_duration'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      extraProperties: json['extra_properties'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sender_avatar': senderAvatar,
        'type': type.name,
        'content': content,
        'file_url': fileUrl,
        'file_name': fileName,
        'file_size': fileSize,
        'mime_type': mimeType,
        'file_ext': fileExt,
        'media_duration': mediaDuration,
        'created_at': createdAt.toIso8601String(),
        if (extraProperties != null) 'extra_properties': extraProperties,
      };
}
