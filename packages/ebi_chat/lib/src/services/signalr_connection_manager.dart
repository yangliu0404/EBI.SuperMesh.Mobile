import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/im_models.dart';

/// SignalR connection states.
enum SignalRConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Manages the SignalR hub connection lifecycle for ABP IM.
///
/// All server→client events use kebab-case (e.g. `get-chat-message`).
/// All client→server invocations use kebab-case (e.g. `send`, `read`).
class SignalRConnectionManager {
  HubConnection? _hubConnection;
  final TokenStorage _tokenStorage;
  final TenantStorage _tenantStorage;
  final String _baseUrl;

  /// Broadcasts every incoming message (raw backend model).
  final StreamController<ImChatMessage> _globalMessageController =
      StreamController<ImChatMessage>.broadcast();

  /// Per-conversation message streams (lazily created).
  /// Key is conversationId: userId for 1-to-1, or `group:<groupId>` for groups.
  final Map<String, StreamController<ImChatMessage>> _conversationControllers =
      {};

  /// Broadcasts online-status changes: {userId: isOnline}.
  final StreamController<Map<String, bool>> _onlineStatusController =
      StreamController<Map<String, bool>>.broadcast();

  /// Broadcasts typing indicators: {userId, isTyping}.
  final StreamController<({String userId, bool isTyping})>
      _typingController = StreamController<
          ({String userId, bool isTyping})>.broadcast();

  /// Broadcasts message recall events.
  final StreamController<ImChatMessage> _recallController =
      StreamController<ImChatMessage>.broadcast();

  /// Broadcasts messages-read receipt events.
  final StreamController<ImMessagesReadEvent> _messagesReadController =
      StreamController<ImMessagesReadEvent>.broadcast();

  /// Broadcasts group user joined/removed events.
  final StreamController<ImGroupUserChangedEvent> _groupUserChangedController =
      StreamController<ImGroupUserChangedEvent>.broadcast();

  /// Broadcasts group info updated events.
  final StreamController<ImGroupInfoUpdatedEvent> _groupInfoUpdatedController =
      StreamController<ImGroupInfoUpdatedEvent>.broadcast();

  /// Observable connection state.
  final ValueNotifier<SignalRConnectionState> connectionState =
      ValueNotifier(SignalRConnectionState.disconnected);

  /// The last message ID received — used for offline-gap sync.
  String? lastReceivedMessageId;

  /// Callback invoked after reconnection, so the repository can sync missed
  /// messages via REST API.
  void Function()? onReconnected;

  SignalRConnectionManager({
    required String baseUrl,
    required TokenStorage tokenStorage,
    required TenantStorage tenantStorage,
  })  : _baseUrl = baseUrl,
        _tokenStorage = tokenStorage,
        _tenantStorage = tenantStorage;

  // ── Public getters ──────────────────────────────────────────────────────

  /// Global message stream (all conversations, raw backend model).
  Stream<ImChatMessage> get globalMessageStream =>
      _globalMessageController.stream;

  /// Message stream for a specific conversation.
  Stream<ImChatMessage> conversationMessageStream(String conversationId) {
    _conversationControllers[conversationId] ??=
        StreamController<ImChatMessage>.broadcast();
    return _conversationControllers[conversationId]!.stream;
  }

  Stream<Map<String, bool>> get onlineStatusStream =>
      _onlineStatusController.stream;
  Stream<({String userId, bool isTyping})> get typingStream =>
      _typingController.stream;
  Stream<ImChatMessage> get recallStream => _recallController.stream;
  Stream<ImMessagesReadEvent> get messagesReadStream =>
      _messagesReadController.stream;
  Stream<ImGroupUserChangedEvent> get groupUserChangedStream =>
      _groupUserChangedController.stream;
  Stream<ImGroupInfoUpdatedEvent> get groupInfoUpdatedStream =>
      _groupInfoUpdatedController.stream;

  bool get isConnected =>
      connectionState.value == SignalRConnectionState.connected;

  // ── Connect / Disconnect ────────────────────────────────────────────────

