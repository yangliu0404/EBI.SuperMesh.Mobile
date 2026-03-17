import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/chat_room.dart';
import 'package:ebi_chat/src/models/im_models.dart';

/// Maps backend [ImMessageState] to UI [MessageStatus].
MessageStatus mapImMessageState(int? stateValue) {
  if (stateValue == null) return MessageStatus.sent;
  final imState = ImMessageState.safeFromValue(stateValue);
  switch (imState) {
    case ImMessageState.send:
      return MessageStatus.sent;
    case ImMessageState.read:
      return MessageStatus.read;
    case ImMessageState.failed:
      return MessageStatus.sending; // treat as still pending
    case ImMessageState.recall:
    case ImMessageState.backTo:
      return MessageStatus.sent;
  }
}

/// Maps backend [ImMessageType] int to UI [MessageType].
MessageType mapImMessageType(int backendType) {
  final imType = ImMessageType.fromValue(backendType);
  switch (imType) {
    case ImMessageType.text:
    case ImMessageType.link:
      return MessageType.text;
    case ImMessageType.image:
      return MessageType.image;
    case ImMessageType.video:
    case ImMessageType.videoCall:
      return MessageType.video;
    case ImMessageType.voice:
    case ImMessageType.voiceCall:
      return MessageType.audio;
    case ImMessageType.file:
      return MessageType.file;
    case ImMessageType.notifier:
    case ImMessageType.meeting:
      return MessageType.system;
    case ImMessageType.contactCard:
      return MessageType.contactCard;
  }
}

/// Extension to convert backend [ImChatMessage] to UI [ChatMessage].
extension ImChatMessageMapper on ImChatMessage {
  /// Derive the conversation ID used by the UI layer.
  String conversationId(String currentUserId) {
    if (isGroupMessage) return 'group:$groupId';
    // For 1-to-1, use the other party's ID (case-insensitive comparison).
    final currentLower = currentUserId.toLowerCase();
    final fromLower = formUserId.toLowerCase();
    return fromLower == currentLower
        ? (toUserId ?? formUserId)
        : formUserId;
  }

  ChatMessage toUiMessage(String currentUserId) {
    // ── Recalled messages → system message ──
    final imState = state != null ? ImMessageState.safeFromValue(state!) : null;
    final isRecalled = imState == ImMessageState.recall;
    final isSystemSource =
        ImMessageSourceType.fromValue(source) == ImMessageSourceType.system;

    // If it's explicitly recalled OR it's a system message with empty content
    // OR it's a system message with recall text in content (backend pattern).
    if (isRecalled || (isSystemSource && content.trim().isEmpty) ||
        content.contains('撤回了一条消息')) {
      final isSelf = formUserId.toLowerCase() == currentUserId.toLowerCase();
      // Determine display name for the recaller:
      // 1. Self → '你'
      // 2. formUserName (if not "system")
      // 3. extraProperties.FormUserName
      // 4. Fallback: '撤回了一条消息' without name prefix
      String recallText;
      if (isSelf) {
        recallText = '你撤回了一条消息';
      } else {
        final extraName = extraProperties?['FormUserName'] as String?
            ?? extraProperties?['formUserName'] as String?;
        final candidateName = formUserName.isNotEmpty && formUserName.toLowerCase() != 'system'
            ? formUserName
            : extraName;
        if (candidateName != null && candidateName.isNotEmpty && candidateName.toLowerCase() != 'system') {
          recallText = '$candidateName撤回了一条消息';
        } else {
          recallText = '撤回了一条消息';
        }
      }
      return ChatMessage(
        id: messageId,
        roomId: conversationId(currentUserId),
        senderId: 'system',
        senderName: 'System',
        type: MessageType.system,
        content: recallText,
        createdAt: _parseSendTime(),
        status: MessageStatus.sent,
      );
    }

    final isSystem =
        ImMessageSourceType.fromValue(source) == ImMessageSourceType.system;

    // Extract quoted reply info from extraProperties (Web QuotedMessageExtra).
    final quotedMsgId = extraProperties?['quotedMessageId'] as String?;
    final quotedSender = extraProperties?['quotedSenderName'] as String?;
    final quotedContent = extraProperties?['quotedContent'] as String?;
    final quotedTypeRaw = extraProperties?['quotedMessageType'];
    MessageType? quotedMsgType;
    if (quotedTypeRaw != null) {
      final intVal = quotedTypeRaw is int ? quotedTypeRaw : int.tryParse('$quotedTypeRaw');
      if (intVal != null) {
        quotedMsgType = mapImMessageType(intVal);
      }
    }

    return ChatMessage(
      id: messageId,
      roomId: conversationId(currentUserId),
      senderId: formUserId,
      senderName: formUserName,
      type: isSystem ? MessageType.system : mapImMessageType(messageType),
      content: content,
      fileUrl: _extractFileUrl(),
      fileName: _extractFileName(),
      fileSize: _extractInt('fileSize'),
      mimeType: extraProperties?['mimeType'] as String?,
      fileExt: _extractFileExt(),
      mediaDuration: _extractInt('duration'),
      createdAt: _parseSendTime(),
      status: mapImMessageState(state),
      quotedMessageId: quotedMsgId,
      quotedSenderName: quotedSender,
      quotedContent: quotedContent,
      quotedMessageType: quotedMsgType,
    );
  }

