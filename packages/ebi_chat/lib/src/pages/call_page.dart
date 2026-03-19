import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ebi_chat/src/models/call_models.dart';
import 'package:ebi_chat/src/providers/call_providers.dart';

/// Full-screen active call string (Video / Voice).
class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key});

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;
  bool _isLocalSmall = true;
  Offset _pipPosition = const Offset(20, 20);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final activeCall = ref.read(callStateProvider).activeCall;
      if (activeCall != null && activeCall.connectTime != null) {
        setState(() {
          _callDuration = DateTime.now().difference(activeCall.connectTime!);
        });
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    // If it's over an hour
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callStateProvider);
    final activeCall = callState.activeCall;

    // Auto close if the call ended.
    if (activeCall == null || activeCall.status != CallStatus.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        } catch (_) {}
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    // Pop if call was minimized to floating.
    if (callState.isCallFloating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        } catch (_) {}
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    final isVideo = activeCall.callType == CallType.video;
    final otherName = activeCall.direction == CallDirection.outgoing
        ? activeCall.targetUserName
        : activeCall.callerUserName;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1F2937), Color(0xFF111827), Colors.black],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              isVideo
                  ? _buildVideoUI(otherName ?? '')
                  : _buildVoiceUI(otherName ?? ''),
              // Minimize button (top-left)
              Positioned(
                top: 8,
                left: 16,
                child: GestureDetector(
                  onTap: () {
                    ref.read(callStateProvider.notifier).minimizeCall();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.close_fullscreen,
                      size: 20,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceUI(String otherName) {
    return Column(
      children: [
        const SizedBox(height: 60),
        // Avatar Placeholder
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF2B3245),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 48, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          otherName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _formatDuration(_callDuration),
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 18),
        ),
        const Spacer(),
        _buildControls(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildVideoUI(String otherName) {
    return Stack(
      children: [
        // Fullscreen Background Video
        Positioned.fill(
          child: _isLocalSmall
              ? _buildVideoView(isLocal: false)
              : _buildVideoView(isLocal: true),
        ),
        // PiP Foreground Video (Draggable)
        Positioned(
          top: _pipPosition.dy,
          left: _pipPosition.dx,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                final size = MediaQuery.of(context).size;
                double newLeft = _pipPosition.dx + details.delta.dx;
                double newTop = _pipPosition.dy + details.delta.dy;
                // Clamp within safe area and bounds
                newLeft = newLeft.clamp(16.0, size.width - 116.0);
                newTop = newTop.clamp(16.0, size.height - 200.0);
                _pipPosition = Offset(newLeft, newTop);
              });
            },
            onTap: () {
              setState(() {
                _isLocalSmall = !_isLocalSmall;
              });
            },
            child: Container(
              width: 100,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: _isLocalSmall
                  ? _buildVideoView(isLocal: true)
                  : _buildVideoView(isLocal: false),
            ),
          ),
        ),
        // Header (name + duration)
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  otherName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_callDuration),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        // Controls (Bottom)
        Positioned(bottom: 40, left: 0, right: 0, child: _buildControls()),
      ],
    );
  }

  Widget _buildVideoView({required bool isLocal}) {
    final liveKitService = ref.watch(liveKitServiceProvider);

    if (isLocal) {
      final callState = ref.watch(callStateProvider);
      if (callState.isCameraOff) {
        return Container(
          color: const Color(0xFF1F2937),
          alignment: Alignment.center,
          child: const Icon(
            Icons.videocam_off,
            color: Colors.white54,
            size: 32,
          ),
        );
      }

      final localParticipant = liveKitService.localParticipant;
      final trackPub = localParticipant?.videoTrackPublications.firstOrNull;

      if (trackPub != null && trackPub.track != null) {
        return VideoTrackRenderer(trackPub.track as VideoTrack);
      }

      // Fallback
      return Container(
        color: const Color(0xFF1F2937),
        alignment: Alignment.center,
        child: const Icon(Icons.videocam, color: Colors.white54, size: 32),
      );
    } else {
      return StreamBuilder<RemoteParticipant?>(
        stream: liveKitService.remoteParticipantStream,
        initialData: liveKitService.remoteParticipant,
        builder: (context, snapshot) {
          final participant = snapshot.data;
          if (participant == null) {
            return Container(
              color: const Color(0xFF111827),
              child: const Center(
                child: Text(
                  '等待对方加入...',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            );
          }

          final trackPub = participant.videoTrackPublications.firstOrNull;
          if (trackPub != null && trackPub.track != null) {
            return VideoTrackRenderer(trackPub.track as VideoTrack);
          }

          return Container(
            color: const Color(0xFF111827),
            child: const Center(
              child: Text('用户未开启画面', style: TextStyle(color: Colors.white54)),
            ),
          );
        },
      );
    }
  }

  Widget _buildControls() {
    final callState = ref.watch(callStateProvider);
    final isVideo = callState.activeCall?.callType == CallType.video;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mic Toggle
          _buildControlButton(
            icon: callState.isMicMuted ? Icons.mic_off : Icons.mic,
            isActive: !callState.isMicMuted,
            onTap: () => ref.read(callStateProvider.notifier).toggleMic(),
          ),
          if (isVideo)
            // Camera Toggle
            _buildControlButton(
              icon: callState.isCameraOff ? Icons.videocam_off : Icons.videocam,
              isActive: !callState.isCameraOff,
              onTap: () => ref.read(callStateProvider.notifier).toggleCamera(),
            ),
          if (isVideo)
            // Flip Camera
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              isActive: true, // Always active style
              onTap: () => ref.read(callStateProvider.notifier).switchCamera(),
            ),
          if (!isVideo)
            // Speaker Toggle
            _buildControlButton(
              icon: callState.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
              isActive: callState.isSpeakerOn,
              onTap: () => ref.read(callStateProvider.notifier).toggleSpeaker(),
            ),
          // End Call
          _buildControlButton(
            icon: Icons.call_end,
            bgColor: const Color(0xFFEF4444),
            iconColor: Colors.white,
            onTap: () => ref.read(callStateProvider.notifier).endActiveCall(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    bool isActive = false,
    Color? bgColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final defaultBg = isActive
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.1);
    final defaultIconColor = isActive ? Colors.white : Colors.white54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bgColor ?? defaultBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 28, color: iconColor ?? defaultIconColor),
      ),
    );
  }
}
