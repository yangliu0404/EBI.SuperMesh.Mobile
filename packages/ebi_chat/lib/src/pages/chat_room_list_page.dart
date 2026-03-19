import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';
import 'package:ebi_chat/src/widgets/chat_room_tile.dart';
import 'package:ebi_chat/src/widgets/notification_section.dart';
import 'package:ebi_chat/src/providers/call_providers.dart';
import 'package:ebi_chat/src/pages/incoming_call_page.dart';

/// Message center page — notification aggregation + conversation list.
class ChatRoomListPage extends ConsumerWidget {
  /// Callback with (roomId, roomName, unreadCount) when a conversation is tapped.
  final void Function(String roomId, String roomName, int unreadCount)? onRoomTap;

  const ChatRoomListPage({super.key, this.onRoomTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(chatRoomsProvider);

    // Global listener for incoming calls
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
      appBar: const EbiAppBar(title: 'Messages', showBack: false),
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
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  prefixIcon:
                      Icon(Icons.search, color: EbiColors.textHint, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintStyle: TextStyle(color: EbiColors.textHint, fontSize: 14),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: roomsAsync.when(
              loading: () => const EbiLoading(message: 'Loading messages...'),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EbiEmptyState(
                      icon: Icons.error_outline,
                      title: 'Failed to load',
                      subtitle: e.toString(),
                    ),
                    const SizedBox(height: 16),
                    EbiButton(
                      text: 'Retry',
                      onPressed: () => ref.read(chatRoomsProvider.notifier).refresh(),
                    ),
                  ],
                ),
              ),
              data: (rooms) => RefreshIndicator(
                onRefresh: () async {
                  await ref.read(chatRoomsProvider.notifier).refresh();
                },
                child: rooms.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          EbiEmptyState(
                            icon: Icons.chat_bubble_outline,
                            title: 'No Conversations',
                            subtitle: 'Pull down to refresh',
                          ),
                        ],
                      )
                    : ListView(
                        children: [
                          // Notification section
                          const NotificationSection(),

                          // Conversations header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Text(
                              'Conversations',
                              style: EbiTextStyles.labelSmall.copyWith(
                                color: EbiColors.textHint,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),

                          // Room list
                          ...rooms.map(
                            (room) => ChatRoomTile(
                              room: room,
                              onTap: () => onRoomTap?.call(
                                  room.id, room.name, room.unreadCount),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
