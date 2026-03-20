/// Data models for meeting management (mirrors Web `types/meeting.ts`).

/// 会议类型
enum MeetingType {
  instant, // 0 - 即时会议
  scheduled, // 1 - 预约会议
}

/// 会议状态
enum MeetingStatus {
  waiting, // 0 - 等待开始
  inProgress, // 1 - 进行中
  ended, // 2 - 已结束
  cancelled, // 3 - 已取消
}

/// 参会者角色
enum ParticipantRole {
  host, // 0 - 主持人
  coHost, // 1 - 联合主持人
  participant, // 2 - 参与者
  viewer, // 3 - 观众
}

/// 参会者状态
enum ParticipantStatus {
  waiting, // 0
  inMeeting, // 1
  left, // 2
  removed, // 3
  waitingAdmission, // 4
}

/// 邀请状态
enum InvitationStatus {
  pending, // 0
  accepted, // 1
  declined, // 2
  cancelled, // 3
}

/// 会议高级设置
class MeetingSettings {
  final int? durationMinutes;
  final bool inviteOnly;
  final bool muteOnJoin;
  final bool disableCameraOnJoin;
  final bool allowScreenShare;
  final bool allowCamera;
  final bool autoRecord;

  const MeetingSettings({
    this.durationMinutes,
    this.inviteOnly = false,
    this.muteOnJoin = false,
    this.disableCameraOnJoin = false,
    this.allowScreenShare = true,
    this.allowCamera = true,
    this.autoRecord = false,
  });

