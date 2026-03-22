import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/chat_room.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_storage/ebi_storage.dart';

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
      return MessageType.video;
    case ImMessageType.videoCall:
      return MessageType.videoCall;
    case ImMessageType.voice:
      return MessageType.audio;
    case ImMessageType.voiceCall:
      return MessageType.voiceCall;
    case ImMessageType.file:
      return MessageType.file;
    case ImMessageType.notifier:
      return MessageType.system;
    case ImMessageType.meeting:
      return MessageType.meeting;
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
    return fromLower == currentLower ? (toUserId ?? formUserId) : formUserId;
  }

  ChatMessage toUiMessage(String currentUserId) {
    // ── Recalled messages → system message ──
    final imState = state != null ? ImMessageState.safeFromValue(state!) : null;
    final isRecalled = imState == ImMessageState.recall;
    final isSystemSource =
        ImMessageSourceType.fromValue(source) == ImMessageSourceType.system;

    // Check if message type is explicitly a call type so we don't treat empty calls as recalled.
    final msgType = ImMessageType.fromValue(messageType);
    final isCall =
        msgType == ImMessageType.videoCall ||
        msgType == ImMessageType.voiceCall;

    // If it's explicitly recalled OR it's a system message with empty content (and NOT a call)
    // OR it's a system message with recall text in content (backend pattern).
    if (isRecalled ||
        (isSystemSource && content.trim().isEmpty && !isCall) ||
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
        final extraName =
            extraProperties?['FormUserName'] as String? ??
            extraProperties?['formUserName'] as String?;
        final candidateName =
            formUserName.isNotEmpty && formUserName.toLowerCase() != 'system'
            ? formUserName
            : extraName;
        if (candidateName != null &&
            candidateName.isNotEmpty &&
            candidateName.toLowerCase() != 'system') {
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
        extraProperties: extraProperties,
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
      final intVal = quotedTypeRaw is int
          ? quotedTypeRaw
          : int.tryParse('$quotedTypeRaw');
      if (intVal != null) {
        quotedMsgType = mapImMessageType(intVal);
      }
    }

    final mappedType = mapImMessageType(messageType);
    final isCallType = mappedType == MessageType.voiceCall || mappedType == MessageType.videoCall;
    
    return ChatMessage(
      id: messageId,
      roomId: conversationId(currentUserId),
      senderId: formUserId,
      senderName: formUserName,
      type: (isSystem && !isCallType) ? MessageType.system : mappedType,
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
      extraProperties: extraProperties,
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
    return extraProperties?['fileName']?.toString() ??
        extraProperties?['FileName']?.toString() ??
        extraProperties?['name']?.toString() ??
        extraProperties?['Name']?.toString();
  }

  /// Extract file extension with fallback chain:
  /// extraProperties['fileExt'] → fileName → content (ossPath).
  String? _extractFileExt() {
    final ext =
        extraProperties?['fileExt']?.toString() ??
        extraProperties?['FileExt']?.toString();
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
      lastMessageAt: sendTime.isNotEmpty ? DateTime.tryParse(sendTime) : null,
      unreadCount: unreadCount ?? 0,
      isPinned: isPinned,
      isMuted: isMuted,
      isOnline: online ?? false,
      createdAt: sendTime.isNotEmpty
          ? (DateTime.tryParse(sendTime) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  /// Check if this is a recalled message.
  bool _isRecalled() {
    final msgType = ImMessageType.fromValue(messageType);
    if (msgType == ImMessageType.videoCall ||
        msgType == ImMessageType.voiceCall) {
      return false; // calls are never recalled messages
    }

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

/// Extension to convert UI [ChatMessage] to DB [MessagesCompanion] for writing.
extension ChatMessageToDb on ChatMessage {
  MessagesCompanion toDbCompanion() {
    // Reverse map UI MessageType to backend int
    int backendType;
    switch (type) {
      case MessageType.text: backendType = 0;
      case MessageType.image: backendType = 10;
      case MessageType.video: backendType = 30;
      case MessageType.audio: backendType = 40;
      case MessageType.file: backendType = 50;
      case MessageType.voiceCall: backendType = 60;
      case MessageType.videoCall: backendType = 70;
      case MessageType.meeting: backendType = 80;
      case MessageType.contactCard: backendType = 90;
      case MessageType.system: backendType = 100;
    }

    int? stateValue;
    switch (status) {
      case MessageStatus.sending: stateValue = null;
      case MessageStatus.sent: stateValue = 0;
      case MessageStatus.delivered: stateValue = 0;
      case MessageStatus.read: stateValue = 1;
    }

    return MessagesCompanion.insert(
      messageId: id,
      tenantId: Value(null),
      groupId: Value(roomId.startsWith('group:') ? roomId.substring(6) : ''),
      formUserId: senderId,
      formUserName: senderName,
      toUserId: Value(null),
      content: content,
      sendTime: createdAt.toIso8601String(),
      isAnonymous: Value(false),
      messageType: Value(backendType),
      source: Value(type == MessageType.system ? 10 : 0),
      state: Value(stateValue),
      extraProperties: Value(extraProperties != null ? jsonEncode(extraProperties) : null),
      roomId: roomId,
      syncState: Value(0),
      localCreatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Extension to convert DB [Message] row to UI [ChatMessage] for reading.
extension DbMessageToUi on Message {
  ChatMessage toUiMessage() {
    final Map<String, dynamic>? extras = extraProperties != null
        ? jsonDecode(extraProperties!) as Map<String, dynamic>
        : null;

    return ChatMessage(
      id: messageId,
      roomId: roomId,
      senderId: formUserId,
      senderName: formUserName,
      type: mapImMessageType(messageType),
      content: content,
      fileName: extras?['fileName']?.toString() ?? extras?['FileName']?.toString(),
      fileSize: _toIntSafe(extras?['fileSize'] ?? extras?['FileSize']),
      mimeType: extras?['mimeType']?.toString(),
      fileExt: extras?['fileExt']?.toString() ?? extras?['FileExt']?.toString(),
      mediaDuration: _toIntSafe(extras?['duration'] ?? extras?['Duration']),
      createdAt: DateTime.tryParse(sendTime) ?? DateTime.now(),
      status: mapImMessageState(state),
      extraProperties: extras,
      quotedMessageId: extras?['quotedMessageId']?.toString(),
      quotedSenderName: extras?['quotedSenderName']?.toString(),
      quotedContent: extras?['quotedContent']?.toString(),
      quotedMessageType: extras?['quotedMessageType'] != null
          ? mapImMessageType(_toIntSafe(extras!['quotedMessageType']) ?? 0)
          : null,
    );
  }

  static int? _toIntSafe(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }
}

/// Extension to convert UI [ChatRoom] to DB [ConversationsCompanion] for writing.
extension ChatRoomToDb on ChatRoom {
  ConversationsCompanion toDbCompanion() {
    return ConversationsCompanion.insert(
      id: id,
      avatarUrl: Value(avatar ?? ''),
      object: Value(name),
      groupId: Value(id.startsWith('group:') ? id.substring(6) : ''),
      messageId: Value(lastMessageId ?? ''),
      content: Value(lastMessage ?? ''),
      sendTime: Value(lastMessageAt?.toIso8601String() ?? ''),
      formUserName: Value(lastSenderName ?? ''),
      unreadCount: Value(unreadCount),
      type: Value(type == ChatRoomType.group ? 1 : 0),
      isPinned: Value(isPinned),
      isMuted: Value(isMuted),
      online: Value(isOnline),
      localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Extension to convert DB [Conversation] row to UI [ChatRoom] for reading.
extension DbConversationToUi on Conversation {
  ChatRoom toUiRoom() {
    return ChatRoom(
      id: id,
      name: object,
      type: type == 1 ? ChatRoomType.group : ChatRoomType.direct,
      avatar: avatarUrl.isNotEmpty ? avatarUrl : null,
      memberIds: const [],
      lastMessage: content.isNotEmpty ? content : null,
      lastMessageId: messageId.isNotEmpty ? messageId : null,
      lastSenderName: formUserName.isNotEmpty ? formUserName : null,
      lastMessageAt: sendTime.isNotEmpty ? DateTime.tryParse(sendTime) : null,
      unreadCount: unreadCount,
      isPinned: isPinned,
      isMuted: isMuted,
      isOnline: online ?? false,
      createdAt: sendTime.isNotEmpty
          ? (DateTime.tryParse(sendTime) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
