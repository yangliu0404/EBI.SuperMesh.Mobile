import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/call_models.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/repository/chat_repository.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';
import 'package:ebi_chat/src/services/call_api_service.dart';
import 'package:ebi_chat/src/services/call_signaling_service.dart';
import 'package:ebi_chat/src/services/livekit_service.dart';

// ── Service Providers (Singleton) ──

final callApiServiceProvider = Provider<CallApiService>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return CallApiService(apiClient: apiClient);
});

final callSignalingProvider = Provider<CallSignalingService>((ref) {
  final tokenStorage = ref.read(tokenStorageProvider);
  final tenantStorage = ref.read(tenantStorageProvider);
  return CallSignalingService(
    baseUrl: AppConfig.signalRServer,
    tokenStorage: tokenStorage,
    tenantStorage: tenantStorage,
  );
});

final liveKitServiceProvider = Provider<LiveKitService>((ref) {
  return LiveKitService();
});

// ── Call State ──

class CallState {
  final ActiveCall? activeCall;
  final List<IncomingCallPayload> incomingCalls;
  final bool isMicMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final String? outgoingCallStatus; // dialing, connected, rejected, busy, no-answer, cancelled
  final String? outgoingCallTargetName;
  final String? outgoingCallTargetAvatarUrl;
  final CallType? outgoingCallType;
  final String callViewMode; // 'fullscreen' or 'floating'

  const CallState({
    this.activeCall,
    this.incomingCalls = const [],
    this.isMicMuted = false,
    this.isCameraOff = false,
    this.isSpeakerOn = true,
    this.outgoingCallStatus,
    this.outgoingCallTargetName,
    this.outgoingCallTargetAvatarUrl,
    this.outgoingCallType,
    this.callViewMode = 'fullscreen',
  });

  bool get hasActiveCall => activeCall != null;
  bool get hasIncomingCall => incomingCalls.isNotEmpty;
  IncomingCallPayload? get currentIncomingCall =>
      incomingCalls.isNotEmpty ? incomingCalls.first : null;
  bool get isVideoCall => activeCall?.callType == CallType.video;
  bool get isDialing => outgoingCallStatus == 'dialing';
  bool get isDialingTerminal => const ['rejected', 'busy', 'no-answer', 'cancelled']
      .contains(outgoingCallStatus);
  bool get isCallFloating => callViewMode == 'floating';

  CallState copyWith({
    ActiveCall? activeCall,
    bool clearActiveCall = false,
    List<IncomingCallPayload>? incomingCalls,
    bool? isMicMuted,
    bool? isCameraOff,
    bool? isSpeakerOn,
    String? outgoingCallStatus,
    bool clearOutgoingStatus = false,
    String? outgoingCallTargetName,
    String? outgoingCallTargetAvatarUrl,
    CallType? outgoingCallType,
    String? callViewMode,
  }) {
    return CallState(
      activeCall: clearActiveCall ? null : (activeCall ?? this.activeCall),
      incomingCalls: incomingCalls ?? this.incomingCalls,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      outgoingCallStatus: clearOutgoingStatus
          ? null
          : (outgoingCallStatus ?? this.outgoingCallStatus),
      outgoingCallTargetName:
          outgoingCallTargetName ?? this.outgoingCallTargetName,
      outgoingCallTargetAvatarUrl:
          outgoingCallTargetAvatarUrl ?? this.outgoingCallTargetAvatarUrl,
      outgoingCallType: outgoingCallType ?? this.outgoingCallType,
      callViewMode: clearActiveCall ? 'fullscreen' : (callViewMode ?? this.callViewMode),
    );
  }
}

class CallStateNotifier extends StateNotifier<CallState> {
  final CallApiService _callApi;
  final CallSignalingService _signaling;
  final ChatRepository _chatRepo;
  final LiveKitService _liveKit;
  final String _currentUserId;
  final String _currentUserName;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _missedCallTimer;

