import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/models/meeting_models.dart';
import 'package:ebi_chat/src/providers/meeting_providers.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/services/meeting_invite_service.dart';
import 'package:ebi_chat/src/widgets/meeting_float_window.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:ebi_chat/src/widgets/meeting_poll_panel.dart';
import 'package:ebi_chat/src/widgets/meeting_whiteboard_panel.dart';

/// Enhanced multi-participant meeting room with panels, reactions, and raise hand.
class MeetingRoomPage extends ConsumerStatefulWidget {
  final MeetingDto meeting;
  final String token;
  final String liveKitServerUrl;
  final String roomName;
  final bool initialMicMuted;
  final bool initialCameraOff;
  final Room? existingRoom; // Preserved room from minimize — skip reconnect

  const MeetingRoomPage({
    super.key,
    required this.meeting,
    required this.token,
    required this.liveKitServerUrl,
    required this.roomName,
    this.initialMicMuted = false,
    this.initialCameraOff = false,
    this.existingRoom,
  });

  @override
  ConsumerState<MeetingRoomPage> createState() => _MeetingRoomPageState();
}

class _MeetingRoomPageState extends ConsumerState<MeetingRoomPage> {
  // ── Core State ──
  Timer? _durationTimer;
  Duration _duration = Duration.zero;
  DateTime? _joinTime;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isLeaving = false;
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  final List<RemoteParticipant> _remoteParticipants = [];

  // ── UI Panels ──
  bool _showParticipants = false;
  bool _showChat = false;
  bool _showWhiteboard = false;
  bool _showPolls = false;
  bool _wasKicked = false;
  bool _wasMutedByHost = false;
  String _currentHostUserId = '';
  final Map<String, String> _participantRoles = {}; // identity → 'Host'|'CoHost'|'Participant'
  List<WaitingParticipantDto> _waitingParticipants = [];
  Timer? _waitingPollTimer;
  bool _isHandRaised = false;
  Timer? _handRaiseTimer;
  String? _pinnedIdentity;
  String _layoutMode = 'grid';
  bool _isLandscape = false;

  // ── Network Quality ──
  final Map<String, ConnectionQuality> _connectionQualities = {};

  // ── Captions ──
  bool _captionsEnabled = false;
  final List<_CaptionEntry> _captions = [];

  // ── Chat ──
  final List<_ChatMsg> _chatMessages = [];
  final _chatController = TextEditingController();
  int _unreadChat = 0;

  // ── Emoji Reactions ──
  final List<_FloatingEmoji> _floatingEmojis = [];

  // ── Screen Share ──
  RemoteTrackPublication? _screenShareTrack;

  // ── Whiteboard ──
  final GlobalKey<MeetingWhiteboardPanelState> _whiteboardKey = GlobalKey();
  List<dynamic>? _lastRemoteStrokes; // Cached strokes for when panel reopens

  @override
  void initState() {
    super.initState();
    _isMicMuted = widget.initialMicMuted;
    _isCameraOff = widget.initialCameraOff;
    _currentHostUserId = widget.meeting.hostUserId;
    _connectToRoom();
    _loadChatHistory();
    _startWaitingRoomPoll();
  }

  void _setupRoomListeners(Room room) {
    _listener?.dispose();
    _listener = room.createListener();
  }

  Future<void> _connectToRoom() async {
    // Reuse existing room from minimize (skip reconnect)
    if (widget.existingRoom != null) {
      _room = widget.existingRoom;
      _setupRoomListeners(_room!);
      setState(() {
        _remoteParticipants.addAll(_room!.remoteParticipants.values);
      });
      _joinTime = DateTime.now();
      _startTimer();
      _isMicMuted = !(_room!.localParticipant?.isMicrophoneEnabled() ?? false);
      _isCameraOff = !(_room!.localParticipant?.isCameraEnabled() ?? false);
      return;
    }

    try {
      final room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(dtx: true),
          defaultVideoPublishOptions: VideoPublishOptions(simulcast: true),
        ),
      );

      _setupRoomListeners(room);
      _listener!
        ..on<ParticipantConnectedEvent>((e) {
          setState(() {
            if (!_remoteParticipants.contains(e.participant)) {
              _remoteParticipants.add(e.participant);
            }
          });
        })
        ..on<ParticipantDisconnectedEvent>((e) {
          setState(() {
            _remoteParticipants.remove(e.participant);
            if (_pinnedIdentity == e.participant.identity) _pinnedIdentity = null;
          });
        })
        ..on<TrackSubscribedEvent>((e) {
          if (e.publication.source == TrackSource.screenShareVideo) {
            setState(() => _screenShareTrack = e.publication);
          }
          setState(() {});
        })
        ..on<TrackUnsubscribedEvent>((e) {
          if (e.publication.source == TrackSource.screenShareVideo) {
            setState(() => _screenShareTrack = null);
          }
          setState(() {});
        })
        // Track published/unpublished — when remote adds or removes a track
        ..on<TrackPublishedEvent>((e) {
          setState(() {});
        })
        ..on<TrackUnpublishedEvent>((e) {
          if (e.publication.source == TrackSource.screenShareVideo) {
            setState(() => _screenShareTrack = null);
          }
          setState(() {});
        })
        // Mute/unmute — when remote toggles mic or camera
        ..on<TrackMutedEvent>((e) {
          setState(() {});
        })
        ..on<TrackUnmutedEvent>((e) {
          setState(() {});
        })
        // Local track published — update our own state
        ..on<LocalTrackPublishedEvent>((e) {
          setState(() {});
        })
        ..on<LocalTrackUnpublishedEvent>((e) {
          setState(() {});
        })
        ..on<ParticipantConnectionQualityUpdatedEvent>((e) {
          setState(() {
            _connectionQualities[e.participant.identity ?? ''] = e.connectionQuality;
          });
        })
        ..on<DataReceivedEvent>((e) {
          _handleDataMessage(e);
        })
        ..on<RoomDisconnectedEvent>((e) {
          if (mounted && !_isLeaving) _leave(showMessage: '会议已断开');
        });

