import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ebi_chat/src/models/call_models.dart';
import 'package:ebi_chat/src/providers/call_providers.dart';
import 'package:ebi_chat/src/pages/call_page.dart';

/// A draggable floating window that appears when a call is minimized.
/// Place this widget at the top of your widget tree (e.g., in a Stack in the root).
class CallFloatWindow extends ConsumerStatefulWidget {
  /// Optional navigator key for pushing CallPage when expanded.
  final GlobalKey<NavigatorState>? navigatorKey;

  const CallFloatWindow({super.key, this.navigatorKey});

  @override
  ConsumerState<CallFloatWindow> createState() => _CallFloatWindowState();
}

class _CallFloatWindowState extends ConsumerState<CallFloatWindow>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 80);
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;
  late AnimationController _pulseController;
  bool _isExpanding = false; // Guard against double-tap

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startTimer();
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final activeCall = ref.read(callStateProvider).activeCall;
      if (activeCall?.connectTime != null) {
        if (mounted) {
          setState(() {
            _callDuration = DateTime.now().difference(activeCall!.connectTime!);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _expandToFullscreen() {
    if (_isExpanding) return; // Prevent double-tap
    _isExpanding = true;

    // Capture navigator BEFORE state change causes rebuild.
    final nav =
        widget.navigatorKey?.currentState ??
        Navigator.of(context, rootNavigator: true);

    ref.read(callStateProvider.notifier).expandCall();

    // Push after next frame so the float window hides first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nav
          .push(
            MaterialPageRoute(
              builder: (_) => const CallPage(),
              fullscreenDialog: true,
            ),
          )
          .then((_) {
            // Reset guard when CallPage is popped.
            _isExpanding = false;
          });
    });
  }

  void _endCall() {
    ref.read(callStateProvider.notifier).endActiveCall();
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callStateProvider);
    final visible = callState.hasActiveCall && callState.isCallFloating;

    if (!visible) {
      _isExpanding = false; // Reset when hidden
      return const SizedBox.shrink();
    }

    final isVideo = callState.activeCall?.callType == CallType.video;
    final otherName = callState.activeCall?.direction == CallDirection.outgoing
        ? callState.activeCall?.targetUserName
        : callState.activeCall?.callerUserName;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
            final size = MediaQuery.of(context).size;
            _position = Offset(
              _position.dx.clamp(0, size.width - 180),
              _position.dy.clamp(0, size.height - 80),
            );
          });
        },
        onTap: _expandToFullscreen,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) {
            final glowOpacity = 0.15 + 0.1 * _pulseController.value;
            return Container(
              width: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF4ADE80).withValues(alpha: glowOpacity),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Video Background (if video call)
                  if (isVideo)
                    Positioned.fill(child: _buildRemoteVideoBackground()),
                  // Dark semi-transparent overlay to ensure text readability
                  if (isVideo)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  // Foreground Content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top section — icon + name
                      Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: isVideo
                              ? Colors.transparent
                              : const Color(0xFF111827),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(
                              isVideo ? Icons.videocam : Icons.phone,
                              color: const Color(0xFF4ADE80),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                otherName ?? '通话中',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Expand icon (no separate GestureDetector — outer one handles tap)
                            Container(
                              width: 28,
                              height: 28,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.open_in_full,
                                size: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bottom section — timer + hangup
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_callDuration),
                              style: const TextStyle(
                                color: Color(0xFFD1D5DB),
                                fontSize: 12,
                              ),
                            ),
                            // Hangup button — needs its own GestureDetector
                            GestureDetector(
                              onTap: _endCall,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                                child: Transform.rotate(
                                  angle: 135 * 3.1415926 / 180,
                                  child: const Icon(
                                    Icons.phone,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRemoteVideoBackground() {
    final liveKitService = ref.watch(liveKitServiceProvider);
    return StreamBuilder<RemoteParticipant?>(
      stream: liveKitService.remoteParticipantStream,
      initialData: liveKitService.remoteParticipant,
      builder: (context, snapshot) {
        final participant = snapshot.data;
        if (participant == null) return const SizedBox.shrink();

        final trackPub = participant.videoTrackPublications.firstOrNull;
        if (trackPub != null && trackPub.track != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: VideoTrackRenderer(trackPub.track as VideoTrack),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
