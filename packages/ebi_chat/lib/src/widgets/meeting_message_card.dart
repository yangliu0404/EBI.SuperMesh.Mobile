import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/models/meeting_models.dart';
import 'package:ebi_chat/src/providers/meeting_providers.dart';
import 'package:ebi_chat/src/pages/meeting_room_page.dart';

/// Renders a meeting invitation card inside a chat bubble.
/// Displays meeting title, number, type, and a join button.
class MeetingMessageCard extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const MeetingMessageCard({
    super.key,
    required this.message,
    this.isMe = false,
  });

  @override
  ConsumerState<MeetingMessageCard> createState() => _MeetingMessageCardState();
}

class _MeetingMessageCardState extends ConsumerState<MeetingMessageCard> {
  bool _isEnded = false;
  bool _isJoining = false;

  Map<String, dynamic>? get _meetingData {
    try {
      final content = widget.message.content;
      if (content.startsWith('{')) {
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (_) {}
    return widget.message.extraProperties;
  }

  // Support both PascalCase (from web/backend) and camelCase keys
  String _getTitle(BuildContext context) => (_meetingData?['MeetingTitle'] ?? _meetingData?['title'] ?? widget.message.content) as String? ?? context.L('MeetingInvitation');
  String get _meetingNo => (_meetingData?['MeetingNo'] ?? _meetingData?['meetingNo']) as String? ?? '';
  String get _meetingId => (_meetingData?['MeetingId'] ?? _meetingData?['meetingId']) as String? ?? '';
  bool get _hasPassword => (_meetingData?['HasPassword'] ?? _meetingData?['hasPassword']) as bool? ?? false;
  int get _type => (_meetingData?['MeetingType'] ?? _meetingData?['type']) as int? ?? 0;

  Future<void> _joinMeeting() async {
    if (_meetingId.isEmpty || _isJoining) return;
    setState(() => _isJoining = true);

    try {
      final api = ref.read(meetingApiServiceProvider);
      final result = await api.joinMeeting(_meetingId);

      if (!mounted) return;

      if (result.isWaiting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在等待主持人准入...')),
        );
      } else if (result.token != null && result.token!.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MeetingRoomPage(
            meeting: result.meeting,
            token: result.token!,
            liveKitServerUrl: result.liveKitServerUrl,
            roomName: result.roomName,
          ),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      // Meeting may have ended
      if (e.toString().contains('ended') || e.toString().contains('404')) {
        setState(() => _isEnded = true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScheduled = _type == 1;

    return Container(
      width: 230,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.white.withValues(alpha: 0.15)
            : EbiColors.bgMeshWork,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.videocam_rounded,
                size: 18,
                color: widget.isMe ? Colors.white : EbiColors.primaryBlue,
              ),
              const SizedBox(width: 6),
              Text(
                isScheduled ? context.L('ScheduledMeeting') : context.L('InstantMeeting'),
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isMe ? Colors.white70 : EbiColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            _getTitle(context),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: widget.isMe ? Colors.white : EbiColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Meeting number
          if (_meetingNo.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.tag,
                  size: 14,
                  color: widget.isMe ? Colors.white54 : EbiColors.textHint,
                ),
                const SizedBox(width: 4),
                Text(
                  _meetingNo,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isMe ? Colors.white54 : EbiColors.textSecondary,
                  ),
                ),
                if (_hasPassword) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.lock_outline,
                    size: 13,
                    color: widget.isMe ? Colors.white54 : EbiColors.textHint,
                  ),
                ],
              ],
            ),
          const SizedBox(height: 10),
          // Join button
          SizedBox(
            width: double.infinity,
            height: 34,
            child: ElevatedButton(
              onPressed: _isEnded || _isJoining ? null : _joinMeeting,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEnded
                    ? Colors.grey
                    : EbiColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.zero,
              ),
              child: _isJoining
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEnded ? '会议已结束' : '加入会议',
                      style: const TextStyle(fontSize: 13),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