  /// Establish the SignalR connection.
  ///
  /// Call this after successful login. Reads token & tenant from storage.
  Future<void> connect() async {
    if (_hubConnection != null &&
        _hubConnection!.state == HubConnectionState.Connected) {
      AppLogger.debug('[SignalR] Already connected, skipping.');
      return;
    }

    connectionState.value = SignalRConnectionState.connecting;

    final token = await _tokenStorage.getAccessToken();
    final tenantId = await _tenantStorage.getTenantId();

    if (token == null) {
      AppLogger.warning('[SignalR] No access token — cannot connect.');
      connectionState.value = SignalRConnectionState.disconnected;
      return;
    }

    // Build hub URL with tenant query parameter.
    final hubUrl = StringBuffer('$_baseUrl${ApiEndpoints.signalRMessages}');
    if (tenantId != null && tenantId.isNotEmpty) {
      hubUrl.write('?tenantId=$tenantId');
    }

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          hubUrl.toString(),
          options: HttpConnectionOptions(
            accessTokenFactory: () async {
              // Always read the latest token (may have been refreshed).
              return await _tokenStorage.getAccessToken() ?? '';
            },
            transport: HttpTransportType.WebSockets,
            skipNegotiation: true,
          ),
        )
        .withAutomaticReconnect(
          retryDelays: [
            0,      // immediate first retry
            2000,   // 2s
            5000,   // 5s
            10000,  // 10s
            30000,  // 30s
          ],
        )
        .build();

    // ── Register server → client hub methods ──
    _registerHubHandlers();

    // ── Lifecycle callbacks ──
    _hubConnection!.onclose(({Exception? error}) {
      AppLogger.warning('[SignalR] Connection closed: $error');
      connectionState.value = SignalRConnectionState.disconnected;
    });

    _hubConnection!.onreconnecting(({Exception? error}) {
      AppLogger.info('[SignalR] Reconnecting: $error');
      connectionState.value = SignalRConnectionState.reconnecting;
    });

    _hubConnection!.onreconnected(({String? connectionId}) {
      AppLogger.info('[SignalR] Reconnected: $connectionId');
      connectionState.value = SignalRConnectionState.connected;
      // Let the repository pull missed messages via REST.
      onReconnected?.call();
    });