  CallStateNotifier({
    required CallApiService callApi,
    required CallSignalingService signaling,
    required ChatRepository chatRepo,
    required LiveKitService liveKit,
    required String currentUserId,
    required String currentUserName,
  })  : _callApi = callApi,
        _signaling = signaling,
        _chatRepo = chatRepo,
        _liveKit = liveKit,
        _currentUserId = currentUserId,
        _currentUserName = currentUserName,
        super(const CallState()) {
    _listenToSignaling();
    _signaling.connect();
  }

  void _listenToSignaling() {
    _subscriptions.add(
      _signaling.incomingCallStream.listen(_onIncomingCall),
    );
    _subscriptions.add(
      _signaling.callAcceptedStream.listen(_onCallAccepted),
    );
    _subscriptions.add(
      _signaling.callRejectedStream.listen(_onCallRejected),
    );
    _subscriptions.add(
      _signaling.callCancelledStream.listen(_onCallCancelled),
    );
    _subscriptions.add(
      _signaling.callEndedStream.listen(_onCallEnded),
    );
    _subscriptions.add(
      _signaling.callBusyStream.listen(_onCallBusy),
    );
  }

  // ── Outgoing Call Flow ──

  /// Initiate a call to [targetUserId].
  Future<void> startCall({
    required String targetUserId,
    required String targetUserName,
    String? targetAvatarUrl,
    required CallType callType,
  }) async {
    state = state.copyWith(
      outgoingCallStatus: 'dialing',
      outgoingCallTargetName: targetUserName,
      outgoingCallTargetAvatarUrl: targetAvatarUrl,
      outgoingCallType: callType,
    );

    try {
      final result = await _callApi.createCall(
        callType: callType,
        conversationType: ConversationType.private_,
        targetUserId: targetUserId,
      );
      debugPrint('[Call] createCall succeeded: callRecordId=${result.callRecordId}, roomName=${result.roomName}');

      // Store the call info BEFORE inviteCall, so that if _onCallAccepted
      // fires immediately after, it has an activeCall to update.
      state = state.copyWith(
        activeCall: ActiveCall(
          callRecordId: result.callRecordId,
          callType: callType,
          conversationType: ConversationType.private_,
          targetUserId: targetUserId,
          targetUserName: targetUserName,
          roomName: result.roomName,
          token: result.token,
          liveKitServerUrl: result.liveKitServerUrl,
          status: CallStatus.ringing,
          direction: CallDirection.outgoing,
          callerUserId: _currentUserId,
          startTime: DateTime.now(),
        ),
      );

      debugPrint('[Call] Calling inviteCall with: targetUserId=$targetUserId, callRecordId=${result.callRecordId}, callType=${callType.index}, conversationType=${ConversationType.private_.index}');
      await _signaling.inviteCall(
        targetUserId,
        result.callRecordId,
        callType,
        ConversationType.private_,
      );

      // Connect to LiveKit immediately (matches Web project behavior).
      debugPrint('[Call] Connecting to LiveKit immediately...');
      await _liveKit.connect(result.liveKitServerUrl, result.token);
      debugPrint('[Call] LiveKit connected, enabling mic...');
      await _liveKit.setMicrophoneEnabled(true);
      if (callType == CallType.video) {
        try {
          await _liveKit.setCameraEnabled(true);
        } catch (e) {
          debugPrint('[Call] Camera enable failed (may be simulator): $e');
        }
      }

      // Auto-cancel after 60s if not answered.
      _missedCallTimer?.cancel();
      _missedCallTimer = Timer(const Duration(seconds: 60), () {
        if (state.outgoingCallStatus == 'dialing') {
          cancelOutgoingCall();
        }
      });
    } catch (e, st) {
      debugPrint('[Call] Error starting call: $e');
      debugPrint('[Call] Stack trace: $st');
      await _liveKit.disconnect();
      state = state.copyWith(clearOutgoingStatus: true, clearActiveCall: true);
    }
  }