      await room.connect(widget.liveKitServerUrl, widget.token);
      _room = room;
      debugPrint('[MeetingRoom] LiveKit connected! localIdentity=${room.localParticipant?.identity}, remoteCount=${room.remoteParticipants.length}');

      setState(() {
        _remoteParticipants.addAll(room.remoteParticipants.values);
        // Check for existing screen share
        for (final p in room.remoteParticipants.values) {
          for (final pub in p.trackPublications.values) {
            if (pub.source == TrackSource.screenShareVideo && pub.track != null) {
              _screenShareTrack = pub;
            }
          }
        }
      });

      _joinTime = DateTime.now();
      _startTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('连接会议室失败: $e')));
        Navigator.of(context).pop();
      }
      return;
    }

    // Media init — failure OK
    if (!_isMicMuted) {
      try { await _room?.localParticipant?.setMicrophoneEnabled(true); }
      catch (_) { if (mounted) setState(() => _isMicMuted = true); }
    }
    if (!_isCameraOff) {
      try { await _room?.localParticipant?.setCameraEnabled(true); }
      catch (_) { if (mounted) setState(() => _isCameraOff = true); }
    }
  }

  void _handleDataMessage(DataReceivedEvent e) {
    try {
      final data = json.decode(utf8.decode(e.data)) as Map<String, dynamic>;
      final type = data['type'] as String?;
      debugPrint('[MeetingRoom] received DataChannel: $type');
      if (type == 'meeting:chat') {
        final msg = _ChatMsg(
          id: data['id'] as String? ?? '',
          senderId: data['senderId'] as String? ?? '',
          senderName: data['senderName'] as String? ?? '',
          content: data['content'] as String? ?? '',
          time: DateTime.now(),
        );
        setState(() {
          _chatMessages.add(msg);
          if (!_showChat) _unreadChat++;
        });
      } else if (type == 'meeting:reaction') {
        _addFloatingEmoji(data['emoji'] as String? ?? '👍');
      } else if (type == 'meeting:raise-hand') {
        // Could track raised hands per participant
      } else if (type == 'meeting:host-changed') {
        final newHost = data['newHostUserId'] as String?;
        if (newHost != null) {
          setState(() => _currentHostUserId = newHost);
          if (newHost == _room?.localParticipant?.identity) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('你已成为主持人')));
          }
        }
      } else if (type == 'meeting:role-changed') {
        final userId = data['userId'] as String?;
        final role = data['role'] as String?;
        if (userId != null && role != null) {
          setState(() => _participantRoles[userId] = role);
          if (userId == _room?.localParticipant?.identity) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('你的角色已变更为 $role')));
          }
        }
      } else if (type == 'meeting:caption') {
        final userName = data['userName'] as String? ?? '';
        final text = data['text'] as String? ?? '';
        final isFinal = data['isFinal'] as bool? ?? false;
        if (text.isNotEmpty && _captionsEnabled) {
          setState(() {
            // Update existing or add new
            final idx = _captions.indexWhere((c) => c.userName == userName && !c.isFinal);
            if (idx >= 0) {
              _captions[idx] = _CaptionEntry(userName: userName, text: text, isFinal: isFinal, time: DateTime.now());
            } else {
              _captions.add(_CaptionEntry(userName: userName, text: text, isFinal: isFinal, time: DateTime.now()));
            }
            // Keep last 4
            while (_captions.length > 4) _captions.removeAt(0);
            // Remove old finals after 5s
            _captions.removeWhere((c) => c.isFinal && DateTime.now().difference(c.time).inSeconds > 5);
          });
        }
      } else if (type == 'meeting:request-mute') {
        final target = data['targetUserId'] as String?;
        if (target == _room?.localParticipant?.identity && !_isMicMuted) {
          _toggleMic();
          setState(() => _wasMutedByHost = true);
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _wasMutedByHost = false);
          });
        }
      } else if (type == 'meeting:whiteboard-strokes-sync') {
        final strokes = data['strokes'];
        if (strokes != null && strokes is List) {
          _lastRemoteStrokes = strokes;
          debugPrint('[MeetingRoom] strokes-sync received, count=${strokes.length}, panelOpen=$_showWhiteboard');
          _whiteboardKey.currentState?.setStrokes(strokes);
        }
      }
    } catch (e, stack) {
      debugPrint('[MeetingRoom] handleDataMessage ERROR: $e\n$stack');
    }
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_joinTime != null && mounted) {
        setState(() => _duration = DateTime.now().difference(_joinTime!));
      }
    });
  }

  void _startWaitingRoomPoll() {
    if (!_isHost) return;
    _waitingPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isHost || !mounted) return;
      try {
        final api = ref.read(meetingApiServiceProvider);
        final waiting = await api.getWaitingParticipants(widget.meeting.id);
        if (mounted) setState(() => _waitingParticipants = waiting);
      } catch (_) {}
    });
  }

  Future<void> _admitParticipant(String userId) async {
    try {
      await ref.read(meetingApiServiceProvider).admitParticipant(widget.meeting.id, userId);
      setState(() => _waitingParticipants.removeWhere((p) => p.userId == userId));
    } catch (_) {}
  }

  Future<void> _denyParticipant(String userId) async {
    try {
      await ref.read(meetingApiServiceProvider).denyParticipant(widget.meeting.id, userId);
      setState(() => _waitingParticipants.removeWhere((p) => p.userId == userId));
    } catch (_) {}
  }

  Future<void> _loadChatHistory() async {
    try {
      final api = ref.read(meetingApiServiceProvider);
      final history = await api.getChatHistory(widget.meeting.id);
      if (mounted) {
        setState(() {
          _chatMessages.insertAll(0, history.map((m) => _ChatMsg(
            id: m.id,
            senderId: m.senderId ?? '',
            senderName: m.senderName,
            content: m.content,
            time: DateTime.tryParse(m.sentAt) ?? DateTime.now(),
          )));
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _handRaiseTimer?.cancel();
    _waitingPollTimer?.cancel();
    _speech?.stop();
    _chatController.dispose();
    _listener?.dispose();
    _room?.disconnect();
    _room?.dispose();
    // Restore portrait orientation
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String _fmtDur(Duration d) {
    if (d.inHours > 0) return '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  // ── Actions ──

  Future<void> _toggleMic() async {
    setState(() => _isMicMuted = !_isMicMuted);
    try { await _room?.localParticipant?.setMicrophoneEnabled(!_isMicMuted); } catch (_) {}
  }

  Future<void> _toggleCamera() async {
    setState(() => _isCameraOff = !_isCameraOff);
    try { await _room?.localParticipant?.setCameraEnabled(!_isCameraOff); } catch (_) {}
  }

  CameraPosition _cameraPosition = CameraPosition.front;

  Future<void> _switchCamera() async {
    try {
      final pub = _room?.localParticipant?.videoTrackPublications
          .where((t) => t.source == TrackSource.camera && t.track != null)
          .firstOrNull;
      if (pub != null && pub.track is LocalVideoTrack) {
        final track = pub.track as LocalVideoTrack;
        final newPos = _cameraPosition == CameraPosition.front ? CameraPosition.back : CameraPosition.front;
        await track.setCameraPosition(newPos);
        setState(() => _cameraPosition = newPos);
      }
    } catch (e) {
      debugPrint('[MeetingRoom] switchCamera error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('切换摄像头失败: $e')));
    }
  }

  Future<void> _startScreenShare() async {
    // Show warning — screen share may crash on some emulators
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('屏幕共享'),
        content: const Text('即将开始共享你的屏幕，系统会请求录屏权限。\n\n注意：模拟器上可能不稳定，建议在真机上使用。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('开始共享')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      debugPrint('[MeetingRoom] Starting screen share...');
      // Android 14+ requires foreground service for MediaProjection
      final bgConfig = const FlutterBackgroundAndroidConfig(
        notificationTitle: 'MeshWork 屏幕共享',
        notificationText: '正在共享屏幕',
        notificationImportance: AndroidNotificationImportance.normal,
      );
      await FlutterBackground.initialize(androidConfig: bgConfig);
      await FlutterBackground.enableBackgroundExecution();

      await _room?.localParticipant?.setScreenShareEnabled(true);
      debugPrint('[MeetingRoom] Screen share started');
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('屏幕共享已开始')));
      }
    } catch (e, stack) {
      debugPrint('[MeetingRoom] Screen share FAILED: $e\n$stack');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('屏幕共享失败: $e')));
    }
  }

  Future<void> _stopScreenShare() async {
    try {
      await _room?.localParticipant?.setScreenShareEnabled(false);
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[MeetingRoom] Stop screen share error: $e');
    }
  }

  bool get _isLocalScreenSharing {
    return _room?.localParticipant?.trackPublications.values
        .any((t) => t.source == TrackSource.screenShareVideo) ?? false;
  }

  // ── Captions / Speech Recognition ──

  void _toggleCaptions() {
    setState(() => _captionsEnabled = !_captionsEnabled);
    if (_captionsEnabled) {
      _startSpeechRecognition();
    } else {
      _stopSpeechRecognition();
      _captions.clear();
    }
  }

  SpeechToText? _speech;

  void _startSpeechRecognition() async {
    try {
      _speech = SpeechToText();
      final available = await _speech!.initialize(
        onError: (e) => debugPrint('[STT] Error: ${e.errorMsg}'),
        onStatus: (s) => debugPrint('[STT] Status: $s'),
      );
      if (!available) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设备不支持语音识别')));
        return;
      }
      _startListening();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('字幕已开启')));
    } catch (e) {
      debugPrint('[STT] Init error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('语音识别启动失败: $e')));
    }
  }

  void _startListening() {
    if (_speech == null || !_captionsEnabled) return;
    final localName = _room?.localParticipant?.name ?? _room?.localParticipant?.identity ?? 'Me';
    final localId = _room?.localParticipant?.identity ?? '';

    _speech!.listen(
      onResult: (result) {
        final text = result.recognizedWords;
        if (text.isEmpty) return;
        final isFinal = result.finalResult;

        // Broadcast caption to peers
        _sendData({
          'type': 'meeting:caption',
          'userId': localId,
          'userName': localName,
          'text': text,
          'isFinal': isFinal,
        }, reliable: false);

        // Show locally too
        setState(() {
          final idx = _captions.indexWhere((c) => c.userName == localName && !c.isFinal);
          if (idx >= 0) {
            _captions[idx] = _CaptionEntry(userName: localName, text: text, isFinal: isFinal, time: DateTime.now());
          } else {
            _captions.add(_CaptionEntry(userName: localName, text: text, isFinal: isFinal, time: DateTime.now()));
          }
          while (_captions.length > 4) _captions.removeAt(0);
          _captions.removeWhere((c) => c.isFinal && DateTime.now().difference(c.time).inSeconds > 5);
        });

        // Restart listening after final result (speech_to_text stops after silence)
        if (isFinal && _captionsEnabled) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_captionsEnabled && mounted) _startListening();
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'zh_CN', // Chinese
    );
  }

  void _stopSpeechRecognition() {
    _speech?.stop();
    _speech = null;
  }

  // ── Network Quality Helper ──

  Widget _buildNetworkBadge(String? identity) {
    final quality = _connectionQualities[identity ?? ''];
    if (quality == null || quality == ConnectionQuality.unknown) return const SizedBox.shrink();
    IconData icon;
    Color color;
    switch (quality) {
      case ConnectionQuality.excellent:
        icon = Icons.signal_cellular_4_bar; color = Colors.green;
      case ConnectionQuality.good:
        icon = Icons.signal_cellular_alt; color = Colors.green;
      case ConnectionQuality.poor:
        icon = Icons.signal_cellular_alt_1_bar; color = Colors.orange;
      case ConnectionQuality.lost:
        icon = Icons.signal_cellular_off; color = Colors.red;
      default:
        return const SizedBox.shrink();
    }
    return Positioned(
      right: 4, top: 4,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, color: color, size: 12),
      ),
    );
  }

  void _toggleRaiseHand() {
    setState(() => _isHandRaised = !_isHandRaised);
    _handRaiseTimer?.cancel();
    if (_isHandRaised) {
      _sendData({'type': 'meeting:raise-hand', 'userId': _room?.localParticipant?.identity ?? '', 'raised': true});
      _handRaiseTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => _isHandRaised = false);
      });
    } else {
      _sendData({'type': 'meeting:raise-hand', 'userId': _room?.localParticipant?.identity ?? '', 'raised': false});
    }
  }

  void _sendReaction(String emoji) {
    _sendData({'type': 'meeting:reaction', 'userId': _room?.localParticipant?.identity ?? '', 'emoji': emoji}, reliable: false);
    _addFloatingEmoji(emoji);
  }

  void _addFloatingEmoji(String emoji) {
    final id = DateTime.now().microsecondsSinceEpoch;
    final e = _FloatingEmoji(id: id, emoji: emoji, left: 0.2 + Random().nextDouble() * 0.6);
    setState(() => _floatingEmojis.add(e));
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _floatingEmojis.removeWhere((x) => x.id == id));
    });
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();

    final localName = _room?.localParticipant?.name ?? _room?.localParticipant?.identity ?? 'Me';
    final localId = _room?.localParticipant?.identity ?? '';

    final msg = _ChatMsg(id: '', senderId: localId, senderName: localName, content: text, time: DateTime.now());
    setState(() => _chatMessages.add(msg));

    // Broadcast via DataChannel
    _sendData({'type': 'meeting:chat', 'senderId': localId, 'senderName': localName, 'content': text, 'sentAt': DateTime.now().millisecondsSinceEpoch});

    // Persist to server
    try {
      await ref.read(meetingApiServiceProvider).sendChatMessage(widget.meeting.id, content: text, senderName: localName);
    } catch (_) {}
  }

  Future<void> _sendData(Map<String, dynamic> data, {bool reliable = true}) async {
    try {
      final jsonStr = json.encode(data);
      final bytes = utf8.encode(jsonStr);
      debugPrint('[MeetingRoom] sendData: type=${data['type']}, bytes=${bytes.length}, reliable=$reliable, room=${_room != null}, local=${_room?.localParticipant?.identity}');
      await _room?.localParticipant?.publishData(bytes, reliable: reliable);
      debugPrint('[MeetingRoom] sendData OK');
    } catch (e, stack) {
      debugPrint('[MeetingRoom] sendData FAILED: $e\n$stack');
    }
  }

  Future<void> _leave({String? showMessage, bool isEndMeeting = false}) async {
    if (_isLeaving) return;
    _isLeaving = true;
    await _room?.disconnect();
    if (mounted) {
      // Save left meeting info for rejoin banner (only if meeting is still active)
      if (!isEndMeeting) {
        ref.read(leftMeetingProvider.notifier).setLeftMeeting(LeftMeetingInfo(
          meetingId: widget.meeting.id,
          meetingNo: widget.meeting.meetingNo,
          title: widget.meeting.title,
        ));
      } else {
        ref.read(leftMeetingProvider.notifier).clear();
      }
      if (showMessage != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(showMessage)));
      ref.read(meetingListProvider.notifier).refresh();
      Navigator.of(context).pop();
    }
  }

  Future<void> _endMeeting() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('结束会议'), content: const Text('结束后所有参与者将被移出，确定？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('结束', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try { await ref.read(meetingApiServiceProvider).endMeeting(widget.meeting.id); } catch (_) {}
    _leave(showMessage: '会议已结束', isEndMeeting: true);
  }

  void _pinParticipant(String? identity) {
    setState(() {
      _pinnedIdentity = identity;
      _layoutMode = identity != null ? 'speaker' : 'grid';
    });
  }

  bool get _isHost => _currentHostUserId == (_room?.localParticipant?.identity ?? '');
  bool get _isHostOrCoHost => _isHost || _participantRoles[_room?.localParticipant?.identity] == 'CoHost';

  void _minimizeMeeting() {
    // Transfer room ownership to the float window — do NOT disconnect
    final room = _room;
    _room = null; // Prevent dispose() from disconnecting
    _listener?.dispose();
    _listener = null;

    ref.read(activeMeetingProvider.notifier).setActive(ActiveMeetingInfo(
      meeting: widget.meeting,
      token: widget.token,
      liveKitServerUrl: widget.liveKitServerUrl,
      roomName: widget.roomName,
      joinTime: _joinTime ?? DateTime.now(),
      room: room, // Preserved — stays connected
    ));
    Navigator.of(context).pop();
  }
  bool get _hasOpenPanel => _showParticipants || _showChat || _showWhiteboard || _showPolls;

  void _toggleLandscape() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _closeAllPanels() {
    setState(() { _showParticipants = false; _showChat = false; _showWhiteboard = false; _showPolls = false; });
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final participantCount = 1 + _remoteParticipants.length;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(participantCount),
                Expanded(
                  child: GestureDetector(
                    onTap: _hasOpenPanel ? _closeAllPanels : null,
                    behavior: HitTestBehavior.translucent,
                    child: _screenShareTrack != null
                        ? _buildScreenShareLayout()
                        : (_layoutMode == 'speaker' && _pinnedIdentity != null)
                            ? _buildSpeakerLayout()
                            : _buildGridLayout(),
                  ),
                ),
                _buildToolbar(),
              ],
            ),
            // Side panels
            if (_showParticipants) _buildParticipantPanel(),
            if (_showChat) _buildChatPanel(),
            if (_showWhiteboard) _buildWhiteboardPanel(),
            if (_showPolls) _buildPollPanel(),
            // Floating emojis
            ..._floatingEmojis.map((e) => _buildFloatingEmoji(e, screenWidth)),
            // Captions overlay
            if (_captionsEnabled && _captions.isNotEmpty)
              Positioned(
                bottom: 70, left: 16, right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _captions.map((c) => Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '${c.userName}: ${c.text}',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: c.isFinal ? FontWeight.w500 : FontWeight.w300),
                      textAlign: TextAlign.center,
                    ),
                  )).toList(),
                ),
              ),
            // Muted by host notification
            if (_wasMutedByHost)
              Positioned(
                top: 60, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.mic_off, color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text('主持人已将你静音', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ──

  Widget _buildTopBar(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.meeting.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${_fmtDur(_duration)}  ·  $count人', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          // Recording indicator
          if (_isRecording)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.fiber_manual_record, color: Colors.red, size: 10),
                SizedBox(width: 3),
                Text('REC', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
          // Waiting room badge
          if (_isHost && _waitingParticipants.isNotEmpty)
            GestureDetector(
              onTap: _showWaitingRoom,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.hourglass_top, color: Colors.orange, size: 12),
                  const SizedBox(width: 3),
                  Text('${_waitingParticipants.length}', style: const TextStyle(color: Colors.orange, fontSize: 11)),
                ]),
              ),
            ),
          if (_isHandRaised)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Text('✋', style: TextStyle(fontSize: 18)),
            ),
          const SizedBox(width: 6),
          // Minimize button
          GestureDetector(
            onTap: _minimizeMeeting,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.picture_in_picture_alt, color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () { Clipboard.setData(ClipboardData(text: widget.meeting.meetingNo)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('会议号已复制'))); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(widget.meeting.meetingNo, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Layouts ──

  Widget _buildGridLayout() {
    final all = <_PInfo>[
      _PInfo(_room?.localParticipant, true),
      ..._remoteParticipants.map((p) => _PInfo(p, false)),
    ];
    if (all.length == 1) return _tile(all.first, fullscreen: true);
    if (all.length == 2) {
      return Column(children: all.map((p) => Expanded(child: _tile(p))).toList());
    }
    final cols = all.length <= 4 ? 2 : 3;
    return GridView.builder(
      padding: const EdgeInsets.all(3),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 3, crossAxisSpacing: 3, childAspectRatio: 3 / 4),
      itemCount: all.length,
      itemBuilder: (_, i) => _tile(all[i]),
    );
  }

  Widget _buildSpeakerLayout() {
    final pinned = _remoteParticipants.where((p) => p.identity == _pinnedIdentity).firstOrNull;
    final others = <_PInfo>[
      _PInfo(_room?.localParticipant, true),
      ..._remoteParticipants.where((p) => p.identity != _pinnedIdentity).map((p) => _PInfo(p, false)),
    ];
    return Column(
      children: [
        Expanded(flex: 3, child: _tile(_PInfo(pinned, false), fullscreen: true)),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            children: others.map((p) => SizedBox(width: 80, child: _tile(p))).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenShareLayout() {
    final track = _screenShareTrack?.track;
    final others = <_PInfo>[
      _PInfo(_room?.localParticipant, true),
      ..._remoteParticipants.map((p) => _PInfo(p, false)),
    ];
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              Positioned.fill(
                child: track != null
                    ? VideoTrackRenderer(track as VideoTrack)
                    : const Center(child: Text('屏幕共享加载中...', style: TextStyle(color: Colors.white54))),
              ),
              // Rotation toggle button
              Positioned(
                right: 12, top: 12,
                child: GestureDetector(
                  onTap: _toggleLandscape,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: Icon(_isLandscape ? Icons.screen_lock_portrait : Icons.screen_lock_landscape, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!_isLandscape)
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              children: others.map((p) => SizedBox(width: 80, child: _tile(p))).toList(),
            ),
          ),
      ],
    );
  }

  Widget _tile(_PInfo info, {bool fullscreen = false}) {
    final p = info.participant;
    if (p == null) return Container(color: const Color(0xFF1F2937));
    final vt = p.videoTrackPublications.where((t) => t.track != null && t.source == TrackSource.camera && !t.muted).firstOrNull;
    final hasVideo = vt != null;
    final name = p.name?.isNotEmpty == true ? p.name! : (info.isLocal ? '我' : (p.identity ?? ''));

    return GestureDetector(
      onTap: info.isLocal ? null : () => _pinParticipant(p.identity == _pinnedIdentity ? null : p.identity),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: fullscreen ? null : BorderRadius.circular(6), border: _pinnedIdentity == p.identity ? Border.all(color: EbiColors.primaryBlue, width: 2) : null),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasVideo) VideoTrackRenderer(vt!.track as VideoTrack)
            else Center(child: CircleAvatar(radius: fullscreen ? 40 : 20, backgroundColor: EbiColors.primaryBlue.withValues(alpha: 0.3), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: Colors.white, fontSize: fullscreen ? 30 : 16)))),
            Positioned(left: 4, bottom: 4, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(3)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (info.isLocal) const Icon(Icons.person, color: Colors.white54, size: 10),
                Text(info.isLocal ? '我' : name, style: const TextStyle(color: Colors.white, fontSize: 10)),
              ]),
            )),
            // Network quality badge
            _buildNetworkBadge(p.identity),
          ],
        ),
      ),
    );
  }

  // ── Toolbar ──

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          // Primary buttons (scrollable)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ctrl(_isMicMuted ? Icons.mic_off : Icons.mic, _isMicMuted ? '解除静音' : '静音', !_isMicMuted, _toggleMic),
                  _cameraCtrl(),
                  _ctrl(Icons.people_outline, '参与者', _showParticipants, () { _closeAllPanels(); setState(() => _showParticipants = true); }),
                  _ctrlBadge(Icons.chat_bubble_outline, '聊天', _showChat, () { _closeAllPanels(); setState(() { _showChat = true; _unreadChat = 0; }); }, _unreadChat),
                  _ctrl(_isHandRaised ? Icons.pan_tool : Icons.pan_tool_outlined, '举手', _isHandRaised, _toggleRaiseHand),
                  _ctrl(Icons.more_horiz, '更多', false, _showMoreMenu),
                ],
              ),
            ),
          ),
          // Fixed leave button
          const SizedBox(width: 4),
          _leaveButton(),
        ],
      ),
    );
  }

  Widget _leaveButton() {
    return GestureDetector(
      onTap: _isHost ? _showLeaveOptions : () => _leave(showMessage: '已离开会议'),
      child: Container(
        width: 52, height: 52,
        decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
        child: const Icon(Icons.call_end, color: Colors.white, size: 24),
      ),
    );
  }

  void _showLeaveOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.white),
              title: const Text('离开会议', style: TextStyle(color: Colors.white)),
              subtitle: Text(_isHost ? '主持人将自动转移给其他参与者' : '会议将继续进行', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                if (_isHost && _remoteParticipants.isNotEmpty) {
                  // Auto-transfer host to first remote participant
                  final newHost = _remoteParticipants.first.identity;
                  try {
                    await ref.read(meetingApiServiceProvider).transferHostAndLeave(widget.meeting.id, newHostUserId: newHost);
                    _sendData({'type': 'meeting:host-changed', 'newHostUserId': newHost});
                  } catch (_) {}
                }
                _leave(showMessage: '已离开会议');
              },
            ),
            if (_isHost) ...[
              const Divider(height: 1, color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.stop_circle, color: Colors.red),
                title: const Text('结束会议', style: TextStyle(color: Colors.red)),
                subtitle: const Text('所有人将被移出', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () { Navigator.pop(ctx); _endMeeting(); },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16, runSpacing: 16,
            children: [
              // Screen share
              _moreItem(ctx, _isLocalScreenSharing ? Icons.stop_screen_share : Icons.screen_share, _isLocalScreenSharing ? '停止共享' : '共享屏幕', () { Navigator.pop(ctx); _isLocalScreenSharing ? _stopScreenShare() : _startScreenShare(); }),
              _moreItem(ctx, Icons.emoji_emotions_outlined, '表情', () { Navigator.pop(ctx); _showEmojiPicker(); }),
              _moreItem(ctx, Icons.draw_outlined, '白板', () { Navigator.pop(ctx); _closeAllPanels(); setState(() => _showWhiteboard = true); }),
              _moreItem(ctx, Icons.poll_outlined, '投票', () { Navigator.pop(ctx); _closeAllPanels(); setState(() => _showPolls = true); }),
              _moreItem(ctx, _captionsEnabled ? Icons.closed_caption : Icons.closed_caption_off, _captionsEnabled ? '关闭字幕' : '字幕', () { Navigator.pop(ctx); _toggleCaptions(); }),
              _moreItem(ctx, Icons.copy, '复制会议号', () { Navigator.pop(ctx); Clipboard.setData(ClipboardData(text: widget.meeting.meetingNo)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制'))); }),
              if (_screenShareTrack != null)
                _moreItem(ctx, _isLandscape ? Icons.screen_lock_portrait : Icons.screen_lock_landscape, '横竖屏', () { Navigator.pop(ctx); _toggleLandscape(); }),
              _moreItem(ctx, Icons.grid_view, _layoutMode == 'grid' ? '宫格视图' : '切换宫格', () { Navigator.pop(ctx); setState(() { _layoutMode = 'grid'; _pinnedIdentity = null; }); }),
              if (_isHost) ...[
                _moreItem(ctx, Icons.person_add_outlined, '邀请', () { Navigator.pop(ctx); _showInvitePanel(); }),
                _moreItem(ctx, _isRecording ? Icons.stop : Icons.fiber_manual_record, _isRecording ? '停止录制' : '录制', () { Navigator.pop(ctx); _toggleRecording(); }),
                if (_waitingParticipants.isNotEmpty)
                  _moreItem(ctx, Icons.hourglass_top, '等候室 (${_waitingParticipants.length})', () { Navigator.pop(ctx); _showWaitingRoom(); }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _moreItem(BuildContext ctx, IconData icon, String label, VoidCallback onTap, [bool active = false]) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: active ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  bool _isRecording = false;
  Future<void> _toggleRecording() async {
    final api = ref.read(meetingApiServiceProvider);
    try {
      if (_isRecording) {
        await api.stopRecording(widget.meeting.id);
        setState(() => _isRecording = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('录制已停止')));
      } else {
        await api.startRecording(widget.meeting.id);
        setState(() => _isRecording = true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('录制已开始')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('录制操作失败: $e')));
    }
  }

  // ── Host Participant Actions ──

  void _showParticipantActions(String identity, String name) {
    final isHostTarget = identity == _currentHostUserId;
    final isCoHost = _participantRoles[identity] == 'CoHost';
    final localId = _room?.localParticipant?.identity ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1, color: Colors.white12),
            // Mute (host or co-host)
            if (_isHostOrCoHost)
              ListTile(
                leading: const Icon(Icons.mic_off, color: Colors.white70),
                title: const Text('请求静音', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendData({'type': 'meeting:request-mute', 'targetUserId': identity});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已发送静音请求')));
                },
              ),
            // Host-only actions
            if (_isHost && !isHostTarget) ...[
              // Transfer host
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.white70),
                title: const Text('设为主持人', style: TextStyle(color: Colors.white)),
                subtitle: const Text('将主持人转移给此参与者', style: TextStyle(color: Colors.white38, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final api = ref.read(meetingApiServiceProvider);
                    final updated = await api.transferHostAndLeave(widget.meeting.id, newHostUserId: identity);
                    // Don't leave — just transfer
                    setState(() => _currentHostUserId = identity);
                    _sendData({'type': 'meeting:host-changed', 'newHostUserId': identity});
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已将主持人转移给 $name')));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('转移失败: $e')));
                  }
                },
              ),
              // Set/Remove co-host
              if (!isCoHost)
                ListTile(
                  leading: const Icon(Icons.person_add, color: Colors.white70),
                  title: const Text('设为联合主持人', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref.read(meetingApiServiceProvider).setCoHost(widget.meeting.id, identity);
                      setState(() => _participantRoles[identity] = 'CoHost');
                      _sendData({'type': 'meeting:role-changed', 'userId': identity, 'role': 'CoHost'});
                    } catch (_) {}
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.person_remove, color: Colors.white70),
                  title: const Text('取消联合主持人', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await ref.read(meetingApiServiceProvider).removeCoHost(widget.meeting.id, identity);
                      setState(() => _participantRoles[identity] = 'Participant');
                      _sendData({'type': 'meeting:role-changed', 'userId': identity, 'role': 'Participant'});
                    } catch (_) {}
                  },
                ),
              // Kick
              ListTile(
                leading: const Icon(Icons.remove_circle, color: Colors.red),
                title: const Text('移出会议', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(meetingApiServiceProvider).kickParticipant(widget.meeting.id, identity);
                  } catch (_) {}
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showWaitingRoom() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Text('等候室', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('(${_waitingParticipants.length}人)', style: const TextStyle(color: Colors.white54)),
                  const Spacer(),
                  GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, color: Colors.white54)),
                ]),
              ),
              const Divider(height: 1, color: Colors.white12),
              if (_waitingParticipants.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Text('暂无等待准入的参与者', style: TextStyle(color: Colors.white38)))
              else
                ..._waitingParticipants.map((p) => ListTile(
                  leading: CircleAvatar(radius: 18, backgroundColor: EbiColors.primaryBlue.withValues(alpha: 0.2), child: Text(p.userName.isNotEmpty ? p.userName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14))),
                  title: Text(p.userName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: () async { await _admitParticipant(p.userId); setSheetState(() {}); },
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: EbiColors.success, borderRadius: BorderRadius.circular(8)), child: const Text('准入', style: TextStyle(color: Colors.white, fontSize: 12))),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async { await _denyParticipant(p.userId); setSheetState(() {}); },
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Text('拒绝', style: TextStyle(color: Colors.red, fontSize: 12))),
                    ),
                  ]),
                )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showInvitePanel() {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    final invitedIds = <String>{};
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F2937),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Text('邀请参会', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(onTap: () => Navigator.pop(ctx), child: const Icon(Icons.close, color: Colors.white54)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: searchCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索用户名...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                    filled: true, fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (q) async {
                    if (q.trim().isEmpty) return;
                    setSheetState(() => loading = true);
                    try {
                      final apiClient = ref.read(apiClientProvider);
                      final resp = await apiClient.get('/api/identity/users', queryParameters: {'filter': q.trim(), 'maxResultCount': 20});
                      final raw = resp.data as Map<String, dynamic>;
                      final items = ((raw['result'] as Map<String, dynamic>?)?['items'] ?? raw['items'] ?? []) as List;
                      results = items.map((e) => e as Map<String, dynamic>).toList();
                    } catch (_) {}
                    setSheetState(() => loading = false);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : results.isEmpty
                        ? const Center(child: Text('搜索用户以邀请', style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            controller: scrollCtrl,
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final u = results[i];
                              final uid = u['id'] as String? ?? '';
                              final uname = (u['userName'] ?? u['name'] ?? '') as String;
                              final invited = invitedIds.contains(uid);
                              return ListTile(
                                leading: CircleAvatar(radius: 18, backgroundColor: EbiColors.primaryBlue.withValues(alpha: 0.2), child: Text(uname.isNotEmpty ? uname[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14))),
                                title: Text(uname, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                trailing: invited
                                    ? const Text('已邀请', style: TextStyle(color: Colors.white38, fontSize: 12))
                                    : GestureDetector(
                                        onTap: () async {
                                          setSheetState(() => invitedIds.add(uid));
                                          try {
                                            await inviteUserToMeeting(ref: ref, meeting: widget.meeting, userId: uid, userName: uname);
                                          } catch (e) {
                                            setSheetState(() => invitedIds.remove(uid));
                                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('邀请失败: $e')));
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(color: EbiColors.primaryBlue, borderRadius: BorderRadius.circular(8)),
                                          child: const Text('邀请', style: TextStyle(color: Colors.white, fontSize: 12)),
                                        ),
                                      ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Camera button: tap = toggle on/off, long press = switch front/back
  Widget _cameraCtrl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: _toggleCamera,
        onLongPress: _isCameraOff ? null : _switchCamera,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: !_isCameraOff ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(_isCameraOff ? Icons.videocam_off : Icons.videocam, color: Colors.white, size: 20),
              ),
              if (!_isCameraOff)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), shape: BoxShape.circle),
                    child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(_isCameraOff ? '开摄像头' : '长按翻转', style: const TextStyle(color: Colors.white60, fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _ctrl(IconData icon, String label, bool active, VoidCallback onTap, {Color? bg}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: bg ?? (active ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08)), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 20)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9), overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }

  Widget _ctrlBadge(IconData icon, String label, bool active, VoidCallback onTap, int badge) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: active ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 20)),
            if (badge > 0) Positioned(right: 0, top: 0, child: Container(
              padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 9)),
            )),
          ]),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        ]),
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['👍', '👏', '❤️', '😂', '😮', '🎉'].map((e) => GestureDetector(
            onTap: () { Navigator.pop(ctx); _sendReaction(e); },
            child: Text(e, style: const TextStyle(fontSize: 36)),
          )).toList(),
        ),
      ),
    );
  }

  // ── Participant Panel ──

  Widget _buildParticipantPanel() {
    final all = <_PInfo>[
      _PInfo(_room?.localParticipant, true),
      ..._remoteParticipants.map((p) => _PInfo(p, false)),
    ];
    return Positioned(
      right: 0, top: 0, bottom: 60, width: 260,
      child: Container(
        color: const Color(0xFF1A202C),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                const Text('参与者', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Text('(${all.length})', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const Spacer(),
                GestureDetector(onTap: () => setState(() => _showParticipants = false), child: const Icon(Icons.close, color: Colors.white54, size: 20)),
              ]),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView.builder(
                itemCount: all.length,
                itemBuilder: (_, i) {
                  final p = all[i];
                  final identity = p.participant?.identity ?? '';
                  final name = p.participant?.name?.isNotEmpty == true ? p.participant!.name! : (p.isLocal ? '我' : identity);
                  final audioTracks = p.participant?.audioTrackPublications ?? [];
                  final isMuted = audioTracks.isEmpty || audioTracks.every((t) => t.muted);
                  final camTracks = p.participant?.videoTrackPublications.where((t) => t.source == TrackSource.camera) ?? [];
                  final camOff = camTracks.isEmpty || camTracks.every((t) => t.muted);
                  final isThisHost = identity == _currentHostUserId;
                  final isThisCoHost = _participantRoles[identity] == 'CoHost';
                  final canShowActions = _isHostOrCoHost && !p.isLocal && !isThisHost;

                  return ListTile(
                    dense: true,
                    onTap: canShowActions ? () => _showParticipantActions(identity, name) : null,
                    onLongPress: canShowActions ? () => _showParticipantActions(identity, name) : null,
                    leading: CircleAvatar(radius: 16, backgroundColor: EbiColors.primaryBlue.withValues(alpha: 0.2), child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 12))),
                    title: Row(children: [
                      Flexible(child: Text(p.isLocal ? '$name (我)' : name, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                      if (isThisHost)
                        Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: EbiColors.primaryBlue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)), child: const Text('主持人', style: TextStyle(fontSize: 9, color: EbiColors.primaryBlue))),
                      if (isThisCoHost)
                        Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: EbiColors.secondaryCyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)), child: const Text('联合主持', style: TextStyle(fontSize: 9, color: EbiColors.secondaryCyan))),
                    ]),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(isMuted ? Icons.mic_off : Icons.mic, color: isMuted ? Colors.red : Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Icon(camOff ? Icons.videocam_off : Icons.videocam, color: camOff ? Colors.red : Colors.green, size: 16),
                      if (canShowActions) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.more_vert, color: Colors.white38, size: 16),
                      ],
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat Panel ──

  Widget _buildChatPanel() {
    return Positioned(
      right: 0, top: 0, bottom: 60, width: 300,
      child: Container(
        color: const Color(0xFF1A202C),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                const Text('聊天', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(onTap: () => setState(() => _showChat = false), child: const Icon(Icons.close, color: Colors.white54, size: 20)),
              ]),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _chatMessages.length,
                itemBuilder: (_, i) {
                  final m = _chatMessages[i];
                  final isMe = m.senderId == (_room?.localParticipant?.identity ?? '');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(isMe ? '我' : m.senderName, style: TextStyle(fontSize: 10, color: isMe ? EbiColors.primaryBlue : Colors.white54)),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: isMe ? EbiColors.primaryBlue.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(m.content, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(child: TextField(
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '发送消息...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      filled: true, fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendChatMessage(),
                  )),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _sendChatMessage,
                    child: Container(width: 36, height: 36, decoration: const BoxDecoration(color: EbiColors.primaryBlue, shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.white, size: 18)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Whiteboard Panel ──

  Widget _buildWhiteboardPanel() {
    return MeetingWhiteboardPanel(
      key: _whiteboardKey,
      onClose: () {
        if (mounted) setState(() => _showWhiteboard = false);
      },
      onStrokesChanged: (strokes) {
        // Broadcast strokes to all peers
        _lastRemoteStrokes = strokes;
        _sendData({'type': 'meeting:whiteboard-strokes-sync', 'strokes': strokes});
      },
      onReady: () {
        // Restore last known strokes when panel opens
        if (_lastRemoteStrokes != null && _lastRemoteStrokes!.isNotEmpty) {
          _whiteboardKey.currentState?.setStrokes(_lastRemoteStrokes!);
        }
      },
    );
  }

  // Whiteboard snapshot methods removed — using pure JSON strokes sync now

  // ── Poll Panel ──

  Widget _buildPollPanel() {
    return MeetingPollPanel(
      meetingId: widget.meeting.id,
      isHost: _isHost,
      onClose: () => setState(() => _showPolls = false),
    );
  }

  // ── Floating Emoji ──

  Widget _buildFloatingEmoji(_FloatingEmoji e, double screenW) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 3),
      builder: (ctx, v, _) => Positioned(
        left: screenW * e.left,
        bottom: 80 + v * 300,
        child: Opacity(opacity: v > 0.7 ? (1 - v) / 0.3 : 1, child: Text(e.emoji, style: TextStyle(fontSize: 28 + v * 8))),
      ),
    );
  }
}

// ── Helper Classes ──

class _PInfo {
  final Participant? participant;
  final bool isLocal;
  const _PInfo(this.participant, this.isLocal);
}

class _ChatMsg {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime time;
  const _ChatMsg({required this.id, required this.senderId, required this.senderName, required this.content, required this.time});
}

class _FloatingEmoji {
  final int id;
  final String emoji;
  final double left;
  const _FloatingEmoji({required this.id, required this.emoji, required this.left});
}

class _CaptionEntry {
  final String userName;
  final String text;
  final bool isFinal;
  final DateTime time;
  const _CaptionEntry({required this.userName, required this.text, required this.isFinal, required this.time});
}
