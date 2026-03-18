import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/chat_room.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/repository/chat_repository.dart';
import 'package:ebi_chat/src/repository/mock_chat_repository.dart';
import 'package:ebi_chat/src/repository/signalr_chat_repository.dart';
import 'package:ebi_chat/src/services/signalr_connection_manager.dart';

// ── Feature flag ──────────────────────────────────────────────────────────
// Set to true to use the real ABP IM backend via SignalR + REST.
// When false, the app falls back to MockChatRepository.
const bool kUseSignalR = true;

// ── SignalR Connection Manager ────────────────────────────────────────────

/// Provides the shared [SignalRConnectionManager] singleton.
///
/// Depends on [tokenStorageProvider] and [tenantStorageProvider] from ebi_core.
/// Call `ref.read(signalRConnectionProvider).connect()` after login.
final signalRConnectionProvider = Provider<SignalRConnectionManager>((ref) {
  final tokenStorage = ref.read(tokenStorageProvider);
  final tenantStorage = ref.read(tenantStorageProvider);

  final manager = SignalRConnectionManager(
    baseUrl: AppConfig.signalRServer,
    tokenStorage: tokenStorage,
    tenantStorage: tenantStorage,
  );

  ref.onDispose(manager.dispose);
  return manager;
});

/// Observable connection state for UI indicators (e.g. "Reconnecting...").
final signalRStateProvider = Provider<SignalRConnectionState>((ref) {
  final manager = ref.watch(signalRConnectionProvider);
  return manager.connectionState.value;
});

// ── Current User ID ─────────────────────────────────────────────────────

/// Provides the current user ID from auth state, used by mappers.
final currentUserIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user?.id ?? '';
});

// ── Chat Repository ───────────────────────────────────────────────────────

/// Chat repository provider — uses SignalR when [kUseSignalR] is true,
/// otherwise falls back to [MockChatRepository] for offline development.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  if (kUseSignalR) {
    final connectionManager = ref.read(signalRConnectionProvider);
    final apiClient = ref.read(apiClientProvider);
    final currentUserId = ref.read(currentUserIdProvider);
    final repo = SignalRChatRepository(
      connectionManager: connectionManager,
      apiClient: apiClient,
      currentUserId: currentUserId,
    );
    ref.onDispose(repo.dispose);
    return repo;
  }

  // Mock mode for UI development.
  final repo = MockChatRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

// ── Data providers ────────────────────────────────────────────────────────

/// Conversation list with real-time unread count updates.
/// Like the web's Pinia store: loads from API, then listens to SignalR
/// globalMessageStream to increment unreadCount + update lastMessage.
final chatRoomsProvider =
    StateNotifierProvider<ChatRoomsNotifier, AsyncValue<List<ChatRoom>>>((ref) {
  final repo = ref.read(chatRepositoryProvider);
  final manager = ref.read(signalRConnectionProvider);
  final currentUserId = ref.read(currentUserIdProvider);
  return ChatRoomsNotifier(
    repo: repo,
    manager: manager,
    currentUserId: currentUserId,
  );
});

class ChatRoomsNotifier extends StateNotifier<AsyncValue<List<ChatRoom>>> {
  final ChatRepository repo;
  final SignalRConnectionManager manager;
  final String currentUserId;
  StreamSubscription<ImChatMessage>? _messageSub;
  StreamSubscription<ImChatMessage>? _recallSub;
  StreamSubscription<ImGroupInfoUpdatedEvent>? _groupUpdateSub;

  ChatRoomsNotifier({
    required this.repo,
    required this.manager,
    required this.currentUserId,
  }) : super(const AsyncValue.loading()) {
    _load();
    _listenToMessages();
    _listenToRecalls();
    _listenToGroupUpdates();
  }

