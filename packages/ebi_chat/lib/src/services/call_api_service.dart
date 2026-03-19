import 'package:flutter/foundation.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/call_models.dart';

/// REST API service for call operations (mirrors Web `useCallApi`).
///
/// Endpoints:
/// - POST /api/rtc/calls          → create call
/// - POST /api/rtc/calls/{id}/join → join call (被叫)
/// - PUT  /api/rtc/calls/{id}/end  → end call
class CallApiService {
  final ApiClient _apiClient;

  CallApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Create a new call. Returns LiveKit token info.
  Future<CallTokenResult> createCall({
    required CallType callType,
    required ConversationType conversationType,
    String? targetUserId,
    int? groupId,
  }) async {
    final response = await _apiClient.post(
      '/api/rtc/calls',
      data: {
        'callType': callType.index,
        'conversationType': conversationType.index,
        if (targetUserId != null) 'targetUserId': targetUserId,
        if (groupId != null) 'groupId': groupId,
      },
    );
    final rawData = response.data as Map<String, dynamic>;
    debugPrint('[CallApi] createCall raw response: $rawData');
    // ABP wraps the actual result in a 'result' field
    final data = (rawData['result'] as Map<String, dynamic>?) ?? rawData;
    return CallTokenResult.fromJson(data);
  }

  /// Join an existing call (被叫接听时调用).
  Future<CallTokenResult> joinCall(String callRecordId) async {
    final response = await _apiClient.post(
      '/api/rtc/calls/$callRecordId/join',
    );
    final rawData = response.data as Map<String, dynamic>;
    final data = (rawData['result'] as Map<String, dynamic>?) ?? rawData;
    return CallTokenResult.fromJson(data);
  }

  /// End a call and optionally set a terminal status.
  Future<void> endCall(String callRecordId, {int? status}) async {
    final queryStr = status != null ? '?status=$status' : '';
    await _apiClient.put(
      '/api/rtc/calls/$callRecordId/end$queryStr',
    );
  }
}
