import 'dart:async';
import 'dart:convert';
import 'package:ebi_core/ebi_core.dart';
import 'package:drift/drift.dart';
import 'package:ebi_storage/ebi_storage.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/chat_room.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/models/im_mappers.dart';
import 'package:ebi_chat/src/repository/chat_repository.dart';
import 'package:ebi_chat/src/services/signalr_connection_manager.dart';
import 'package:uuid/uuid.dart';

/// Real [ChatRepository] backed by SignalR (real-time) + REST API (history).
///
/// Uses ABP IM endpoints:
///   - `GET /api/im/chat/my-last-messages` → conversation list
///   - `GET /api/im/chat/my-messages` → 1-to-1 message history
///   - `GET /api/im/chat/group/messages` → group message history
///   - SignalR `send` → send message
///   - SignalR `read-conversation` → mark conversation as read
class SignalRChatRepository implements ChatRepository {
  final SignalRConnectionManager _connectionManager;
  final ApiClient _apiClient;
  final String currentUserId;

  MessageDao? messageDao;
  ConversationDao? conversationDao;

  /// Local message cache per conversation.
  final Map<String, List<ChatMessage>> _messageCache = {};

  /// Tracks groups the client has joined on the hub.
  final Set<String> _joinedGroups = {};

  /// Per-conversation stream subscriptions from the connection manager.
  final Map<String, StreamSubscription<ImChatMessage>> _convSubs = {};

  /// Per-conversation broadcast controllers exposed to the UI.
  final Map<String, StreamController<ChatMessage>> _convBroadcasts = {};

  SignalRChatRepository({
    required SignalRConnectionManager connectionManager,
    required ApiClient apiClient,
    required this.currentUserId,
  })  : _connectionManager = connectionManager,
        _apiClient = apiClient {
    _connectionManager.onReconnected = _onReconnected;
  }

  // ── ChatRepository: getConversations ────────────────────────────────────

  @override
  Future<List<ChatRoom>> getConversations({int? maxResultCount}) async {
    try {
      final queryParams = <String, dynamic>{
        'sorting': 'sendTime desc',
        'maxResultCount': maxResultCount ?? 50,
      };

      final response = await _apiClient.get(
        ApiEndpoints.imMyLastMessages,
        queryParameters: queryParams,
      );

      // ABP WrapResult format: {code, message, result: {items: [...]}}
      // _WrapResultInterceptor does NOT unwrap, so we handle both formats.
      final data = response.data;
      AppLogger.debug('[SignalRChatRepo] my-last-messages response type: ${data.runtimeType}');

      final List<dynamic> items;
      if (data is Map<String, dynamic>) {
        // Unwrap ABP WrapResult: result.items
        final result = data['result'];
        if (result is Map<String, dynamic> && result.containsKey('items')) {
          items = result['items'] as List<dynamic>;
        } else if (data.containsKey('items')) {
          items = data['items'] as List<dynamic>;
        } else {
          AppLogger.warning('[SignalRChatRepo] Unexpected data format: $data');
          items = [];
        }
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }

      AppLogger.debug('[SignalRChatRepo] Parsed ${items.length} conversations, currentUserId=$currentUserId');

      final rooms = items
          .map((e) => ImLastChatMessage.fromJson(e as Map<String, dynamic>))
          .map((e) => e.toUiRoom(currentUserId))
          .toList();

      // Auto-join SignalR groups for any group conversations.
      for (final room in rooms) {
        if (room.id.startsWith('group:')) {
          final groupId = room.id.substring(6);
          _joinGroup(groupId);
        }
      }

      // Fetch conversation settings (pin/mute) from dedicated API,
      // same as Web's getMySettingsApi().
      try {
        final settingsResponse = await _apiClient.get(
          ApiEndpoints.imConversationSettings,
        );
        final settingsItems = _extractItems(settingsResponse.data);
        AppLogger.info('[SignalRChatRepo] Settings API returned ${settingsItems.length} items');
        final settingsMap = <String, Map<String, dynamic>>{};
        for (final s in settingsItems) {
          final map = s as Map<String, dynamic>;
          final convId = (map['conversationId'] as String?)?.toLowerCase();
          if (convId != null) {
            settingsMap[convId] = map;
            final isPinned = map['isPinned'];
            final isMuted = map['isMuted'];
            if (isPinned == true || isMuted == true) {
              AppLogger.info('[SignalRChatRepo] Setting: convId=$convId, isPinned=$isPinned, isMuted=$isMuted');
            }
          }
        }

        // Merge settings into rooms.
        // Backend may return conversationId with or without 'group:' prefix.
        // For groups, prefer the raw groupId key (without prefix) since that's
        // the authoritative setting record.
        for (int i = 0; i < rooms.length; i++) {
          final roomId = rooms[i].id.toLowerCase();
          Map<String, dynamic>? setting;

          if (roomId.startsWith('group:')) {
            final rawId = roomId.substring(6);
            // Prefer raw groupId (authoritative), fallback to prefixed.
            setting = settingsMap[rawId] ?? settingsMap[roomId];
          } else {
            setting = settingsMap[roomId];
          }

          if (setting != null) {
            rooms[i] = rooms[i].copyWith(
              isPinned: setting['isPinned'] as bool? ?? false,
              isMuted: setting['isMuted'] as bool? ?? false,
            );
          }
        }
      } catch (e) {
        AppLogger.debug('[SignalRChatRepo] getConversationSettings failed: $e');
      }

      // Sort: pinned first, then by lastMessageAt descending.
      rooms.sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final aTime = a.lastMessageAt ?? DateTime(2000);
        final bTime = b.lastMessageAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      // Save to local DB (server data overwrites local).
      _saveConversationsToDb(rooms);

      return rooms;
    } catch (e, st) {
      AppLogger.error('[SignalRChatRepo] getConversations failed', e, st);
      rethrow;
    }
  }

