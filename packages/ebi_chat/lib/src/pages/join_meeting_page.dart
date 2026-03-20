import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/models/meeting_models.dart';
import 'package:ebi_chat/src/providers/meeting_providers.dart';
import 'package:ebi_chat/src/pages/meeting_room_page.dart';

/// Join meeting by meeting number — with device preview.
class JoinMeetingPage extends ConsumerStatefulWidget {
  const JoinMeetingPage({super.key});

  @override
  ConsumerState<JoinMeetingPage> createState() => _JoinMeetingPageState();
}

class _JoinMeetingPageState extends ConsumerState<JoinMeetingPage> {
  final _controller = TextEditingController();
  bool _isMicMuted = false;
  bool _isCameraOff = true;
  bool _isJoining = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _joinMeeting() async {
    final meetingNo = _controller.text.trim();
    if (meetingNo.isEmpty) return;

    setState(() => _isJoining = true);
    final api = ref.read(meetingApiServiceProvider);

    try {
      // Look up meeting by number
      final meeting = await api.getMeetingByNo(meetingNo);
      if (meeting == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到该会议号对应的会议')),
        );
        setState(() => _isJoining = false);
        return;
      }

      // Check if needs password
      if (meeting.hasPassword) {
        if (!mounted) return;
        final password = await _showPasswordDialog();
        if (password == null) {
          setState(() => _isJoining = false);
          return;
        }
        final result = await api.joinMeeting(meeting.id, password: password);
        if (!mounted) return;
        _handleJoinResult(result, meeting);
      } else {
        final result = await api.joinMeeting(meeting.id);
        if (!mounted) return;
        _handleJoinResult(result, meeting);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入会议失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _handleJoinResult(JoinMeetingResultDto result, MeetingDto meeting) {
    if (result.isWaiting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在等待主持人准入...')),
      );
      return;
    }
    if (result.token != null && result.token!.isNotEmpty) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => MeetingRoomPage(
          meeting: result.meeting,
          token: result.token!,
          liveKitServerUrl: result.liveKitServerUrl,
          roomName: result.roomName,
          initialMicMuted: _isMicMuted,
          initialCameraOff: _isCameraOff,
        ),
      ));
    }
    ref.read(meetingListProvider.notifier).refresh();
  }

  Future<String?> _showPasswordDialog() {
    final pwController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入会议密码'),
        content: TextField(
          controller: pwController,
          obscureText: true,
          decoration: const InputDecoration(hintText: '请输入密码'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, pwController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const userName = 'Me';

    return Scaffold(
      backgroundColor: EbiColors.bgMeshWork,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: EbiColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '加入会议',
          style: TextStyle(color: EbiColors.textPrimary, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Meeting number input
              const Text(
                '请输入会议号',
                style: TextStyle(
                  fontSize: 16,
                  color: EbiColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 4),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  hintText: '8位会议号',
                  hintStyle: TextStyle(
                    color: EbiColors.textHint,
                    fontSize: 24,
                    letterSpacing: 4,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: EbiColors.primaryBlue, width: 2),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: EbiColors.primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // User avatar preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: EbiColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: EbiColors.primaryBlue.withValues(alpha: 0.1),
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 36,
                          color: EbiColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Media controls
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: EbiColors.bgMeshWork,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MediaButton(
                            icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                            label: _isMicMuted ? '已静音' : '静音',
                            isActive: !_isMicMuted,
                            onTap: () =>
                                setState(() => _isMicMuted = !_isMicMuted),
                          ),
                          const SizedBox(width: 24),
                          _MediaButton(
                            icon: _isCameraOff
                                ? Icons.videocam_off
                                : Icons.videocam,
                            label: _isCameraOff ? '开摄像头' : '关摄像头',
                            isActive: !_isCameraOff,
                            onTap: () =>
                                setState(() => _isCameraOff = !_isCameraOff),
                          ),
                          const SizedBox(width: 24),
                          _MediaButton(
                            icon: Icons.volume_up,
                            label: '扬声器',
                            isActive: true,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Join button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _joinMeeting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EbiColors.primaryBlue,
                    foregroundColor: EbiColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    disabledBackgroundColor:
                        EbiColors.primaryBlue.withValues(alpha: 0.5),
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: EbiColors.white,
                          ),
                        )
                      : const Text(
                          '进入会议',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? EbiColors.textPrimary : EbiColors.textHint,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? EbiColors.textPrimary : EbiColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}