    try {
      await _hubConnection!.start();
      connectionState.value = SignalRConnectionState.connected;
      AppLogger.info('[SignalR] Connected successfully.');
    } catch (e, st) {
      AppLogger.error('[SignalR] Connection failed', e, st);
      connectionState.value = SignalRConnectionState.disconnected;
      rethrow;
    }
  }

  /// Gracefully stop the connection (e.g. on logout).
  Future<void> disconnect() async {
    if (_hubConnection == null) return;
    try {
      await _hubConnection!.stop();
    } catch (e) {
      AppLogger.error('[SignalR] Error stopping connection', e);
    }
    connectionState.value = SignalRConnectionState.disconnected;
    AppLogger.info('[SignalR] Disconnected.');
  }

  // ── Hub invocations (Client → Server) ───────────────────────────────────

  /// Send a chat message. Returns the server-assigned messageId.
  Future<String?> sendMessage(ImChatMessage message) async {
    _ensureConnected();
    final result = await _hubConnection!
        .invoke('send', args: <Object>[message.toJson()]);
    AppLogger.debug('[SignalR] Message sent, result: $result');
    return result as String?;
  }

  /// Join a SignalR group to receive group messages.
  Future<void> joinGroup(String groupId) async {
    _ensureConnected();
    await _hubConnection!.invoke('join-group', args: <Object>[groupId]);
    AppLogger.debug('[SignalR] Joined group: $groupId');
  }

  /// Mark a single message as read.
  Future<void> markAsRead(String messageId) async {
    if (!isConnected) return;
    await _hubConnection!.invoke('read', args: <Object>[messageId]);
  }

  /// Batch-mark all messages in a 1-to-1 conversation as read.
  Future<void> markConversationAsRead(String senderUserId) async {
    if (!isConnected) return;
    await _hubConnection!
        .invoke('read-conversation', args: <Object>[senderUserId]);
  }

  /// Mark a group conversation as read up to a specific message.
  Future<void> readGroupConversation(
      String groupId, String lastReadMessageId) async {
    if (!isConnected) return;
    await _hubConnection!.invoke('read-group-conversation',
        args: <Object>[groupId, lastReadMessageId]);
  }

  /// Notify the other user that we are typing.
  Future<void> sendTyping(String toUserId) async {
    if (!isConnected) return;
    await _hubConnection!.invoke('typing', args: <Object>[toUserId]);
  }

  /// Notify the other user that we stopped typing.
  Future<void> sendStopTyping(String toUserId) async {
    if (!isConnected) return;
    await _hubConnection!.invoke('stop-typing', args: <Object>[toUserId]);
  }

  /// Recall (withdraw) a message via SignalR hub, notifying all parties.
  /// Backend expects the full message object (same as `send`).
  Future<void> recallMessage(ImChatMessage message) async {
    _ensureConnected();
    await _hubConnection!.invoke('recall', args: <Object>[message.toJson()]);
    AppLogger.debug('[SignalR] Message recalled: ${message.messageId}');
  }

  // ── Hub handlers (Server → Client) ─────────────────────────────────────

  void _registerHubHandlers() {
    final hub = _hubConnection!;

    // DEBUG: Log ALL events if needed.
    // Actually, hub.on('any', ...) is not standard. 
    // We'll just add logs to the ones we care about.

    // get-chat-message — the primary real-time message event.
    hub.on('get-chat-message', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      AppLogger.debug('[SignalR] get-chat-message received: $arguments');
      try {
        final data = arguments[0] as Map<String, dynamic>;
        final message = ImChatMessage.fromJson(data);

        // Track for offline-gap sync.
        lastReceivedMessageId = message.messageId;

        // Dispatch to global stream.
        _globalMessageController.add(message);

        // Detect recall: state==10, OR system source with recall content.
        // Backend doesn't always set state==10; sometimes only source==system
        // with content like "对方撤回了一条消息".
        final isRecall = message.state == 10 ||
            (message.sourceEnum == ImMessageSourceType.system &&
             message.content.contains('撤回了一条消息'));

        if (isRecall) {
          final extraMsgId = message.extraProperties?['MessageId'] as String?
              ?? message.extraProperties?['messageId'] as String?;
          final realRecalledId = (extraMsgId ?? message.messageId).toLowerCase();
          
          AppLogger.info('[SignalR] Detected recall in get-chat-message. '
              'state=${message.state}, source=${message.source}, '
              'content="${message.content}", '
              'systemMsgId=${message.messageId}, realRecalledId=$realRecalledId, '
              'formUserId=${message.formUserId}, toUserId=${message.toUserId}, '
              'groupId=${message.groupId}, extraProperties=${message.extraProperties}');
          
          final recallMsg = message.copyWith(
            messageId: realRecalledId,
            formUserId: message.formUserId.toLowerCase(),
            toUserId: message.toUserId?.toLowerCase(),
          );
          _recallController.add(recallMsg);
        }

        // Dispatch to per-conversation streams.
        // For group messages, key is `group:<groupId>`.
        // For 1-to-1, key is the other user's ID (we don't know current user
        // here, so dispatch to both formUserId and toUserId streams).
        if (message.isGroupMessage) {
          final key = 'group:${message.groupId}';
          _conversationControllers[key]?.add(message);
        } else {
          // Dispatch to both possible conversation keys so the listener picks
          // it up regardless of which side they are.
          _conversationControllers[message.formUserId]?.add(message);
          if (message.toUserId != null) {
            _conversationControllers[message.toUserId!]?.add(message);
          }
        }
      } catch (e, st) {
        AppLogger.error('[SignalR] Error parsing get-chat-message', e, st);
      }
    });

    // recall-chat-message — message recall event.
    // We listen to multiple aliases to ensure coverage across backend versions.
    hub.on('recall-chat-message', _handleRecall);
    hub.on('on-recall-chat-message', _handleRecall);
    hub.on('recall-message', _handleRecall);
    hub.on('on-recall-message', _handleRecall);
    hub.on('recallChatMessage', _handleRecall);
    hub.on('RecallChatMessage', _handleRecall);

    // on-user-onlined — a user came online (tenantId, userId).
    hub.on('on-user-onlined', (List<Object?>? arguments) {
      if (arguments == null || arguments.length < 2) return;
      try {
        final userId = (arguments[1] as String).toLowerCase();
        _onlineStatusController.add({userId: true});
      } catch (e, st) {
        AppLogger.error('[SignalR] Error parsing on-user-onlined', e, st);
      }
    });

    // on-user-offlined — a user went offline (tenantId, userId).
    hub.on('on-user-offlined', (List<Object?>? arguments) {
      if (arguments == null || arguments.length < 2) return;
      try {
        final userId = (arguments[1] as String).toLowerCase();
        _onlineStatusController.add({userId: false});
      } catch (e, st) {
        AppLogger.error('[SignalR] Error parsing on-user-offlined', e, st);
      }
    });

    // on-user-typing — another user started typing (userId).
    hub.on('on-user-typing', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        final userId = (arguments[0] as String).toLowerCase();
        _typingController.add((userId: userId, isTyping: true));
      } catch (e, st) {
        AppLogger.error('[SignalR] Error parsing on-user-typing', e, st);
      }
    });

    // on-user-stop-typing — another user stopped typing (userId).
    hub.on('on-user-stop-typing', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        final userId = (arguments[0] as String).toLowerCase();
        _typingController.add((userId: userId, isTyping: false));
      } catch (e, st) {
        AppLogger.error('[SignalR] Error parsing on-user-stop-typing', e, st);
      }
    });

    // on-messages-read — read receipt event.
    hub.on('on-messages-read', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        final data = arguments[0] as Map<String, dynamic>;
        final event = ImMessagesReadEvent.fromJson(data);
        _messagesReadController.add(event);
      } catch (e, st) {
        AppLogger.error('[SignalR] Error parsing on-messages-read', e, st);
      }
    });

    // on-group-user-joined — a user joined a group.
    hub.on('on-group-user-joined', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        final data = arguments[0] as Map<String, dynamic>;
        final event = ImGroupUserChangedEvent.fromJson(data);
        _groupUserChangedController.add(event);
      } catch (e, st) {
        AppLogger.error(
            '[SignalR] Error parsing on-group-user-joined', e, st);
      }
    });

    // on-group-user-removed — a user was removed from a group.
    hub.on('on-group-user-removed', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        final data = arguments[0] as Map<String, dynamic>;
        final event = ImGroupUserChangedEvent.fromJson(data);
        _groupUserChangedController.add(event);
      } catch (e, st) {
        AppLogger.error(
            '[SignalR] Error parsing on-group-user-removed', e, st);
      }
    });

    // on-group-info-updated — group metadata changed.
    hub.on('on-group-info-updated', (List<Object?>? arguments) {
      if (arguments == null || arguments.isEmpty) return;
      try {
        final data = arguments[0] as Map<String, dynamic>;
        final event = ImGroupInfoUpdatedEvent.fromJson(data);
        _groupInfoUpdatedController.add(event);
      } catch (e, st) {
        AppLogger.error(
            '[SignalR] Error parsing on-group-info-updated', e, st);
      }
    });
  }

  void _handleRecall(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;
    try {
      AppLogger.debug('[SignalR] Recall event received. Args: $arguments');

      ImChatMessage message;
      final arg0 = arguments[0];

      if (arg0 is String && arguments.length >= 2 && arguments[1] is String) {
        // Pattern: (conversationId, messageId) or vice versa.
        // We assume the one with : or GUID-like is the conversation/message.
        // To be safe, try both. If one looks like a GUID, it's likely the messageId.
        String cid = arg0;
        String mid = arguments[1] as String;
        
        // If mid is not a GUID but cid is, swap them. 
        // Actually, just create a message with mid.
        message = ImChatMessage(
          messageId: mid.toLowerCase(),
          groupId: cid.startsWith('group:') ? cid.substring(6) : '',
          formUserId: cid.startsWith('group:') ? '' : cid,
          formUserName: '',
          content: '',
          sendTime: '',
          messageType: ImMessageType.text.value,
          source: ImMessageSourceType.user.value,
        );
      } else if (arg0 is String) {
        // Payload is just the messageId.
        message = ImChatMessage(
          messageId: arg0.toLowerCase(),
          formUserId: '',
          formUserName: '',
          content: '',
          sendTime: '',
          messageType: ImMessageType.text.value,
          source: ImMessageSourceType.user.value,
        );
      } else if (arg0 is Map<String, dynamic>) {
        // Payload is a full message object (a NEW system message for the recall notification).
        // The REAL recalled messageId is in extraProperties.MessageId (Web pattern: useChatBell.ts:344).
        message = ImChatMessage.fromJson(arg0);

        // Extract the original recalled message ID from extraProperties.
        final extraMessageId = message.extraProperties?['MessageId'] as String?
            ?? message.extraProperties?['messageId'] as String?;
        final realRecalledId = (extraMessageId ?? message.messageId).toLowerCase();

        AppLogger.info('[SignalR] Recall: systemMsgId=${message.messageId}, '
            'realRecalledId=$realRecalledId, '
            'extraProperties=${message.extraProperties}');

        message = message.copyWith(
          messageId: realRecalledId,
          formUserId: message.formUserId.toLowerCase(),
          toUserId: message.toUserId?.toLowerCase(),
        );
      } else {
        AppLogger.warning('[SignalR] Unknown recall payload type: ${arg0.runtimeType}');
        return;
      }

      _recallController.add(message);
    } catch (e, st) {
      AppLogger.error('[SignalR] Error parsing recall event', e, st);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _ensureConnected() {
    if (_hubConnection == null ||
        _hubConnection!.state != HubConnectionState.Connected) {
      throw StateError(
        '[SignalR] Hub is not connected. Current state: '
        '${_hubConnection?.state}',
      );
    }
  }

  /// Dispose all resources. Call on app shutdown or logout.
  void dispose() {
    _hubConnection?.stop();
    _globalMessageController.close();
    for (final c in _conversationControllers.values) {
      c.close();
    }
    _conversationControllers.clear();
    _onlineStatusController.close();
    _typingController.close();
    _recallController.close();
    _messagesReadController.close();
    _groupUserChangedController.close();
    _groupInfoUpdatedController.close();
    connectionState.dispose();
  }
}
