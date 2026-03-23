import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';
import 'package:ebi_chat/src/widgets/chat_room_tile.dart';
import 'package:ebi_chat/src/widgets/notification_section.dart';
import 'package:ebi_chat/src/providers/call_providers.dart';
import 'package:ebi_chat/src/pages/incoming_call_page.dart';

/// Message center page — notification aggregation + conversation list.
class ChatRoomListPage extends ConsumerStatefulWidget {
  final void Function(String roomId, String roomName, int unreadCount)? onRoomTap;

  const ChatRoomListPage({super.key, this.onRoomTap});

  @override
  ConsumerState<ChatRoomListPage> createState() => _ChatRoomListPageState();
}

class _ChatRoomListPageState extends ConsumerState<ChatRoomListPage> {
  final _swipeController = SwipeActionController();

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      _swipeController.closeAll();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(chatRoomsProvider);

    ref.listen<CallState>(callStateProvider, (prev, next) {
      if (next.hasIncomingCall && (prev == null || !prev.hasIncomingCall)) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const IncomingCallPage(),
            fullscreenDialog: true,
          ),
        );
      }
    });

    return Scaffold(
      appBar: EbiAppBar(title: ref.L('Messages'), showBack: false),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: ref.L('SearchConversations'),
                  prefixIcon: const Icon(Icons.search, color: EbiColors.textHint, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintStyle: const TextStyle(color: EbiColors.textHint, fontSize: 14),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: roomsAsync.when(
              loading: () => EbiLoading(message: ref.L('LoadingMessages')),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EbiEmptyState(
                      icon: Icons.error_outline,
                      title: ref.L('FailedToLoad'),
                      subtitle: e.toString(),
                    ),
                    const SizedBox(height: 16),
                    EbiButton(
                      text: ref.L('Retry'),
                      onPressed: () => ref.read(chatRoomsProvider.notifier).refresh(),
                    ),
                  ],
                ),
              ),
              data: (rooms) => NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: RefreshIndicator(
                  onRefresh: () async {
                    _swipeController.closeAll();
                    await ref.read(chatRoomsProvider.notifier).refresh();
                  },
                  child: rooms.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 120),
                          EbiEmptyState(
                            icon: Icons.chat_bubble_outline,
                            title: ref.L('NoConversations'),
                            subtitle: ref.L('PullDownToRefresh'),
                          ),
                        ])
                      : ListView(
                          children: [
                            const NotificationSection(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Text(
                                ref.L('Conversations'),
                                style: EbiTextStyles.labelSmall.copyWith(
                                  color: EbiColors.textHint, letterSpacing: 1.0),
                              ),
                            ),
                            ...rooms.map((room) => ChatRoomTile(
                              key: ValueKey(room.id),
                              room: room,
                              swipeController: _swipeController,
                              onTap: () {
                                _swipeController.closeAll();
                                widget.onRoomTap?.call(room.id, room.name, room.unreadCount);
                              },
                              onMarkUnread: () {
                                final notifier = ref.read(chatRoomsProvider.notifier);
                                if (room.unreadCount > 0) {
                                  // Mark as read: clear force-unread + notify server.
                                  notifier.clearUnreadCount(room.id);
                                  final repo = ref.read(chatRepositoryProvider);
                                  if (room.id.startsWith('group:')) {
                                    repo.readGroupConversation(
                                        room.id.substring(6), room.lastMessageId ?? '');
                                  } else {
                                    repo.markConversationAsRead(room.id);
                                  }
                                } else {
                                  // Mark as unread: persisted locally.
                                  notifier.markAsUnread(room.id);
                                }
                              },
                              onPin: () async {
                                final repo = ref.read(chatRepositoryProvider);
                                final newPinned = !room.isPinned;
                                try {
                                  final convId = room.id.startsWith('group:')
                                      ? room.id.substring(6)
                                      : room.id;
                                  await repo.pinConversation(convId, newPinned);
                                  ref.read(chatRoomsProvider.notifier).refresh();
                                } catch (_) {}
                              },
                              onDelete: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('删除功能开发中')),
                                );
                              },
                            )),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
