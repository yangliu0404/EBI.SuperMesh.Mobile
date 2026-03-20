import 'package:flutter/foundation.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/meeting_models.dart';

/// REST API service for meeting operations (mirrors Web `useMeetingApi`).
///
/// Core endpoints:
/// - POST /api/rtc/meetings              → create meeting
/// - POST /api/rtc/meetings/{id}/join    → join meeting
/// - PUT  /api/rtc/meetings/{id}/end     → end meeting
/// - GET  /api/rtc/meetings/my           → list my meetings
/// - GET  /api/rtc/meetings/by-no/{no}   → query by meeting number
class MeetingApiService {
  final ApiClient _apiClient;

  MeetingApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Extract ABP WrapResult `result` field.
  Map<String, dynamic> _unwrap(dynamic responseData) {
    final raw = responseData as Map<String, dynamic>;
    return (raw['result'] as Map<String, dynamic>?) ?? raw;
  }

  /// Extract ABP WrapResult `result` as a list.
  List<dynamic> _unwrapList(dynamic responseData) {
    final raw = responseData as Map<String, dynamic>;
    return (raw['result'] as List<dynamic>?) ?? [];
  }

  // ==================== 核心操作 ====================

  /// 创建会议
  Future<MeetingDto> createMeeting(CreateMeetingDto input) async {
    final response = await _apiClient.post(
      '/api/rtc/meetings',
      data: input.toJson(),
    );
    debugPrint('[MeetingApi] createMeeting raw: ${response.data}');
    return MeetingDto.fromJson(_unwrap(response.data));
  }

  /// 加入会议
  Future<JoinMeetingResultDto> joinMeeting(
    String id, {
    String? password,
  }) async {
    final query = password != null ? '?password=${Uri.encodeComponent(password)}' : '';
    final response = await _apiClient.post(
      '/api/rtc/meetings/$id/join$query',
    );
    debugPrint('[MeetingApi] joinMeeting raw: ${response.data}');
    return JoinMeetingResultDto.fromJson(_unwrap(response.data));
  }

  /// 结束会议（仅主持人）
  Future<void> endMeeting(String id) async {
    await _apiClient.put('/api/rtc/meetings/$id/end');
  }

  /// 获取会议信息
  Future<MeetingDto> getMeeting(String id) async {
    final response = await _apiClient.get('/api/rtc/meetings/$id');
    return MeetingDto.fromJson(_unwrap(response.data));
  }

  /// 通过会议号查询
  Future<MeetingDto?> getMeetingByNo(String meetingNo) async {
    try {
      final response =
          await _apiClient.get('/api/rtc/meetings/by-no/$meetingNo');
      return MeetingDto.fromJson(_unwrap(response.data));
    } catch (e) {
      debugPrint('[MeetingApi] getMeetingByNo error: $e');
      return null;
    }
  }