  /// Cancel the current outgoing call.
  Future<void> cancelOutgoingCall() async {
    _missedCallTimer?.cancel();
    final call = state.activeCall;
    if (call == null) return;

    try {
      await _signaling.cancelCall(
        call.callRecordId,
        call.targetUserId ?? '',
      );
      await _callApi.endCall(call.callRecordId, status: 5); // Cancelled
      _sendCallSystemMessage(
        targetUserId: call.targetUserId ?? '',
        callType: call.callType,
        isVideo: call.callType == CallType.video,
        durationSeconds: 0,
      );
    } catch (_) {}

    state = state.copyWith(
      outgoingCallStatus: 'cancelled',
      clearActiveCall: true,
    );

    // Auto-clear the overlay after 2s.
    Future.delayed(const Duration(seconds: 2), () {
      if (state.outgoingCallStatus == 'cancelled') {
        state = state.copyWith(clearOutgoingStatus: true);
      }
    });
  }

  // ── Incoming Call Flow ──

  void _onIncomingCall(IncomingCallPayload payload) {
    // If already in a call, send busy signal.
    if (state.hasActiveCall) {
      _signaling
          .busyCall(payload.callRecordId, payload.callerUserId)
          .catchError((_) {});
      return;
    }

    // Deduplicate.
    if (state.incomingCalls
        .any((c) => c.callRecordId == payload.callRecordId)) {
      return;
    }

    state = state.copyWith(
      incomingCalls: [...state.incomingCalls, payload],
    );

    // Auto-dismiss after 30s.
    _missedCallTimer?.cancel();
    _missedCallTimer = Timer(const Duration(seconds: 30), () {
      _dismissIncomingCall(payload.callRecordId);
    });
  }

  /// Accept the current incoming call.
  Future<void> acceptIncomingCall() async {
    final incoming = state.currentIncomingCall;
    if (incoming == null) return;

    try {
      await _signaling.acceptCall(
          incoming.callRecordId, incoming.callerUserId);
      final result = await _callApi.joinCall(incoming.callRecordId);

      state = state.copyWith(
        activeCall: ActiveCall(
          callRecordId: incoming.callRecordId,
          callType: incoming.callType,
          conversationType: incoming.conversationType,
          roomName: result.roomName,
          token: result.token,
          liveKitServerUrl: result.liveKitServerUrl,
          status: CallStatus.connected,
          direction: CallDirection.incoming,
          callerUserId: incoming.callerUserId,
          callerUserName: incoming.callerUserName,
          startTime: DateTime.now(),
          connectTime: DateTime.now(),
        ),
        incomingCalls: state.incomingCalls
            .where((c) => c.callRecordId != incoming.callRecordId)
            .toList(),
      );

      _missedCallTimer?.cancel();

      // Connect to LiveKit.
      await _liveKit.connect(result.liveKitServerUrl, result.token);

      // Enable mic.
      await _liveKit.setMicrophoneEnabled(true);
      // Enable camera for video calls.
      if (incoming.callType == CallType.video) {
        try {
          await _liveKit.setCameraEnabled(true);
        } catch (e) {
          debugPrint('[Call] Camera enable failed (may be simulator): $e');
        }
      }
    } catch (e) {
      debugPrint('[Call] Error accepting call: $e');
      state = state.copyWith(
        clearActiveCall: true,
        incomingCalls: state.incomingCalls
            .where((c) => c.callRecordId != incoming.callRecordId)
            .toList(),
      );
      await _liveKit.disconnect();
    }
  }

  /// Reject the current incoming call.
  Future<void> rejectIncomingCall() async {
    final incoming = state.currentIncomingCall;
    if (incoming == null) return;

    _missedCallTimer?.cancel();

    try {
      await _signaling.rejectCall(
          incoming.callRecordId, incoming.callerUserId);
      await _callApi.endCall(incoming.callRecordId, status: 4); // Rejected
      
      _sendCallSystemMessage(
        targetUserId: incoming.callerUserId,
        callType: incoming.callType,
        isVideo: incoming.callType == CallType.video,
        durationSeconds: 0,
      );
    } catch (_) {}

    state = state.copyWith(
      incomingCalls: state.incomingCalls
          .where((c) => c.callRecordId != incoming.callRecordId)
          .toList(),
    );
  }

  void _dismissIncomingCall(String callRecordId) {
    state = state.copyWith(
      incomingCalls: state.incomingCalls
          .where((c) => c.callRecordId != callRecordId)
          .toList(),
    );
  }

