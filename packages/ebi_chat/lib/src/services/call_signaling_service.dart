import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/call_models.dart';

/// SignalR Call Hub signaling service (mirrors Web `useCallSignaling`).
///
/// Manages a **separate** SignalR connection to `/signalr-hubs/call`,
/// independent of the IM messages hub.
class CallSignalingService {
  HubConnection? _hubConnection;
  final TokenStorage _tokenStorage;
  final TenantStorage _tenantStorage;
  final String _baseUrl;

  /// Fires when a remote user invites us to a call.
  final StreamController<IncomingCallPayload> _incomingCallController =
      StreamController<IncomingCallPayload>.broadcast();

  /// Fires when our outgoing call is accepted.
  final StreamController<Map<String, dynamic>> _callAcceptedController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Fires when our outgoing call is rejected.
  final StreamController<Map<String, dynamic>> _callRejectedController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Fires when an incoming call is cancelled by the caller.
  final StreamController<Map<String, dynamic>> _callCancelledController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Fires when the current call ends.
  final StreamController<Map<String, dynamic>> _callEndedController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Fires when the remote user is busy.
  final StreamController<Map<String, dynamic>> _callBusyController =
      StreamController<Map<String, dynamic>>.broadcast();

  final ValueNotifier<SignalRCallState> connectionState =
      ValueNotifier(SignalRCallState.disconnected);

  CallSignalingService({
    required String baseUrl,
    required TokenStorage tokenStorage,
    required TenantStorage tenantStorage,
  })  : _baseUrl = baseUrl,
        _tokenStorage = tokenStorage,
        _tenantStorage = tenantStorage;

  // ── Streams ──

  Stream<IncomingCallPayload> get incomingCallStream =>
      _incomingCallController.stream;
  Stream<Map<String, dynamic>> get callAcceptedStream =>
      _callAcceptedController.stream;
  Stream<Map<String, dynamic>> get callRejectedStream =>
      _callRejectedController.stream;
  Stream<Map<String, dynamic>> get callCancelledStream =>
      _callCancelledController.stream;
  Stream<Map<String, dynamic>> get callEndedStream =>
      _callEndedController.stream;
  Stream<Map<String, dynamic>> get callBusyStream =>
      _callBusyController.stream;

  bool get isConnected =>
      connectionState.value == SignalRCallState.connected;

  // ── Connect / Disconnect ──

  Future<void> connect() async {
    if (_hubConnection != null &&
        _hubConnection!.state == HubConnectionState.Connected) {
      return;
    }

    connectionState.value = SignalRCallState.connecting;

    final token = await _tokenStorage.getAccessToken();
    final tenantId = await _tenantStorage.getTenantId();

    if (token == null) {
      connectionState.value = SignalRCallState.disconnected;
      return;
    }

    final hubUrl = StringBuffer('$_baseUrl${ApiEndpoints.signalRCall}');
    if (tenantId != null && tenantId.isNotEmpty) {
      hubUrl.write('?__tenant=$tenantId');
    }

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          hubUrl.toString(),
          options: HttpConnectionOptions(
            accessTokenFactory: () async {
              return await _tokenStorage.getAccessToken() ?? '';
            },
            transport: HttpTransportType.WebSockets,
            skipNegotiation: true,
          ),
        )
        .withAutomaticReconnect(
          retryDelays: [0, 2000, 5000, 10000, 30000],
        )
        .build();

    _registerHubHandlers();

    _hubConnection!.onclose(({Exception? error}) {
      connectionState.value = SignalRCallState.disconnected;
    });
    _hubConnection!.onreconnecting(({Exception? error}) {
      connectionState.value = SignalRCallState.reconnecting;
    });
    _hubConnection!.onreconnected(({String? connectionId}) {
      connectionState.value = SignalRCallState.connected;
    });

