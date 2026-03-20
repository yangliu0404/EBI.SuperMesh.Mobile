import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ebi_chat/src/models/meeting_models.dart';
import 'package:ebi_chat/src/pages/meeting_room_page.dart';

/// State for an active minimized meeting — holds the live Room instance.
class ActiveMeetingInfo {
  final MeetingDto meeting;
  final String token;
  final String liveKitServerUrl;
  final String roomName;
  final DateTime joinTime;
  final Room? room; // Preserved LiveKit room — stays connected during minimize

  const ActiveMeetingInfo({
    required this.meeting,
    required this.token,
    required this.liveKitServerUrl,
    required this.roomName,
    required this.joinTime,
    this.room,
  });
}

class ActiveMeetingNotifier extends StateNotifier<ActiveMeetingInfo?> {
  ActiveMeetingNotifier() : super(null);

  void setActive(ActiveMeetingInfo info) => state = info;
  void clear() => state = null;
}

final activeMeetingProvider =
    StateNotifierProvider<ActiveMeetingNotifier, ActiveMeetingInfo?>((ref) {
  return ActiveMeetingNotifier();
});

/// Draggable floating window for minimized meeting.
/// Place in root Stack alongside CallFloatWindow.
class MeetingFloatWindow extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState>? navigatorKey;

  const MeetingFloatWindow({super.key, this.navigatorKey});

  @override
  ConsumerState<MeetingFloatWindow> createState() => _MeetingFloatWindowState();
}

class _MeetingFloatWindowState extends ConsumerState<MeetingFloatWindow> {
  Offset _position = const Offset(20, 140);
  Timer? _timer;
  Duration _duration = Duration.zero;
  bool _isExpanding = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final info = ref.read(activeMeetingProvider);
      if (info != null && mounted) {
        setState(() => _duration = DateTime.now().difference(info.joinTime));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d.inHours > 0) return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void _expand() {
    if (_isExpanding) return;
    _isExpanding = true;
    final info = ref.read(activeMeetingProvider);
    if (info == null) return;

    ref.read(activeMeetingProvider.notifier).clear();

    final nav = widget.navigatorKey?.currentState ?? Navigator.of(context, rootNavigator: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nav.push(MaterialPageRoute(
        builder: (_) => MeetingRoomPage(
          meeting: info.meeting,
          token: info.token,
          liveKitServerUrl: info.liveKitServerUrl,
          roomName: info.roomName,
          existingRoom: info.room, // Pass preserved room
        ),
        fullscreenDialog: true,
      )).then((_) => _isExpanding = false);
    });
  }

  void _leaveMeeting() {
    final info = ref.read(activeMeetingProvider);
    info?.room?.disconnect();
    ref.read(activeMeetingProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(activeMeetingProvider);
    if (info == null) return const SizedBox.shrink();

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            _position += d.delta;
            final size = MediaQuery.of(context).size;
            _position = Offset(_position.dx.clamp(0, size.width - 180), _position.dy.clamp(0, size.height - 80));
          });
        },
        onTap: _expand,
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF009FE3).withValues(alpha: 0.3), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFF111827),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.videocam, color: Color(0xFF009FE3), size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        info.meeting.title,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 28, height: 28,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.open_in_full, size: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_duration), style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12)),
                    GestureDetector(
                      onTap: _leaveMeeting,
                      child: Container(
                        width: 28, height: 28,
                        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                        child: const Icon(Icons.call_end, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