  // ── In-Call Actions ──

  /// End the current active call.
  Future<void> endActiveCall() async {
    final call = state.activeCall;
    if (call == null) return;

    _missedCallTimer?.cancel();

    try {
      final otherUserId = call.direction == CallDirection.outgoing
          ? call.targetUserId
          : call.callerUserId;
      final participantIds = otherUserId != null ? [otherUserId] : <String>[];
      await _signaling.endCall(call.callRecordId, participantIds);
      await _callApi.endCall(call.callRecordId);

      // Calculate duration
      final duration = call.connectTime != null
          ? DateTime.now().difference(call.connectTime!).inSeconds
          : 0;

      if (otherUserId != null) {
        _sendCallSystemMessage(
          targetUserId: otherUserId,
          callType: call.callType,
          isVideo: call.callType == CallType.video,
          durationSeconds: duration,
        );
      }
    } catch (_) {}

    await _liveKit.disconnect();
    state = state.copyWith(
      clearActiveCall: true,
      clearOutgoingStatus: true,
      isMicMuted: false,
      isCameraOff: false,
    );
  }

  Future<void> toggleMic() async {
    final newMuted = !state.isMicMuted;
    state = state.copyWith(isMicMuted: newMuted);
    await _liveKit.setMicrophoneEnabled(!newMuted);
  }

  Future<void> toggleCamera() async {
    final newOff = !state.isCameraOff;
    state = state.copyWith(isCameraOff: newOff);
    try {
      await _liveKit.setCameraEnabled(!newOff);
    } catch (e) {
      debugPrint('[Call] toggleCamera failed (may be simulator): $e');
    }
  }

