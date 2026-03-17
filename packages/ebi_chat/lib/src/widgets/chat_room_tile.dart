import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_room.dart';

/// A single chat room tile — visually differentiates direct, group, and channel.
class ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final VoidCallback? onTap;

  const ChatRoomTile({super.key, required this.room, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Type icon for group/channel
                      if (!room.isDirect) ...[
                        Icon(
                          room.isGroup ? Icons.group : Icons.tag,
                          size: 14,
                          color: EbiColors.textHint,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                room.name,
                                style: room.unreadCount > 0
                                    ? EbiTextStyles.labelLarge
                                    : EbiTextStyles.labelLarge.copyWith(
                                        fontWeight: FontWeight.w400,
                                      ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (room.tenantName != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: EbiColors.primaryBlue
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  room.tenantName!,
                                  style: EbiTextStyles.labelSmall.copyWith(
                                    fontSize: 10,
                                    color: EbiColors.primaryBlue,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (room.lastMessageAt != null)
                        Text(
                          _formatTime(room.lastMessageAt!),
                          style: EbiTextStyles.labelSmall.copyWith(
                            color: room.unreadCount > 0
                                ? EbiColors.primaryBlue
                                : EbiColors.textHint,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _lastMessagePreview(),
                          style: room.unreadCount > 0
                              ? EbiTextStyles.bodySmall.copyWith(
                                  color: EbiColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                )
                              : EbiTextStyles.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: EbiColors.primaryBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${room.unreadCount}',
                            style: const TextStyle(
                              color: EbiColors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Avatar with online indicator for direct chats,
  /// group icon overlay for groups, # badge for channels.
  Widget _buildAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        room.isDirect
            ? EbiAvatar(name: room.name, radius: 24)
            : _groupAvatar(),
        // Online indicator for direct chats
        if (room.isDirect && room.isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: EbiColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: EbiColors.white, width: 2),
              ),
            ),
          ),
        // Member count badge for groups/channels
        if (!room.isDirect && room.memberCount > 0)
          Positioned(
            bottom: -2,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: EbiColors.textSecondary,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: EbiColors.white, width: 1.5),
              ),
              child: Text(
                '${room.memberCount}',
                style: const TextStyle(
                  color: EbiColors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _groupAvatar() {
    return CircleAvatar(
      radius: 24,
      backgroundColor: room.isGroup
          ? EbiColors.primaryBlue.withValues(alpha: 0.12)
          : EbiColors.darkNavy.withValues(alpha: 0.08),
      child: Icon(
        room.isGroup ? Icons.group : Icons.tag,
        size: 22,
        color: room.isGroup ? EbiColors.primaryBlue : EbiColors.darkNavy,
      ),
    );
  }

  String _lastMessagePreview() {
    final msg = room.lastMessage ?? '';
    if (!room.isDirect && room.lastSenderName != null && room.lastSenderName!.isNotEmpty && msg.isNotEmpty) {
      return '${room.lastSenderName}: $msg';
    }
    return msg;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) {
      final hour = time.hour;
      final minute = time.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? '下午' : '上午';
      final h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$period$h12:$minute';
    }
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    }
    return '${time.month}/${time.day}';
  }
}