  Future<void> _load() async {
    try {
      final rooms = await repo.getConversations();
      if (mounted) state = AsyncValue.data(rooms);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  /// Reload from API (e.g. after marking as read).
  Future<void> refresh() async {
    try {
      final rooms = await repo.getConversations();
      if (mounted) state = AsyncValue.data(rooms);
    } catch (_) {}
  }

  void _listenToMessages() {
    _messageSub = manager.globalMessageStream.listen((imMsg) {
      if (!mounted) return;
      // Skip recall messages — they're handled by _listenToRecalls.
      // Backend may send recalls with state==10 OR as system source with recall text.
      if (imMsg.state == 10) return;
      if (imMsg.sourceEnum == ImMessageSourceType.system &&
          imMsg.content.contains('撤回了一条消息')) return;
      final rooms = state.valueOrNull;
      if (rooms == null) return;

      // Determine the conversation key (same logic as web).
      final isGroupMessage = imMsg.groupId.isNotEmpty;
      final isSelf = imMsg.formUserId == currentUserId;
      final conversationKey = isGroupMessage
          ? 'group:${imMsg.groupId}'
          : (isSelf ? (imMsg.toUserId ?? '') : imMsg.formUserId);

      if (conversationKey.isEmpty) return;

      final idx = rooms.indexWhere((r) => r.id == conversationKey);
      if (idx >= 0) {
        // Update existing conversation.
        final room = rooms[idx];
        final updated = room.copyWith(
          lastMessage: imMsg.content,
          lastMessageId: imMsg.messageId, // CRITICAL: Update this for recall matching!
          lastSenderName: isSelf ? null : imMsg.formUserName,
          lastMessageAt: DateTime.tryParse(imMsg.sendTime) ?? DateTime.now(),
          unreadCount: isSelf ? room.unreadCount : room.unreadCount + 1,
        );
        final newList = List<ChatRoom>.from(rooms);
        newList[idx] = updated;
        // Move to top (most recent conversation first).
        newList.removeAt(idx);
        newList.insert(0, updated);
        state = AsyncValue.data(newList);
      } else {
        // New conversation — trigger a full refresh to get proper metadata.
        refresh();
      }
    });
  }

  void _listenToRecalls() {
    _recallSub = manager.recallStream.listen((imMsg) {
      if (!mounted) return;
      final rooms = state.valueOrNull;
      if (rooms == null) return;

      // The recall event sends a NEW system message. The real recalled message ID
      // may be in extraProperties.MessageId (Web pattern: useChatBell.ts:344).
      final extraMessageId = imMsg.extraProperties?['MessageId'] as String?
          ?? imMsg.extraProperties?['messageId'] as String?;
      final recalledMessageId = (extraMessageId ?? imMsg.messageId).toLowerCase();
      final formUserId = imMsg.formUserId.toLowerCase();
      final toUserId = imMsg.toUserId?.toLowerCase();
      final currentLower = currentUserId.toLowerCase();

      AppLogger.info('[ChatRooms] Recall event: recalledMsgId=$recalledMessageId, '
          'formUserId=$formUserId, toUserId=$toUserId, '
          'groupId=${imMsg.groupId}, currentUserId=$currentLower');
      AppLogger.info('[ChatRooms] Room IDs: ${rooms.map((r) => 'id=${r.id}, lastMsgId=${r.lastMessageId}').join(' | ')}');

      // 1. Prioritize global scan by messageId (most robust).
      int idx = rooms.indexWhere((r) => r.lastMessageId?.toLowerCase() == recalledMessageId);
      if (idx >= 0) {
        AppLogger.info('[ChatRooms] Matched room by lastMessageId at idx=$idx');
      }

      // 2. Fallback to conversationKey matching if messageId match failed.
      if (idx < 0) {
        final isGroupMessage = imMsg.groupId.isNotEmpty;
        
        // Build all possible conversation keys to try.
        final keysToTry = <String>[];
        if (isGroupMessage) {
          keysToTry.add('group:${imMsg.groupId}');
        } else {
          // The recall notification preserves the original message's formUserId/toUserId.
          // For 1-to-1 chat, the conversation key is the OTHER person's userId.
          // We try both formUserId and toUserId as potential keys since we don't
          // know which one represents the "other" person relative to currentUser.
          if (formUserId.isNotEmpty && formUserId != currentLower) {
            keysToTry.add(formUserId);
          }
          if (toUserId != null && toUserId.isNotEmpty && toUserId != currentLower) {
            keysToTry.add(toUserId);
          }
          // Also try with currentUserId excluded — the conversation key is always
          // the OTHER person's ID.
          if (formUserId.isNotEmpty) keysToTry.add(formUserId);
          if (toUserId != null && toUserId.isNotEmpty) keysToTry.add(toUserId);
        }
        
        AppLogger.info('[ChatRooms] Trying conversation keys: $keysToTry');
        
        for (final key in keysToTry) {
          idx = rooms.indexWhere((r) => r.id.toLowerCase() == key.toLowerCase());
          if (idx >= 0) {
            AppLogger.info('[ChatRooms] Matched room by conversationKey=$key at idx=$idx');
            break;
          }
        }
      }

      if (idx >= 0) {
        final room = rooms[idx];
        final newList = List<ChatRoom>.from(rooms);
        
        final isSelf = formUserId == currentLower;

        // Build recall display text.
        // - Direct chats: room.name IS the other person's name (reliable).
        // - Group chats: recall notification's formUserName is "system",
        //   so just show the recall text without a person prefix.
        String recallText;
        if (isSelf) {
          recallText = '你撤回了一条消息';
        } else if (room.type == ChatRoomType.direct) {
          recallText = '${room.name}撤回了一条消息';
        } else {
          // For groups, try formUserName; skip if it's "system" or empty.
          final name = imMsg.formUserName;
          if (name.isNotEmpty && name.toLowerCase() != 'system') {
            recallText = '$name撤回了一条消息';
          } else {
            recallText = '撤回了一条消息';
          }
        }

        newList[idx] = room.copyWith(
          lastMessage: recallText,
          lastSenderName: '', // Clear so tile doesn't prepend "system:"
        );
        state = AsyncValue.data(newList);
        AppLogger.info('[ChatRooms] Recall UI updated for room ${room.id}');
      } else {
        AppLogger.warning('[ChatRooms] Could not match recall to any room! '
            'recalledMsgId=$recalledMessageId, formUserId=$formUserId, toUserId=$toUserId');
      }
    });
  }

  void _listenToGroupUpdates() {
    _groupUpdateSub = manager.groupInfoUpdatedStream.listen((event) {
      if (!mounted) return;
      final rooms = state.valueOrNull;
      if (rooms == null) return;

      final conversationKey = 'group:${event.groupId}';
      final idx = rooms.indexWhere((r) => r.id == conversationKey);
      if (idx >= 0) {
        final room = rooms[idx];
        // event.name could be null if only notice was updated
        // We only care if name or avatar was updated since they are shown in ChatRoom
        if (event.name != null && event.name != room.name || 
            event.avatarUrl != null && event.avatarUrl != room.avatar) {
          final updated = room.copyWith(
            name: event.name ?? room.name,
            avatar: event.avatarUrl ?? room.avatar,
          );
          final newList = List<ChatRoom>.from(rooms);
          newList[idx] = updated;
          state = AsyncValue.data(newList);
          AppLogger.info('[ChatRooms] Group info UI updated for room ${room.id}');
        }
      }
    });
  }

  /// Clear unread count for a conversation (called when user enters chat).
  void clearUnreadCount(String conversationKey) {
    final rooms = state.valueOrNull;
    if (rooms == null) return;
    final idx = rooms.indexWhere((r) => r.id == conversationKey);
    if (idx < 0) return;
    final room = rooms[idx];
    if (room.unreadCount == 0) return;
    final newList = List<ChatRoom>.from(rooms);
    newList[idx] = room.copyWith(unreadCount: 0);
    state = AsyncValue.data(newList);
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _recallSub?.cancel();
    _groupUpdateSub?.cancel();
    super.dispose();
  }
}

/// Messages for a specific conversation.
/// conversationId is a userId for 1-to-1, or `group:<groupId>` for groups.
final chatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, conversationId) async {
  final repo = ref.read(chatRepositoryProvider);
  if (conversationId.startsWith('group:')) {
    return repo.getGroupMessages(conversationId.substring(6));
  }
  return repo.getUserMessages(conversationId);
});

/// Message stream for a specific conversation.
final messageStreamProvider =
    StreamProvider.family<ChatMessage, String>((ref, conversationId) {
  final repo = ref.read(chatRepositoryProvider);
  return repo.messageStream(conversationId);
});

/// Typing indicator stream.
final typingIndicatorProvider = StreamProvider.family<
    ({String userId, bool isTyping}), String>((ref, conversationId) {
  final manager = ref.read(signalRConnectionProvider);
  return manager.typingStream.where((e) => e.userId == conversationId);
});
