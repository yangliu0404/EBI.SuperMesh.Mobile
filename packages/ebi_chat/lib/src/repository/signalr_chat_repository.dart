import 'dart:async';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/chat_room.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/models/im_mappers.dart';
import 'package:ebi_chat/src/repository/chat_repository.dart';
import 'package:ebi_chat/src/services/signalr_connection_manager.dart';

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
    if (_connectionManager.isConnected) {
      final messageId = await _connectionManager.sendMessage(message);
      return messageId ?? message.messageId;
    }

    // Fallback: send via REST API when SignalR is unavailable.
    try {
      final response = await _apiClient.post(
        ApiEndpoints.imSendMessage,
        data: message.toJson(),
      );
      final result = ImChatMessageSendResult.fromJson(
        response.data as Map<String, dynamic>,
      );
      return result.messageId;
    } catch (e, st) {
      AppLogger.error('[SignalRChatRepo] sendMessage REST failed', e, st);
      rethrow;
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
