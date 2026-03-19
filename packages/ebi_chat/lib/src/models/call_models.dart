/// Data models for voice/video call (mirrors Web `types/call.ts`).

/// 通话类型
enum CallType {
  voice, // 0
  video, // 1
}

/// 通话状态
enum CallStatus {
  ringing, // 0
  connected, // 1
  ended, // 2
  missed, // 3
  rejected, // 4
  cancelled, // 5
  busy, // 6
}

/// 会话类型
enum ConversationType {
  private_, // 0
  group, // 1
}

/// 通话方向
enum CallDirection { incoming, outgoing }

/// LiveKit 令牌结果 (from POST /api/rtc/calls or join)
class CallTokenResult {
  final String callRecordId;
  final String token;
  final String liveKitServerUrl;
  final String roomName;

  const CallTokenResult({
    required this.callRecordId,
    required this.token,
    required this.liveKitServerUrl,
    required this.roomName,
  });

  factory CallTokenResult.fromJson(Map<String, dynamic> json) {
    return CallTokenResult(
      callRecordId: json['callRecordId'] as String? ?? json['id'] as String? ?? '',
      token: json['token'] as String? ?? '',
      liveKitServerUrl: json['liveKitServerUrl'] as String? ?? '',
      roomName: json['roomName'] as String? ?? '',
    );
  }
}

/// SignalR: 来电事件载荷
class IncomingCallPayload {
  final String callRecordId;
  final String callerUserId;
  final String callerUserName;
  final CallType callType;
  final ConversationType conversationType;

  const IncomingCallPayload({
    required this.callRecordId,
    required this.callerUserId,
    required this.callerUserName,
    required this.callType,
    required this.conversationType,
  });

  factory IncomingCallPayload.fromJson(Map<String, dynamic> json) {
    return IncomingCallPayload(
      callRecordId: json['callRecordId'] as String? ?? '',
      callerUserId: json['callerUserId'] as String? ?? '',
      callerUserName: json['callerUserName'] as String? ?? '',
      callType: CallType.values[(json['callType'] as int?) ?? 0],
      conversationType:
          ConversationType.values[(json['conversationType'] as int?) ?? 0],
    );
  }
}

/// 当前活跃通话
class ActiveCall {
  final String callRecordId;
  final CallType callType;
  final ConversationType conversationType;
  final String? targetUserId;
  final String? targetUserName;
  final String roomName;
  final String token;
  final String liveKitServerUrl;
  final CallStatus status;
  final CallDirection direction;
  final String callerUserId;
  final String? callerUserName;
  final DateTime startTime;
  DateTime? connectTime;

  ActiveCall({
    required this.callRecordId,
    required this.callType,
    required this.conversationType,
    this.targetUserId,
    this.targetUserName,
    required this.roomName,
    required this.token,
    required this.liveKitServerUrl,
    required this.status,
    required this.direction,
    required this.callerUserId,
    this.callerUserName,
    required this.startTime,
    this.connectTime,
  });
}
