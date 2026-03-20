import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/poll_models.dart';

/// REST API service for meeting polls (mirrors Web `usePollApi`).
class PollApiService {
  final ApiClient _apiClient;

  PollApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Map<String, dynamic> _unwrap(dynamic data) {
    final raw = data as Map<String, dynamic>;
    return (raw['result'] as Map<String, dynamic>?) ?? raw;
  }

  List<dynamic> _unwrapList(dynamic data) {
    final raw = data as Map<String, dynamic>;
    return (raw['result'] as List<dynamic>?) ?? [];
  }

  /// Create a new poll in a meeting.
  Future<MeetingPollDto> createPoll(String meetingId, CreatePollDto input) async {
    final resp = await _apiClient.post(
      '/api/rtc/meetings/$meetingId/polls',
      data: input.toJson(),
    );
    return MeetingPollDto.fromJson(_unwrap(resp.data));
  }

  /// Vote on a poll.
  Future<void> vote(String meetingId, String pollId, List<String> optionIds) async {
    await _apiClient.post(
      '/api/rtc/meetings/$meetingId/polls/$pollId/vote',
      data: {'optionIds': optionIds},
    );
  }

  /// Close a poll (host only).
  Future<void> closePoll(String meetingId, String pollId) async {
    await _apiClient.put('/api/rtc/meetings/$meetingId/polls/$pollId/close');
  }

  /// Get all polls for a meeting.
  Future<List<MeetingPollDto>> getPolls(String meetingId) async {
    final resp = await _apiClient.get('/api/rtc/meetings/$meetingId/polls');
    final list = _unwrapList(resp.data);
    return list.map((e) => MeetingPollDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get a single poll result.
  Future<MeetingPollDto> getPollResult(String meetingId, String pollId) async {
    final resp = await _apiClient.get('/api/rtc/meetings/$meetingId/polls/$pollId');
    return MeetingPollDto.fromJson(_unwrap(resp.data));
  }
}