    try {
      await _hubConnection!.start();
      connectionState.value = SignalRCallState.connected;
      AppLogger.info('[CallHub] Connected successfully.');
    } catch (e, st) {
      AppLogger.error('[CallHub] Connection failed', e, st);
      connectionState.value = SignalRCallState.disconnected;
    }
  }

  Future<void> disconnect() async {
    if (_hubConnection == null) return;
    try {
      await _hubConnection!.stop();
    } catch (e) {
      AppLogger.error('[CallHub] Error stopping', e);
    }
    connectionState.value = SignalRCallState.disconnected;
  }

  // ── Client → Server Methods ──

  Future<void> inviteCall(
    String targetUserId,
    String callRecordId,
    CallType callType,
    ConversationType conversationType,
  ) async {
    _ensureConnected();
    final args = <Object>[
      targetUserId,
      callRecordId,
      callType.index,
      conversationType.index,
    ];
    AppLogger.info('[CallHub] invoke invite-call with args: $args');
    try {
      await _hubConnection!.invoke('invite-call', args: args);
      AppLogger.info('[CallHub] invite-call succeeded');
    } catch (e) {
      AppLogger.error('[CallHub] invite-call failed: $e');
      rethrow;
    }
  }

  Future<void> acceptCall(String callRecordId, String callerUserId) async {
    _ensureConnected();
    await _hubConnection!
        .invoke('accept-call', args: <Object>[callRecordId, callerUserId]);
  }

  Future<void> rejectCall(String callRecordId, String callerUserId) async {
    _ensureConnected();
    await _hubConnection!
        .invoke('reject-call', args: <Object>[callRecordId, callerUserId]);
  }

  Future<void> cancelCall(String callRecordId, String targetUserId) async {
    _ensureConnected();
    await _hubConnection!
        .invoke('cancel-call', args: <Object>[callRecordId, targetUserId]);
  }

  Future<void> endCall(
      String callRecordId, List<String> participantUserIds) async {
    _ensureConnected();
    await _hubConnection!.invoke('end-call',
        args: <Object>[callRecordId, participantUserIds]);
  }

  Future<void> busyCall(String callRecordId, String callerUserId) async {
    _ensureConnected();
    await _hubConnection!
        .invoke('busy-call', args: <Object>[callRecordId, callerUserId]);
  }

  // ── Server → Client Handlers ──

  void _registerHubHandlers() {
    final hub = _hubConnection!;

    hub.on('on-incoming-call', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        final data = arguments[0] as Map<String, dynamic>;
        _incomingCallController.add(IncomingCallPayload.fromJson(data));
      } catch (e, st) {
        AppLogger.error('[CallHub] Error parsing on-incoming-call', e, st);
      }
    });

    hub.on('on-call-accepted', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        _callAcceptedController.add(arguments[0] as Map<String, dynamic>);
      } catch (e, st) {
        AppLogger.error('[CallHub] Error parsing on-call-accepted', e, st);
      }
    });

    hub.on('on-call-rejected', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        _callRejectedController.add(arguments[0] as Map<String, dynamic>);
      } catch (e, st) {
        AppLogger.error('[CallHub] Error parsing on-call-rejected', e, st);
      }
    });

    hub.on('on-call-cancelled', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        _callCancelledController.add(arguments[0] as Map<String, dynamic>);
      } catch (e, st) {
        AppLogger.error('[CallHub] Error parsing on-call-cancelled', e, st);
      }
    });

    hub.on('on-call-ended', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        _callEndedController.add(arguments[0] as Map<String, dynamic>);
      } catch (e, st) {
        AppLogger.error('[CallHub] Error parsing on-call-ended', e, st);
      }
    });

    hub.on('on-call-busy', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        _callBusyController.add(arguments[0] as Map<String, dynamic>);
      } catch (e, st) {
        AppLogger.error('[CallHub] Error parsing on-call-busy', e, st);
      }
    });
  }

  void _ensureConnected() {
    if (_hubConnection == null ||
        _hubConnection!.state != HubConnectionState.Connected) {
      throw StateError('[CallHub] Not connected.');
    }
  }

  void dispose() {
    _hubConnection?.stop();
    _incomingCallController.close();
    _callAcceptedController.close();
    _callRejectedController.close();
    _callCancelledController.close();
    _callEndedController.close();
    _callBusyController.close();
    connectionState.dispose();
  }
}

enum SignalRCallState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}