  String? _extractFileUrl() {
    final type = ImMessageType.fromValue(messageType);
    if (type == ImMessageType.image ||
        type == ImMessageType.file ||
        type == ImMessageType.video ||
        type == ImMessageType.voice) {
      return content;
    }
    return null;
  }

  String? _extractFileName() {
    return extraProperties?['fileName']?.toString() 
        ?? extraProperties?['FileName']?.toString()
        ?? extraProperties?['name']?.toString()
        ?? extraProperties?['Name']?.toString();
  }

  /// Extract file extension with fallback chain:
  /// extraProperties['fileExt'] → fileName → content (ossPath).
  String? _extractFileExt() {
    final ext = extraProperties?['fileExt']?.toString() 
             ?? extraProperties?['FileExt']?.toString();
    if (ext != null && ext.isNotEmpty) return ext;
    // Fallback: derive from fileName.
    final name = _extractFileName();
    final fromName = _extFromString(name);
    if (fromName != null) return fromName;
    // Fallback: derive from content (ossPath like "blobs:im/.../file.pdf").
    return _extFromString(content);
  }

  static String? _extFromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final dot = value.lastIndexOf('.');
    if (dot < 0 || dot == value.length - 1) return null;
    return value.substring(dot + 1).toLowerCase();
  }

  int? _extractInt(String key) {
    var value = extraProperties?[key];
    if (value == null && key.isNotEmpty) {
      // Try PascalCase
      final pascalKey = key[0].toUpperCase() + key.substring(1);
      value = extraProperties?[pascalKey];
    }
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  DateTime _parseSendTime() {
    if (sendTime.isEmpty) return DateTime.now();
    return DateTime.tryParse(sendTime) ?? DateTime.now();
  }
}

/// Extension to convert backend [ImLastChatMessage] to UI [ChatRoom].
extension ImLastChatMessageMapper on ImLastChatMessage {
  ChatRoom toUiRoom(String currentUserId) {
    final isGroup = groupId.isNotEmpty;
    final currentLower = currentUserId.toLowerCase();
    final fromLower = formUserId.toLowerCase();
    final convId = isGroup
        ? 'group:$groupId'
        : (fromLower == currentLower ? toUserId : formUserId);

    final isRecallMessage = _isRecalled();

    return ChatRoom(
      id: convId,
      name: object,
      type: isGroup ? ChatRoomType.group : ChatRoomType.direct,
      avatar: avatarUrl.isNotEmpty ? avatarUrl : null,
      memberIds: const [],
      lastMessage: _formatLastMessage(currentUserId),
      lastMessageId: messageId,
      // Clear lastSenderName for recalled messages so tile doesn't prepend "system:"
      lastSenderName: isRecallMessage ? '' : formUserName,
      lastMessageAt: sendTime.isNotEmpty
          ? DateTime.tryParse(sendTime)
          : null,
      unreadCount: unreadCount ?? 0,
      isOnline: online ?? false,
      createdAt: sendTime.isNotEmpty
          ? (DateTime.tryParse(sendTime) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  /// Check if this is a recalled message.
  bool _isRecalled() {
    final isSystemSource =
        ImMessageSourceType.fromValue(source) == ImMessageSourceType.system;
    // Recalled if: system source with empty content, OR content contains recall text
    if (isSystemSource && content.trim().isEmpty) return true;
    if (content.contains('撤回了一条消息')) return true;
    return false;
  }

  String _formatLastMessage(String currentUserId) {
    if (_isRecalled()) {
      // For 1-to-1 chats, use 'object' (the conversation name = the other person).
      // For group chats, we can't reliably know who recalled, just show the text.
      final isGroup = groupId.isNotEmpty;
      final isSelf = formUserId.toLowerCase() == currentUserId.toLowerCase();
      if (isSelf) {
        return '你撤回了一条消息';
      } else if (!isGroup) {
        // Direct chat: 'object' is the other person's display name.
        return '$object撤回了一条消息';
      } else {
        // Group: try formUserName if it's not "system".
        if (formUserName.isNotEmpty && formUserName.toLowerCase() != 'system') {
          return '$formUserName撤回了一条消息';
        }
        return '撤回了一条消息';
      }
    }

    final type = ImMessageType.fromValue(messageType);
    switch (type) {
      case ImMessageType.image:
        return '[Image]';
      case ImMessageType.video:
        return '[Video]';
      case ImMessageType.voice:
        return '[Voice]';
      case ImMessageType.file:
        return '[File]';
      case ImMessageType.voiceCall:
        return '[Voice Call]';
      case ImMessageType.videoCall:
        return '[Video Call]';
      case ImMessageType.meeting:
        return '[Meeting]';
      default:
        return content;
    }
  }
}
