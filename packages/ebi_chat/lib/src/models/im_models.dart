/// Backend-aligned IM data models for ABP IM chat module.
///
/// These models match the backend API responses exactly.
/// Use [im_mappers.dart] to convert to UI models ([ChatMessage], [ChatRoom]).

/// Backend message type (int values matching ABP IM MessageType enum).
enum ImMessageType {
  text(0),
  image(10),
  link(20),
  video(30),
  voice(40),
  file(50),
  voiceCall(60),
  videoCall(70),
  meeting(80),
  notifier(100);

  const ImMessageType(this.value);
  final int value;

  static ImMessageType fromValue(int value) {
    return ImMessageType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ImMessageType.text,
    );
  }
}

/// Backend message source type.
enum ImMessageSourceType {
  user(0),
  system(10);

  const ImMessageSourceType(this.value);
  final int value;

  static ImMessageSourceType fromValue(int value) {
    return ImMessageSourceType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ImMessageSourceType.user,
    );
  }
}

/// Backend message state.
enum ImMessageState {
  send(0),
  read(1),
  recall(10),
  failed(50),
  backTo(100);

  const ImMessageState(this.value);
  final int value;

  static ImMessageState fromValue(int value) {
    return ImMessageState.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ImMessageState.recall, // Default to recall if state 10 is missing or other issues
    ).value == 10 ? ImMessageState.recall : ImMessageState.values.firstWhere((e) => e.value == value, orElse: () => ImMessageState.send);
  }
  
  // Refined fromValue for safety.
  static ImMessageState safeFromValue(int? value) {
    if (value == null) return ImMessageState.send;
    for (final s in ImMessageState.values) {
      if (s.value == value) return s;
    }
    return ImMessageState.send;
  }
}

/// Backend ChatMessage — matches the ABP IM ChatMessage interface.
class ImChatMessage {
  final String? tenantId;
  final String groupId;
  final String messageId;
  final String formUserId;
  final String formUserName;
  final String? toUserId;
  final String content;
  final String sendTime;
  final bool isAnonymous;
  final int messageType;
  final int source;
  final int? state;
  final Map<String, dynamic>? extraProperties;

  const ImChatMessage({
    this.tenantId,
    this.groupId = '',
    required this.messageId,
    required this.formUserId,
    required this.formUserName,
    this.toUserId,
    required this.content,
    required this.sendTime,
    this.isAnonymous = false,
    this.messageType = 0,
    this.source = 0,
    this.state,
    this.extraProperties,
  });

  ImMessageType get messageTypeEnum => ImMessageType.fromValue(messageType);
  ImMessageSourceType get sourceEnum => ImMessageSourceType.fromValue(source);

  bool get isGroupMessage => groupId.isNotEmpty;

  factory ImChatMessage.fromJson(Map<String, dynamic> json) {
    return ImChatMessage(
      tenantId: _findValue(json, 'tenantId') as String?,
      groupId: (_findValue(json, 'groupId') as String?) ?? '',
      messageId: _findValue(json, 'messageId') as String? ?? '',
      formUserId: _findValue(json, 'formUserId') as String? ?? '',
      formUserName: _findValue(json, 'formUserName') as String? ?? '',
      toUserId: _findValue(json, 'toUserId') as String?,
      content: _findValue(json, 'content') as String? ?? '',
      sendTime: _findValue(json, 'sendTime') as String? ?? '',
      isAnonymous: _findValue(json, 'isAnonymous') as bool? ?? false,
      messageType: _toInt(_findValue(json, 'messageType')) ?? 0,
      source: _toInt(_findValue(json, 'source')) ?? 0,
      state: _toInt(_findValue(json, 'state')),
      extraProperties: _findValue(json, 'extraProperties') as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (tenantId != null) 'tenantId': tenantId,
        'groupId': groupId,
        'messageId': messageId,
        'formUserId': formUserId,
        'formUserName': formUserName,
        if (toUserId != null) 'toUserId': toUserId,
        'content': content,
        'sendTime': sendTime,
        'isAnonymous': isAnonymous,
        'messageType': messageType,
        'source': source,
        if (state != null) 'state': state,
        if (extraProperties != null) 'extraProperties': extraProperties,
      };

  ImChatMessage copyWith({
    String? tenantId,
    String? groupId,
    String? messageId,
    String? formUserId,
    String? formUserName,
    String? toUserId,
    String? content,
    String? sendTime,
    bool? isAnonymous,
    int? messageType,
    int? source,
    int? state,
    Map<String, dynamic>? extraProperties,
  }) {
    return ImChatMessage(
      tenantId: tenantId ?? this.tenantId,
      groupId: groupId ?? this.groupId,
      messageId: messageId ?? this.messageId,
      formUserId: formUserId ?? this.formUserId,
      formUserName: formUserName ?? this.formUserName,
      toUserId: toUserId ?? this.toUserId,
      content: content ?? this.content,
      sendTime: sendTime ?? this.sendTime,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      messageType: messageType ?? this.messageType,
      source: source ?? this.source,
      state: state ?? this.state,
      extraProperties: extraProperties ?? this.extraProperties,
    );
  }
}

/// Backend LastChatMessage — the conversation list item from
/// `/api/im/chat/my-last-messages`.
class ImLastChatMessage {
  final String avatarUrl;
  final String object;
  final String? tenantId;
  final String groupId;
  final String messageId;
  final String formUserId;
  final String formUserName;
  final String toUserId;
  final String content;
  final String sendTime;
  final bool isAnonymous;
  final int messageType;
  final int source;
  final bool? online;
  final int? unreadCount;
  final Map<String, dynamic>? extraProperties;

