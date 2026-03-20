import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/models/meeting_models.dart';
import 'package:ebi_chat/src/repository/chat_repository.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';
import 'package:ebi_chat/src/providers/meeting_providers.dart';

/// Sends a meeting invitation as an IM message to a user or group.
/// This mirrors the web's `im:send-meeting-invitation` event handler.
Future<void> sendMeetingInvitationMessage({
  required WidgetRef ref,
  required MeetingDto meeting,
  required String targetUserId,
  String? groupId,
}) async {
  final auth = ref.read(authProvider);
  final currentUserId = auth.user?.id ?? '';
  final currentUserName = auth.user?.name ?? '';
  final repo = ref.read(chatRepositoryProvider);

  final msg = ImChatMessage(
    messageId: '',
    formUserId: currentUserId,
    formUserName: currentUserName,
    toUserId: groupId == null ? targetUserId : null,
    groupId: groupId ?? '',
    content: meeting.title,
    sendTime: DateTime.now().toUtc().toIso8601String(),
    messageType: ImMessageType.meeting.value,
    source: ImMessageSourceType.user.value,
    extraProperties: {
      'MeetingNo': meeting.meetingNo,
      'MeetingTitle': meeting.title,
      'MeetingId': meeting.id,
      'HasPassword': meeting.hasPassword,
      'MeetingType': meeting.type.index,
      if (meeting.scheduledStartTime != null)
        'ScheduledStartTime': meeting.scheduledStartTime,
    },
  );

  await repo.sendMessage(msg);
}

/// Invites a user to a meeting via API and sends an IM message card.
Future<void> inviteUserToMeeting({
  required WidgetRef ref,
  required MeetingDto meeting,
  required String userId,
  String? userName,
}) async {
  final api = ref.read(meetingApiServiceProvider);

  // 1. API invitation
  await api.inviteToMeeting(meeting.id, userId, userName: userName);

  // 2. Send IM message card
  await sendMeetingInvitationMessage(
    ref: ref,
    meeting: meeting,
    targetUserId: userId,
  );
}
