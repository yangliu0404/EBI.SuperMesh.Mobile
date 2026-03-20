import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/meeting_models.dart';
import 'package:ebi_chat/src/services/meeting_api_service.dart';

// ── Service Provider ──

final meetingApiServiceProvider = Provider<MeetingApiService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return MeetingApiService(apiClient: apiClient);
});

// ── Meeting List State ──

class MeetingListState {
  final List<MeetingDto> meetings;
  final bool isLoading;
  final String? error;

  const MeetingListState({
    this.meetings = const [],
    this.isLoading = false,
    this.error,
  });

  MeetingListState copyWith({
    List<MeetingDto>? meetings,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return MeetingListState(
      meetings: meetings ?? this.meetings,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Meetings that are currently in progress and the user is a participant.
  List<MeetingDto> get activeMeetings =>
      meetings.where((m) => m.status == MeetingStatus.inProgress).toList();
}

class MeetingListNotifier extends StateNotifier<MeetingListState> {
  final MeetingApiService _api;

  MeetingListNotifier(this._api) : super(const MeetingListState());

  Future<void> loadMeetings() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final meetings = await _api.getMyMeetings(maxResultCount: 50);
      state = state.copyWith(meetings: meetings, isLoading: false);
    } catch (e) {
      debugPrint('[MeetingList] loadMeetings error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => loadMeetings();
}

final meetingListProvider =
    StateNotifierProvider<MeetingListNotifier, MeetingListState>((ref) {
  final api = ref.read(meetingApiServiceProvider);
  return MeetingListNotifier(api);
});

// ── Left Meeting State (for rejoin banner) ──

class LeftMeetingInfo {
  final String meetingId;
  final String meetingNo;
  final String title;

  const LeftMeetingInfo({
    required this.meetingId,
    required this.meetingNo,
    required this.title,
  });
}

class LeftMeetingNotifier extends StateNotifier<LeftMeetingInfo?> {
  LeftMeetingNotifier() : super(null);

  void setLeftMeeting(LeftMeetingInfo info) => state = info;
  void clear() => state = null;
}

final leftMeetingProvider =
    StateNotifierProvider<LeftMeetingNotifier, LeftMeetingInfo?>((ref) {
  return LeftMeetingNotifier();
});