  const ImLastChatMessage({
    this.avatarUrl = '',
    this.object = '',
    this.tenantId,
    this.groupId = '',
    this.messageId = '',
    this.formUserId = '',
    this.formUserName = '',
    this.toUserId = '',
    this.content = '',
    this.sendTime = '',
    this.isAnonymous = false,
    this.messageType = 0,
    this.source = 0,
    this.online,
    this.unreadCount,
    this.extraProperties,
  });

  bool get isGroupMessage => groupId.isNotEmpty;

  factory ImLastChatMessage.fromJson(Map<String, dynamic> json) {
    return ImLastChatMessage(
      avatarUrl: _findValue(json, 'avatarUrl') as String? ?? '',
      object: _findValue(json, 'object') as String? ?? '',
      tenantId: _findValue(json, 'tenantId') as String?,
      groupId: (_findValue(json, 'groupId') as String?) ?? '',
      messageId: _findValue(json, 'messageId') as String? ?? '',
      formUserId: _findValue(json, 'formUserId') as String? ?? '',
      formUserName: _findValue(json, 'formUserName') as String? ?? '',
      toUserId: _findValue(json, 'toUserId') as String? ?? '',
      content: _findValue(json, 'content') as String? ?? '',
      sendTime: _findValue(json, 'sendTime') as String? ?? '',
      isAnonymous: _findValue(json, 'isAnonymous') as bool? ?? false,
      messageType: _toInt(_findValue(json, 'messageType')) ?? 0,
      source: _toInt(_findValue(json, 'source')) ?? 0,
      online: _findValue(json, 'online') as bool?,
      unreadCount: _toInt(_findValue(json, 'unreadCount')),
      extraProperties: _findValue(json, 'extraProperties') as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'avatarUrl': avatarUrl,
        'object': object,
        if (tenantId != null) 'tenantId': tenantId,
        'groupId': groupId,
        'messageId': messageId,
        'formUserId': formUserId,
        'formUserName': formUserName,
        'toUserId': toUserId,
        'content': content,
        'sendTime': sendTime,
        'isAnonymous': isAnonymous,
        'messageType': messageType,
        'source': source,
        if (online != null) 'online': online,
        if (unreadCount != null) 'unreadCount': unreadCount,
        if (extraProperties != null) 'extraProperties': extraProperties,
      };
}

/// Messages-read receipt event from SignalR.
class ImMessagesReadEvent {
  final String readerUserId;
  final List<String> messageIds;
  final String? readTime;

  const ImMessagesReadEvent({
    required this.readerUserId,
    required this.messageIds,
    this.readTime,
  });

  factory ImMessagesReadEvent.fromJson(Map<String, dynamic> json) {
    return ImMessagesReadEvent(
      readerUserId: _findValue(json, 'readerUserId') as String? ?? '',
      messageIds: (_findValue(json, 'messageIds') as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      readTime: _findValue(json, 'readTime') as String?,
    );
  }
}

/// Group user changed event from SignalR.
class ImGroupUserChangedEvent {
  final String groupId;
  final String userId;
  final String? groupName;
  final String? avatarUrl;
  final int? groupUserCount;

  const ImGroupUserChangedEvent({
    required this.groupId,
    required this.userId,
    this.groupName,
    this.avatarUrl,
    this.groupUserCount,
  });

  factory ImGroupUserChangedEvent.fromJson(Map<String, dynamic> json) {
    return ImGroupUserChangedEvent(
      groupId: _findValue(json, 'groupId') as String? ?? '',
      userId: _findValue(json, 'userId') as String? ?? '',
      groupName: _findValue(json, 'groupName') as String?,
      avatarUrl: _findValue(json, 'avatarUrl') as String?,
      groupUserCount: _toInt(_findValue(json, 'groupUserCount')),
    );
  }
}

/// Group info updated event from SignalR.
class ImGroupInfoUpdatedEvent {
  final String groupId;
  final String? name;
  final String? notice;
  final String? description;
  final String? avatarUrl;
  final String? adminUserId;

  const ImGroupInfoUpdatedEvent({
    required this.groupId,
    this.name,
    this.notice,
    this.description,
    this.avatarUrl,
    this.adminUserId,
  });

  factory ImGroupInfoUpdatedEvent.fromJson(Map<String, dynamic> json) {
    return ImGroupInfoUpdatedEvent(
      groupId: _findValue(json, 'groupId') as String? ?? '',
      name: _findValue(json, 'name') as String?,
      notice: _findValue(json, 'notice') as String?,
      description: _findValue(json, 'description') as String?,
      avatarUrl: _findValue(json, 'avatarUrl') as String?,
      adminUserId: _findValue(json, 'adminUserId') as String?,
    );
  }
}

/// Result returned from sending a message via REST API.
class ImChatMessageSendResult {
  final String messageId;

  const ImChatMessageSendResult({required this.messageId});

  factory ImChatMessageSendResult.fromJson(Map<String, dynamic> json) {
    return ImChatMessageSendResult(
      messageId: _findValue(json, 'messageId') as String? ?? '',
    );
  }
}

// ── Shared Parsing Helpers ────────────────────────────────────────────────

dynamic _findValue(Map<String, dynamic> json, String key) {
  if (json.containsKey(key)) return json[key];
  final lowerKey = key.toLowerCase();
  for (final k in json.keys) {
    if (k.toLowerCase() == lowerKey) return json[k];
  }
  return null;
}

int? _toInt(dynamic val) {
  if (val == null) return null;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val);
  return null;
}