  factory MeetingSettings.fromJson(Map<String, dynamic> json) {
    return MeetingSettings(
      durationMinutes: json['durationMinutes'] as int?,
      inviteOnly: json['inviteOnly'] as bool? ?? false,
      muteOnJoin: json['muteOnJoin'] as bool? ?? false,
      disableCameraOnJoin: json['disableCameraOnJoin'] as bool? ?? false,
      allowScreenShare: json['allowScreenShare'] as bool? ?? true,
      allowCamera: json['allowCamera'] as bool? ?? true,
      autoRecord: json['autoRecord'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        'inviteOnly': inviteOnly,
        'muteOnJoin': muteOnJoin,
        'disableCameraOnJoin': disableCameraOnJoin,
        'allowScreenShare': allowScreenShare,
        'allowCamera': allowCamera,
        'autoRecord': autoRecord,
      };
}

/// 创建会议请求
class CreateMeetingDto {
  final String title;
  final String? description;
  final MeetingType type;
  final String? scheduledStartTime;
  final String? password;
  final int? maxParticipants;
  final bool requiresAdmission;
  final int? durationMinutes;
  final bool muteOnJoin;
  final bool disableCameraOnJoin;
  final bool allowScreenShare;

  const CreateMeetingDto({
    required this.title,
    this.description,
    required this.type,
    this.scheduledStartTime,
    this.password,
    this.maxParticipants,
    this.requiresAdmission = false,
    this.durationMinutes,
    this.muteOnJoin = false,
    this.disableCameraOnJoin = false,
    this.allowScreenShare = true,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null) 'description': description,
        'type': type.index,
        if (scheduledStartTime != null)
          'scheduledStartTime': scheduledStartTime,
        if (password != null) 'password': password,
        if (maxParticipants != null) 'maxParticipants': maxParticipants,
        'requiresAdmission': requiresAdmission,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        'muteOnJoin': muteOnJoin,
        'disableCameraOnJoin': disableCameraOnJoin,
        'allowScreenShare': allowScreenShare,
      };
}

/// 会议 DTO
class MeetingDto {
  final String id;
  final String meetingNo;
  final String title;
  final String? description;
  final String hostUserId;
  final MeetingType type;
  final MeetingStatus status;
  final String? scheduledStartTime;
  final String? actualStartTime;
  final String? actualEndTime;
  final int maxParticipants;
  final bool hasPassword;
  final bool requiresAdmission;
  final String? creatorUserId;
  final String creationTime;
  final InvitationStatus? myInvitationStatus;
  final MeetingSettings? settings;

  const MeetingDto({
    required this.id,
    required this.meetingNo,
    required this.title,
    this.description,
    required this.hostUserId,
    required this.type,
    required this.status,
    this.scheduledStartTime,
    this.actualStartTime,
    this.actualEndTime,
    this.maxParticipants = 100,
    this.hasPassword = false,
    this.requiresAdmission = false,
    this.creatorUserId,
    required this.creationTime,
    this.myInvitationStatus,
    this.settings,
  });

  factory MeetingDto.fromJson(Map<String, dynamic> json) {
    return MeetingDto(
      id: json['id'] as String? ?? '',
      meetingNo: json['meetingNo'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      hostUserId: json['hostUserId'] as String? ?? '',
      type: MeetingType.values[(json['type'] as int?) ?? 0],
      status: MeetingStatus.values[(json['status'] as int?) ?? 0],
      scheduledStartTime: json['scheduledStartTime'] as String?,
      actualStartTime: json['actualStartTime'] as String?,
      actualEndTime: json['actualEndTime'] as String?,
      maxParticipants: json['maxParticipants'] as int? ?? 100,
      hasPassword: json['hasPassword'] as bool? ?? false,
      requiresAdmission: json['requiresAdmission'] as bool? ?? false,
      creatorUserId: json['creatorUserId'] as String?,
      creationTime: json['creationTime'] as String? ?? '',
      myInvitationStatus: json['myInvitationStatus'] != null
          ? InvitationStatus.values[json['myInvitationStatus'] as int]
          : null,
      settings: json['settings'] != null
          ? MeetingSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 会议是否可加入（等待中或进行中）
  bool get isJoinable =>
      status == MeetingStatus.waiting || status == MeetingStatus.inProgress;

  /// 格式化的时间范围
  String get timeRange {
    final start = actualStartTime ?? scheduledStartTime;
    final end = actualEndTime;
    if (start == null) return '';
    final s = DateTime.tryParse(start);
    final e = end != null ? DateTime.tryParse(end) : null;
    if (s == null) return '';
    final startStr =
        '${s.month}月${s.day}日 ${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
    if (e == null) return startStr;
    final endStr =
        '${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}';
    return '$startStr – $endStr';
  }
}

/// 加入会议结果
class JoinMeetingResultDto {
  final String meetingId;
  final String? token;
  final String liveKitServerUrl;
  final String roomName;
  final MeetingDto meeting;

  /// true 表示正在等待主持人准入，token 为空
  final bool isWaiting;

  const JoinMeetingResultDto({
    required this.meetingId,
    this.token,
    required this.liveKitServerUrl,
    required this.roomName,
    required this.meeting,
    this.isWaiting = false,
  });

  factory JoinMeetingResultDto.fromJson(Map<String, dynamic> json) {
    return JoinMeetingResultDto(
      meetingId: json['meetingId'] as String? ?? '',
      token: json['token'] as String?,
      liveKitServerUrl: json['liveKitServerUrl'] as String? ?? '',
      roomName: json['roomName'] as String? ?? '',
      meeting:
          MeetingDto.fromJson(json['meeting'] as Map<String, dynamic>? ?? {}),
      isWaiting: json['isWaiting'] as bool? ?? false,
    );
  }
}

/// 准入状态（等待中的参与者轮询）
class AdmissionStatusDto {
  final bool isAdmitted;
  final bool isDenied;
  final bool isMeetingEnded;
  final String? token;
  final String? liveKitServerUrl;

  const AdmissionStatusDto({
    this.isAdmitted = false,
    this.isDenied = false,
    this.isMeetingEnded = false,
    this.token,
    this.liveKitServerUrl,
  });

  factory AdmissionStatusDto.fromJson(Map<String, dynamic> json) {
    return AdmissionStatusDto(
      isAdmitted: json['isAdmitted'] as bool? ?? false,
      isDenied: json['isDenied'] as bool? ?? false,
      isMeetingEnded: json['isMeetingEnded'] as bool? ?? false,
      token: json['token'] as String?,
      liveKitServerUrl: json['liveKitServerUrl'] as String?,
    );
  }
}

/// 等待准入的参与者
class WaitingParticipantDto {
  final String userId;
  final String userName;
  final String waitingSince;

  const WaitingParticipantDto({
    required this.userId,
    required this.userName,
    required this.waitingSince,
  });

  factory WaitingParticipantDto.fromJson(Map<String, dynamic> json) {
    return WaitingParticipantDto(
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      waitingSince: json['waitingSince'] as String? ?? '',
    );
  }
}

/// 会议邀请 DTO
class MeetingInvitationDto {
  final String id;
  final String meetingId;
  final String inviteeUserId;
  final String inviterUserId;
  final String? inviteeUserName;
  final String? inviterUserName;
  final InvitationStatus status;
  final String creationTime;

  const MeetingInvitationDto({
    required this.id,
    required this.meetingId,
    required this.inviteeUserId,
    required this.inviterUserId,
    this.inviteeUserName,
    this.inviterUserName,
    required this.status,
    required this.creationTime,
  });

  factory MeetingInvitationDto.fromJson(Map<String, dynamic> json) {
    return MeetingInvitationDto(
      id: json['id'] as String? ?? '',
      meetingId: json['meetingId'] as String? ?? '',
      inviteeUserId: json['inviteeUserId'] as String? ?? '',
      inviterUserId: json['inviterUserId'] as String? ?? '',
      inviteeUserName: json['inviteeUserName'] as String?,
      inviterUserName: json['inviterUserName'] as String?,
      status: InvitationStatus.values[(json['status'] as int?) ?? 0],
      creationTime: json['creationTime'] as String? ?? '',
    );
  }
}

/// 会议聊天消息
class MeetingChatMessageDto {
  final String id;
  final String meetingId;
  final String? senderId;
  final String senderName;
  final String content;
  final String sentAt;

  const MeetingChatMessageDto({
    required this.id,
    required this.meetingId,
    this.senderId,
    required this.senderName,
    required this.content,
    required this.sentAt,
  });

  factory MeetingChatMessageDto.fromJson(Map<String, dynamic> json) {
    return MeetingChatMessageDto(
      id: json['id'] as String? ?? '',
      meetingId: json['meetingId'] as String? ?? '',
      senderId: json['senderId'] as String?,
      senderName: json['senderName'] as String? ?? '',
      content: json['content'] as String? ?? '',
      sentAt: json['sentAt'] as String? ?? '',
    );
  }
}

/// 参与者统计信息
class ParticipantStatDto {
  final String userId;
  final String? userName;
  final String role;
  final String? joinTime;
  final String? leaveTime;
  final int? durationSeconds;

  const ParticipantStatDto({
    required this.userId,
    this.userName,
    required this.role,
    this.joinTime,
    this.leaveTime,
    this.durationSeconds,
  });

  factory ParticipantStatDto.fromJson(Map<String, dynamic> json) {
    return ParticipantStatDto(
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String?,
      role: json['role'] as String? ?? 'Participant',
      joinTime: json['joinTime'] as String?,
      leaveTime: json['leaveTime'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
    );
  }

  /// 格式化参会时长
  String get formattedDuration {
    if (durationSeconds == null || durationSeconds == 0) return '-';
    final m = (durationSeconds! ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds! % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// 会议统计 DTO
class MeetingStatisticsDto {
  final String meetingTitle;
  final String? startTime;
  final String? endTime;
  final int totalParticipants;
  final int totalDurationMinutes;
  final List<ParticipantStatDto> participants;

  const MeetingStatisticsDto({
    required this.meetingTitle,
    this.startTime,
    this.endTime,
    required this.totalParticipants,
    required this.totalDurationMinutes,
    required this.participants,
  });

  factory MeetingStatisticsDto.fromJson(Map<String, dynamic> json) {
    return MeetingStatisticsDto(
      meetingTitle: json['meetingTitle'] as String? ?? '',
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      totalParticipants: json['totalParticipants'] as int? ?? 0,
      totalDurationMinutes: json['totalDurationMinutes'] as int? ?? 0,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) =>
                  ParticipantStatDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// 录制记录 DTO
class MeetingRecordingDto {
  final String id;
  final int status;
  final String filePath;
  final int? durationSeconds;
  final String creationTime;

  const MeetingRecordingDto({
    required this.id,
    required this.status,
    required this.filePath,
    this.durationSeconds,
    required this.creationTime,
  });

  factory MeetingRecordingDto.fromJson(Map<String, dynamic> json) {
    return MeetingRecordingDto(
      id: json['id'] as String? ?? '',
      status: json['status'] as int? ?? 0,
      filePath: json['filePath'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int?,
      creationTime: json['creationTime'] as String? ?? '',
    );
  }
}