  /// 获取当前用户的会议列表
  Future<List<MeetingDto>> getMyMeetings({
    int? status,
    String? fromDate,
    String? toDate,
    int? maxResultCount,
  }) async {
    final response = await _apiClient.get(
      '/api/rtc/meetings/my',
      queryParameters: {
        if (status != null) 'status': status,
        if (fromDate != null) 'fromDate': fromDate,
        if (toDate != null) 'toDate': toDate,
        if (maxResultCount != null) 'maxResultCount': maxResultCount,
      },
    );
    final list = _unwrapList(response.data);
    return list
        .map((e) => MeetingDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==================== 预约会议 ====================

  /// 主持人手动开始预约会议
  Future<MeetingDto> startScheduledMeeting(String id) async {
    final response = await _apiClient.put('/api/rtc/meetings/$id/start');
    return MeetingDto.fromJson(_unwrap(response.data));
  }

  // ==================== 准入控制 ====================

  /// 等待中的参与者轮询准入状态
  Future<AdmissionStatusDto> checkAdmission(String id) async {
    final response =
        await _apiClient.get('/api/rtc/meetings/$id/check-admission');
    return AdmissionStatusDto.fromJson(_unwrap(response.data));
  }

  /// 获取等待准入的参与者列表（主持人调用）
  Future<List<WaitingParticipantDto>> getWaitingParticipants(
      String id) async {
    final response = await _apiClient.get('/api/rtc/meetings/$id/waiting');
    final list = _unwrapList(response.data);
    return list
        .map((e) => WaitingParticipantDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 主持人准入等待中的参与者
  Future<void> admitParticipant(String id, String userId) async {
    await _apiClient.put('/api/rtc/meetings/$id/admit/$userId');
  }

  /// 主持人拒绝等待中的参与者
  Future<void> denyParticipant(String id, String userId) async {
    await _apiClient.put('/api/rtc/meetings/$id/deny/$userId');
  }

  // ==================== 主持人管理 ====================

  /// 转移主持人并离开会议
  Future<MeetingDto> transferHostAndLeave(
    String id, {
    String? newHostUserId,
  }) async {
    final query = newHostUserId != null ? '?newHostUserId=${Uri.encodeComponent(newHostUserId)}' : '';
    final response = await _apiClient.put(
      '/api/rtc/meetings/$id/transfer-host$query',
    );
    return MeetingDto.fromJson(_unwrap(response.data));
  }

  /// 移除参与者
  Future<void> kickParticipant(String id, String userId) async {
    await _apiClient.put('/api/rtc/meetings/$id/kick/$userId');
  }

  // ==================== 邀请管理 ====================

  /// 邀请用户参加会议
  Future<MeetingInvitationDto> inviteToMeeting(
    String meetingId,
    String userId, {
    String? userName,
  }) async {
    final response = await _apiClient.post(
      '/api/rtc/meetings/$meetingId/invitations',
      data: {
        'userId': userId,
        if (userName != null) 'userName': userName,
      },
    );
    return MeetingInvitationDto.fromJson(_unwrap(response.data));
  }

  /// 获取会议邀请列表
  Future<List<MeetingInvitationDto>> getInvitations(String meetingId) async {
    final response =
        await _apiClient.get('/api/rtc/meetings/$meetingId/invitations');
    final list = _unwrapList(response.data);
    return list
        .map((e) => MeetingInvitationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 接受邀请
  Future<void> acceptInvitation(String meetingId) async {
    await _apiClient.put('/api/rtc/meetings/$meetingId/invitations/accept');
  }

  /// 拒绝邀请
  Future<void> declineInvitation(String meetingId) async {
    await _apiClient.put('/api/rtc/meetings/$meetingId/invitations/decline');
  }

  // ==================== 统计与回顾 ====================

  /// 获取会议参与者统计
  Future<MeetingStatisticsDto> getStatistics(String meetingId) async {
    final response =
        await _apiClient.get('/api/rtc/meetings/$meetingId/statistics');
    return MeetingStatisticsDto.fromJson(_unwrap(response.data));
  }

  /// 获取会议中的参与者 userId 列表
  Future<List<String>> getParticipantUserIds(String meetingId) async {
    final response =
        await _apiClient.get('/api/rtc/meetings/$meetingId/participants');
    final list = _unwrapList(response.data);
    return list.map((e) => e.toString()).toList();
  }

  // ==================== 会议聊天 ====================

  /// 发送会议聊天消息
  Future<MeetingChatMessageDto> sendChatMessage(
    String meetingId, {
    required String content,
    required String senderName,
  }) async {
    final response = await _apiClient.post(
      '/api/rtc/meetings/$meetingId/chat',
      data: {'content': content, 'senderName': senderName},
    );
    return MeetingChatMessageDto.fromJson(_unwrap(response.data));
  }

  /// 获取会议聊天历史
  Future<List<MeetingChatMessageDto>> getChatHistory(String meetingId) async {
    final response =
        await _apiClient.get('/api/rtc/meetings/$meetingId/chat');
    final list = _unwrapList(response.data);
    return list
        .map((e) => MeetingChatMessageDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==================== 录制 ====================

  /// 开始录制
  Future<Map<String, String>> startRecording(String meetingId) async {
    final response = await _apiClient.post(
      '/api/rtc/meetings/$meetingId/recording/start',
    );
    final data = _unwrap(response.data);
    return {
      'id': data['id'] as String? ?? '',
      'egressId': data['egressId'] as String? ?? '',
    };
  }

  /// 停止录制
  Future<void> stopRecording(String meetingId) async {
    await _apiClient.put('/api/rtc/meetings/$meetingId/recording/stop');
  }

  /// 获取录制列表
  Future<List<MeetingRecordingDto>> getRecordings(String meetingId) async {
    final response =
        await _apiClient.get('/api/rtc/meetings/$meetingId/recordings');
    final list = _unwrapList(response.data);
    return list
        .map((e) => MeetingRecordingDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ==================== 联合主持人 ====================

  /// 设置参与者为联合主持人
  Future<void> setCoHost(String meetingId, String userId) async {
    await _apiClient.put('/api/rtc/meetings/$meetingId/co-host/$userId');
  }

  /// 取消联合主持人角色
  Future<void> removeCoHost(String meetingId, String userId) async {
    await _apiClient.delete('/api/rtc/meetings/$meetingId/co-host/$userId');
  }

  // ==================== 白板 ====================

  /// 获取白板快照 (base64)
  Future<String?> getWhiteboardSnapshot(String meetingId) async {
    try {
      final response =
          await _apiClient.get('/api/rtc/meetings/$meetingId/whiteboard');
      final data = _unwrap(response.data);
      return data['snapshotBase64'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 保存白板快照 (base64)
  Future<void> saveWhiteboardSnapshot(
      String meetingId, String snapshotBase64) async {
    await _apiClient.post(
      '/api/rtc/meetings/$meetingId/whiteboard',
      data: {'snapshotBase64': snapshotBase64},
    );
  }
}
