import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_room.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';

/// Action item for the custom share panel.
class ShareAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const ShareAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// WeChat-style custom share bottom sheet.
///
/// - First row: recent conversations (horizontal scroll, avatar + name)
/// - Second row: action buttons (forward, download, etc.)
Future<void> showCustomShareSheet(
  BuildContext context, {
  required WidgetRef ref,
  required List<ShareAction> actions,
  void Function(ChatRoom room)? onQuickForward,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomShareSheetContent(
      ref: ref,
      actions: actions,
      onQuickForward: onQuickForward,
    ),
  );
}

class _CustomShareSheetContent extends StatelessWidget {
  final WidgetRef ref;
  final List<ShareAction> actions;
  final void Function(ChatRoom room)? onQuickForward;

  const _CustomShareSheetContent({
    required this.ref,
    required this.actions,
    this.onQuickForward,
  });

  @override
  Widget build(BuildContext context) {
    final rooms = ref.read(chatRoomsProvider).valueOrNull ?? [];
    // Show up to 10 recent conversations.
    final recentRooms = rooms.take(10).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Recent conversations row
            if (recentRooms.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '最近会话',
                    style: TextStyle(
                      fontSize: 12,
                      color: EbiColors.textSecondary,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: recentRooms.length,
                  itemBuilder: (context, index) {
                    final room = recentRooms[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                        onQuickForward?.call(room);
                      },
                      child: Container(
                        width: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: room.isGroup
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade100,
                              child: Icon(
                                room.isGroup ? Icons.group : Icons.person,
                                size: 22,
                                color: room.isGroup
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              room.name,
                              style: const TextStyle(fontSize: 11),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Divider(height: 1, color: EbiColors.divider),
            ],
            // Action buttons row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: actions.map((action) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      action.onTap();
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            action.icon,
                            size: 24,
                            color: EbiColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          action.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: EbiColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            // Cancel button
            Divider(height: 1, color: EbiColors.divider),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text(
                '取消',
                style: TextStyle(
                  fontSize: 16,
                  color: EbiColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