  Future<void> switchCamera() async {
    try {
      await _liveKit.switchCamera();
    } catch (e) {
      debugPrint('[Call] switchCamera failed: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    final newOn = !state.isSpeakerOn;
    state = state.copyWith(isSpeakerOn: newOn);
    await _liveKit.setSpeakerphoneOn(newOn);
  }

  /// Minimize the active call to a floating window.
  void minimizeCall() {
    state = state.copyWith(callViewMode: 'floating');
  }

  /// Expand the floating window back to fullscreen.
  void expandCall() {
    state = state.copyWith(callViewMode: 'fullscreen');
  }

  // ── SignalR Event Handlers ──

  void _onCallAccepted(Map<String, dynamic> payload) {
    _missedCallTimer?.cancel();
    final call = state.activeCall;
    if (call == null) return;

    debugPrint('[Call] _onCallAccepted: updating activeCall status to connected');

    // LiveKit is already connected (done in startCall).
    // Just update the activeCall status so the UI transitions to CallPage.
    final connectedCall = ActiveCall(
      callRecordId: call.callRecordId,
      callType: call.callType,
      conversationType: call.conversationType,
      targetUserId: call.targetUserId,
      targetUserName: call.targetUserName,
      roomName: call.roomName,
      token: call.token,
      liveKitServerUrl: call.liveKitServerUrl,
      status: CallStatus.connected,
      direction: call.direction,
      callerUserId: call.callerUserId,
      callerUserName: call.callerUserName,
      startTime: call.startTime,
      connectTime: DateTime.now(),
    );

    state = state.copyWith(
      activeCall: connectedCall,
      outgoingCallStatus: 'connected',
    );

    // Clear the outgoing overlay after a brief moment so OutgoingCallPage
    // can transition to CallPage.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (state.outgoingCallStatus == 'connected') {
        state = state.copyWith(clearOutgoingStatus: true);
      }
    });
  }

  void _onCallRejected(Map<String, dynamic> payload) {
    debugPrint('[Call] _onCallRejected payload: $payload');
    _missedCallTimer?.cancel();
    
    final call = state.activeCall;
    if (call != null) {
      _sendCallSystemMessage(
        targetUserId: call.targetUserId ?? '',
        callType: call.callType,
        isVideo: call.callType == CallType.video,
        durationSeconds: 0, // 0 indicates missed/cancelled
      );
    }
    
    state = state.copyWith(
      outgoingCallStatus: 'rejected',
      clearActiveCall: true,
    );
    _autoClearOutgoingStatus();
  }

  void _onCallCancelled(Map<String, dynamic> payload) {
    _missedCallTimer?.cancel();
    final callRecordId = payload['callRecordId'] as String?;
    state = state.copyWith(
      incomingCalls: state.incomingCalls
          .where((c) => c.callRecordId != callRecordId)
          .toList(),
    );
  }

  void _onCallEnded(Map<String, dynamic> payload) {
    debugPrint('[Call] _onCallEnded payload: $payload');
    _missedCallTimer?.cancel();
    _liveKit.disconnect();
    
    final call = state.activeCall;
    if (call != null) {
      final otherUserId = call.direction == CallDirection.outgoing
          ? call.targetUserId
          : call.callerUserId;
      final duration = call.connectTime != null
          ? DateTime.now().difference(call.connectTime!).inSeconds
          : 0;

      if (otherUserId != null) {
        _sendCallSystemMessage(
          targetUserId: otherUserId,
          callType: call.callType,
          isVideo: call.callType == CallType.video,
          durationSeconds: duration,
        );
      }
    }
    
    state = state.copyWith(
      clearActiveCall: true,
      clearOutgoingStatus: true,
      isMicMuted: false,
      isCameraOff: false,
    );
  }

  void _onCallBusy(Map<String, dynamic> payload) {
    debugPrint('[Call] _onCallBusy payload: $payload');
    _missedCallTimer?.cancel();
    
    final call = state.activeCall;
    if (call != null) {
      _sendCallSystemMessage(
        targetUserId: call.targetUserId ?? '',
        callType: call.callType,
        isVideo: call.callType == CallType.video,
        durationSeconds: 0, // 0 indicates missed/cancelled
      );
    }

    state = state.copyWith(
      outgoingCallStatus: 'busy',
      clearActiveCall: true,
    );
    _autoClearOutgoingStatus();
  }

  // ── Helpers ──

  /// Silently injects a call record message into the chat repository
  /// so that the history shows "[Video Call] Duration 01:23" etc.
  void _sendCallSystemMessage({
    required String targetUserId,
    required CallType? callType,
    required bool isVideo,
    required int durationSeconds,
  }) {
    if (targetUserId.isEmpty) return;

    final imMessageType = isVideo ? ImMessageType.videoCall : ImMessageType.voiceCall;
    
    final imMessage = ImChatMessage(
      messageId: '',
      formUserId: _currentUserId,
      formUserName: _currentUserName,
      toUserId: targetUserId,
      groupId: '',
      content: '', // Call messages have no textual content
      sendTime: DateTime.now().toUtc().toIso8601String(),
      messageType: imMessageType.value,
      source: ImMessageSourceType.system.value, // It's generated by the system automatically
      extraProperties: {
        'mediaDuration': durationSeconds,
      },
    );

    _chatRepo.sendMessage(imMessage).catchError((e) {
      debugPrint('[Call] Failed to send call history message: $e');
      return '';
    });
  }

  void _autoClearOutgoingStatus() {
    Future.delayed(const Duration(seconds: 2), () {
      if (state.isDialingTerminal) {
        state = state.copyWith(clearOutgoingStatus: true);
      }
    });
  }

  @override
  void dispose() {
    _missedCallTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

/// Main call state provider.
final callStateProvider =
    StateNotifierProvider<CallStateNotifier, CallState>((ref) {
  final callApi = ref.read(callApiServiceProvider);
  final signaling = ref.read(callSignalingProvider);
  final chatRepo = ref.watch(chatRepositoryProvider);
  final liveKit = ref.read(liveKitServiceProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  // User name: read once — we must NOT watch authProvider here because that
  // would rebuild (and destroy) the CallStateNotifier every time auth state
  // emits, killing any active call.
  final currentUser = ref.read(authProvider).user;

  return CallStateNotifier(
    callApi: callApi,
    signaling: signaling,
    chatRepo: chatRepo,
    liveKit: liveKit,
    currentUserId: currentUserId,
    currentUserName: currentUser?.name ?? '',
  );
});