  // ── ChatRepository: getUserMessages ─────────────────────────────────────

  @override
  Future<List<ChatMessage>> getUserMessages(
    String receiveUserId, {
    int skipCount = 0,
    int maxResultCount = 50,
    int? messageType,
  }) async {
    try {
      AppLogger.debug('[SignalRChatRepo] getUserMessages receiveUserId=$receiveUserId');
      final response = await _apiClient.get(
        ApiEndpoints.imMyMessages,
        queryParameters: {
          'receiveUserId': receiveUserId,
          'skipCount': skipCount,
          'maxResultCount': maxResultCount,
          'sorting': 'CreationTime desc',
          if (messageType != null) 'messageType': messageType,
        },
      );

      final items = _extractItems(response.data);
      AppLogger.debug('[SignalRChatRepo] getUserMessages got ${items.length} messages');

      final messages = items
          .map((e) => ImChatMessage.fromJson(e as Map<String, dynamic>))
          .map((e) => e.toUiMessage(currentUserId))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // asc for UI

      // Cache (first page replaces, subsequent pages append).
      if (skipCount == 0) {
        _messageCache[receiveUserId] = messages;
      } else {
        _messageCache[receiveUserId] ??= [];
        _messageCache[receiveUserId]!.addAll(messages);
      }

      // Save to local DB.
      _saveMessagesToDb(messages);

      return messages;
    } catch (e, st) {
      AppLogger.error('[SignalRChatRepo] getUserMessages failed', e, st);
      rethrow;
    }
  }

  // ── ChatRepository: getGroupMessages ────────────────────────────────────

  @override
  Future<List<ChatMessage>> getGroupMessages(
    String groupId, {
    int skipCount = 0,
    int maxResultCount = 50,
    int? messageType,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.imGroupMessages,
        queryParameters: {
          'groupId': groupId,
          'skipCount': skipCount,
          'maxResultCount': maxResultCount,
          'sorting': 'CreationTime desc',
          if (messageType != null) 'messageType': messageType,
        },
      );

      final convId = 'group:$groupId';
      final items = _extractItems(response.data);
      final messages = items
          .map((e) => ImChatMessage.fromJson(e as Map<String, dynamic>))
          .map((e) => e.toUiMessage(currentUserId))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // asc for UI

      if (skipCount == 0) {
        _messageCache[convId] = messages;
      } else {
        _messageCache[convId] ??= [];
        _messageCache[convId]!.addAll(messages);
      }

      // Ensure we've joined this group on SignalR.
      _joinGroup(groupId);

      // Save to local DB.
      _saveMessagesToDb(messages);

      return messages;
    } catch (e, st) {
      AppLogger.error('[SignalRChatRepo] getGroupMessages failed', e, st);
      rethrow;
    }
  }

  @override
  Future<List<ChatMessage>> getMediaMessages({
    String? groupId,
    String? receiveUserId,
    int skipCount = 0,
    int maxResultCount = 50,
  }) async {
    try {
      final imgFuture = groupId != null
          ? getGroupMessages(groupId, skipCount: skipCount, maxResultCount: maxResultCount, messageType: ImMessageType.image.value)
          : getUserMessages(receiveUserId!, skipCount: skipCount, maxResultCount: maxResultCount, messageType: ImMessageType.image.value);
          
      final vidFuture = groupId != null
          ? getGroupMessages(groupId, skipCount: skipCount, maxResultCount: maxResultCount, messageType: ImMessageType.video.value)
          : getUserMessages(receiveUserId!, skipCount: skipCount, maxResultCount: maxResultCount, messageType: ImMessageType.video.value);

      final results = await Future.wait([imgFuture, vidFuture]);
      final List<ChatMessage> combined = [...results[0], ...results[1]];
      
      // Sort ascending for UI consistency or descending if fetching paginated history?
      // Usually gallery wants descending (newest first) or ascending. 
      // We match the ascending sort of getGroupMessages for UI, or we can just sort by createdAt asc.
      combined.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Remove duplicates just in case
      final Map<String, ChatMessage> unique = {};
      for (var m in combined) {
        unique[m.id] = m;
      }
      final sortedUnique = unique.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      return sortedUnique;
    } catch (e, st) {
      AppLogger.error('[SignalRChatRepo] getMediaMessages failed', e, st);
      rethrow;
    }
  }

  // ── ChatRepository: sendMessage ─────────────────────────────────────────

  @override
  Future<String> sendMessage(ImChatMessage message) async {
    // 1. Save to local DB immediately with syncState = 1 (pendingSend).
    final roomId = message.isGroupMessage
        ? 'group:${message.groupId}'
        : (message.toUserId ?? '');
    try {
      await messageDao?.upsertMessage(MessagesCompanion(
        messageId: Value(message.messageId),
        tenantId: Value(message.tenantId),
        groupId: Value(message.groupId),
        formUserId: Value(message.formUserId),
        formUserName: Value(message.formUserName),
        toUserId: Value(message.toUserId),
        content: Value(message.content),
        sendTime: Value(message.sendTime),
        isAnonymous: Value(message.isAnonymous),
        messageType: Value(message.messageType),
        source: Value(message.source),
        state: Value(message.state),
        extraProperties: Value(message.extraProperties != null
            ? _jsonEncode(message.extraProperties!)
            : null),
        roomId: Value(roomId),
        syncState: const Value(1), // pendingSend
        localCreatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    } catch (_) {}

    // 2. Try to send via SignalR or REST.
    try {
      String finalMsgId;
      if (_connectionManager.isConnected) {
        final messageId = await _connectionManager.sendMessage(message);
        finalMsgId = messageId ?? message.messageId;
      } else {
        // Fallback: send via REST API when SignalR is unavailable.
        final response = await _apiClient.post(
          ApiEndpoints.imSendMessage,
          data: message.toJson(),
        );
        final result = ImChatMessageSendResult.fromJson(
          response.data as Map<String, dynamic>,
        );
        finalMsgId = result.messageId;
      }

      _connectionManager.broadcastLocalMessage(
        message.copyWith(
          messageId: finalMsgId,
          state: ImMessageState.send.value,
        ),
      );

      // 3. On success, update syncState to 0 (synced).
      try {
        await messageDao?.updateSyncState(message.messageId, 0);
      } catch (_) {}

      return finalMsgId;
    } catch (e, st) {
      // Both SignalR and REST failed — keep as pendingSend (syncState = 1)
      // so it can be retried on network recovery.
      AppLogger.warning('[SignalRChatRepo] sendMessage failed, queued for retry: ${message.messageId}');
      AppLogger.error('[SignalRChatRepo] sendMessage error detail', e, st);
      // syncState is already 1 (pendingSend) from step 1, so no update needed.
      // Return the original messageId so the UI can display it with "sending" status.
      return message.messageId;
    }
  }

  /// Retry sending all pending messages (called on network recovery).
  Future<void> retrySendPendingMessages() async {
    final pending = await messageDao?.getPendingSend();
    if (pending == null || pending.isEmpty) return;

    AppLogger.info('[SignalRChatRepo] Retrying ${pending.length} pending messages');

    for (final msg in pending) {
      try {
        final imMsg = ImChatMessage(
          messageId: msg.messageId,
          groupId: msg.groupId ?? '',
          formUserId: msg.formUserId ?? '',
          formUserName: msg.formUserName ?? '',
          toUserId: msg.toUserId,
          content: msg.content ?? '',
          sendTime: msg.sendTime ?? DateTime.now().toIso8601String(),
          messageType: msg.messageType ?? 0,
          source: msg.source ?? 0,
          extraProperties: msg.extraProperties != null
              ? (jsonDecode(msg.extraProperties!) as Map<String, dynamic>)
              : null,
        );

        final newId = await sendMessage(imMsg);
        // Update DB: mark synced (sendMessage already does this on success,
        // but ensure it's done).
        await messageDao?.updateSyncState(msg.messageId, 0);
        AppLogger.info(
            '[SignalRChatRepo] Pending message sent: ${msg.messageId} -> $newId');
      } catch (e) {
        await messageDao?.updateSyncState(msg.messageId, 2); // sendFailed
        AppLogger.warning(
            '[SignalRChatRepo] Pending message failed: ${msg.messageId}');
      }
    }
  }

  static String _jsonEncode(Map<String, dynamic> map) {
    try {
      return jsonEncode(map);
    } catch (_) {
      return '{}';
    }
  }

  // ── ChatRepository: messageStream ───────────────────────────────────────

  @override
  Stream<ChatMessage> messageStream(String conversationId) {
    if (!_convBroadcasts.containsKey(conversationId)) {
      _convBroadcasts[conversationId] =
          StreamController<ChatMessage>.broadcast(onCancel: () {
        _cleanupConversation(conversationId);
      });

      // Forward messages from the connection manager, mapping to UI model.
      _convSubs[conversationId] = _connectionManager
          .conversationMessageStream(conversationId)
          .listen((imMsg) {
        final uiMsg = imMsg.toUiMessage(currentUserId);

        // De-duplicate.
        final cache = _messageCache[conversationId];
        if (cache != null && cache.any((m) => m.id == uiMsg.id)) return;

        _messageCache[conversationId] ??= [];
        _messageCache[conversationId]!.add(uiMsg);
        // Persist real-time message to DB.
        _saveMessagesToDb([uiMsg]);
        _convBroadcasts[conversationId]?.add(uiMsg);
      });
    }

    // If it's a group conversation, ensure we've joined the group.
    if (conversationId.startsWith('group:')) {
      _joinGroup(conversationId.substring(6));
    }

    return _convBroadcasts[conversationId]!.stream;
  }

  // ── ChatRepository: markConversationAsRead ──────────────────────────────

  @override
  Future<void> markConversationAsRead(String senderUserId) async {
    if (_connectionManager.isConnected) {
      await _connectionManager.markConversationAsRead(senderUserId);
    }
  }

  @override
  Future<void> readGroupConversation(
      String groupId, String lastReadMessageId) async {
    if (_connectionManager.isConnected) {
      await _connectionManager.readGroupConversation(
          groupId, lastReadMessageId);
    }
  }

  // ── ChatRepository: settings (pin/mute) ─────────────────────────────────

  @override
  Future<void> pinConversation(String conversationId, bool isPinned) async {
    AppLogger.info('[SignalRChatRepo] pinConversation: convId=$conversationId, isPinned=$isPinned');
    try {
      final response = await _apiClient.put(
        '/api/im/conversation-settings/pin',
        data: {
          'conversationId': conversationId,
          'value': isPinned,
        },
      );
      AppLogger.info('[SignalRChatRepo] pinConversation response: ${response.statusCode} ${response.data}');
    } catch (e, st) {
      AppLogger.error('[SignalRChatRepo] pinConversation failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> muteConversation(String conversationId, bool isMuted) async {
    try {
      await _apiClient.put(
        '/api/im/conversation-settings/mute',
        data: {
          'conversationId': conversationId,
          'value': isMuted,
        },
      );
    } catch (e, st) {
      AppLogger.error('[SignalRChatRepo] muteConversation failed', e, st);
      rethrow;
    }
  }

  // ── ChatRepository: deleteMessage ────────────────────────────────────────

  @override
  Future<void> deleteMessage({
    required String messageId,
    required String conversationId,
    String? groupId,
  }) async {
    try {
      await _apiClient.post(
        '/api/im/chat/messages/delete',
        data: {
          'messageId': messageId,
          'conversationId': conversationId,
          if (groupId != null) 'groupId': groupId,
        },
      );
      // Remove from local cache.
      _messageCache[conversationId]?.removeWhere((m) => m.id == messageId);
    } catch (e, st) {
      AppLogger.error('[SignalRChatRepo] deleteMessage failed', e, st);
      rethrow;
    }
  }

  // ── ChatRepository: recallMessage ───────────────────────────────────────

  @override
  Future<void> recallMessage(ImChatMessage message) async {
    try {
      // Recall is done entirely via SignalR hub (same as Web).
      await _connectionManager.recallMessage(message);
    } catch (e, st) {
      AppLogger.error('[SignalRChatRepo] recallMessage failed', e, st);
      rethrow;
    }
  }

  // ── ChatRepository: dispose ─────────────────────────────────────────────

  @override
  void dispose() {
    for (final sub in _convSubs.values) {
      sub.cancel();
    }
    _convSubs.clear();
    for (final bc in _convBroadcasts.values) {
      bc.close();
    }
    _convBroadcasts.clear();
    _messageCache.clear();
    _joinedGroups.clear();
  }

  // ── Local DB accessors ──────────────────────────────────────────────────

  /// Load conversations from local DB (for instant startup).
  Future<List<ChatRoom>> getConversationsFromDb() async {
    if (conversationDao == null) return [];
    try {
      final rows = await conversationDao!.getAllSorted();
      return rows.map((r) => r.toUiRoom()).toList();
    } catch (e) {
      AppLogger.debug('[SignalRChatRepo] Failed to load conversations from DB: $e');
      return [];
    }
  }

  /// Load messages from local DB (for instant chat open).
  Future<List<ChatMessage>> getMessagesFromDb(
    String roomId, {
    int limit = 50,
    String? beforeSendTime,
  }) async {
    if (messageDao == null) return [];
    try {
      final rows = await messageDao!.getByRoom(roomId, limit: limit, beforeSendTime: beforeSendTime);
      final messages = rows.map((r) => r.toUiMessage()).toList();
      // DB returns desc order, reverse for UI (ascending).
      return messages.reversed.toList();
    } catch (e) {
      AppLogger.debug('[SignalRChatRepo] Failed to load messages from DB: $e');
      return [];
    }
  }

  // ── DB helpers (fire-and-forget) ────────────────────────────────────────

  Future<void> _saveConversationsToDb(List<ChatRoom> rooms) async {
    try {
      final companions = rooms.map((r) => r.toDbCompanion()).toList();
      await conversationDao?.upsertConversations(companions);
    } catch (e) {
      AppLogger.debug('[SignalRChatRepo] DB save conversations failed: $e');
    }
  }

  Future<void> _saveMessagesToDb(List<ChatMessage> messages) async {
    try {
      final companions = messages.map((m) => m.toDbCompanion()).toList();
      await messageDao?.upsertMessages(companions);
    } catch (e) {
      AppLogger.debug('[SignalRChatRepo] DB save messages failed: $e');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Extract `items` array from ABP response, handling both
  /// WrapResult `{code, result: {items}}` and plain `{items}` formats.
  List<dynamic> _extractItems(dynamic data) {
    if (data is Map<String, dynamic>) {
      // ABP WrapResult: {code, message, result: {items: [...]}}
      final result = data['result'];
      if (result is Map<String, dynamic> && result.containsKey('items')) {
        return result['items'] as List<dynamic>;
      }
      // Plain ABP: {items: [...]}
      if (data.containsKey('items')) {
        return data['items'] as List<dynamic>;
      }
    }
    if (data is List) return data;
    return [];
  }

  Future<void> _joinGroup(String groupId) async {
    if (_joinedGroups.contains(groupId)) return;
    if (!_connectionManager.isConnected) return;
    try {
      await _connectionManager.joinGroup(groupId);
      _joinedGroups.add(groupId);
    } catch (e) {
      AppLogger.error('[SignalRChatRepo] joinGroup failed: $groupId', e);
    }
  }

  void _cleanupConversation(String conversationId) {
    _convSubs[conversationId]?.cancel();
    _convSubs.remove(conversationId);
    _convBroadcasts[conversationId]?.close();
    _convBroadcasts.remove(conversationId);
  }

  // ── Reconnection: offline-gap sync ──────────────────────────────────────

  Future<void> _onReconnected() async {
    AppLogger.info(
        '[SignalRChatRepo] Reconnected — re-joining groups.');

    // Re-join all previously joined groups.
    final groupsToRejoin = Set<String>.from(_joinedGroups);
    _joinedGroups.clear();
    for (final groupId in groupsToRejoin) {
      await _joinGroup(groupId);
    }
  }
}
