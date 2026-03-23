import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_room.dart';

/// Controller that ensures only one [ChatRoomTile] is open at a time
/// and can close all on scroll.
class SwipeActionController extends ChangeNotifier {
  _ChatRoomTileState? _openTile;

  /// Close the currently open tile (if any).
  void closeAll() {
    _openTile?._close();
    _openTile = null;
  }

  void _register(_ChatRoomTileState tile) {
    if (_openTile != null && _openTile != tile) {
      _openTile!._close();
    }
    _openTile = tile;
  }

  void _unregister(_ChatRoomTileState tile) {
    if (_openTile == tile) _openTile = null;
  }
}

/// A single chat room tile with swipe-to-reveal action buttons.
class ChatRoomTile extends StatefulWidget {
  final ChatRoom room;
  final VoidCallback? onTap;
  final VoidCallback? onMarkUnread;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;
  final SwipeActionController? swipeController;

  const ChatRoomTile({
    super.key,
    required this.room,
    this.onTap,
    this.onMarkUnread,
    this.onPin,
    this.onDelete,
    this.swipeController,
  });

  @override
  State<ChatRoomTile> createState() => _ChatRoomTileState();
}

class _ChatRoomTileState extends State<ChatRoomTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  bool _isOpen = false;

  static const double _actionWidth = 170.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween<double>(begin: 0, end: -_actionWidth).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    widget.swipeController?._unregister(this);
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    widget.swipeController?._register(this);
    _controller.forward();
    _isOpen = true;
  }

  void _close() {
    _controller.reverse();
    _isOpen = false;
  }

  void _handleDragStart(DragStartDetails details) {
    // Close any other open tile immediately on touch.
    final ctrl = widget.swipeController;
    if (ctrl != null && ctrl._openTile != null && ctrl._openTile != this) {
      ctrl._openTile!._close();
      ctrl._openTile = null;
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    _controller.value = (_controller.value - delta / _actionWidth).clamp(0.0, 1.0);
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300) {
      _open();
    } else if (velocity > 300) {
      _close();
      widget.swipeController?._unregister(this);
    } else if (_controller.value > 0.4) {
      _open();
    } else {
      _close();
      widget.swipeController?._unregister(this);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: GestureDetector(
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        onTapDown: (_) {
          // Close any other open tile on touch (WeChat behavior).
          final ctrl = widget.swipeController;
          if (ctrl != null && ctrl._openTile != null && ctrl._openTile != this) {
            ctrl._openTile!._close();
            ctrl._openTile = null;
          }
        },
        onTap: () {
          if (_isOpen) {
            _close();
            widget.swipeController?._unregister(this);
          } else {
            widget.onTap?.call();
          }
        },
        child: Stack(
          children: [
            // Action buttons (behind).
            Positioned(right: 0, top: 0, bottom: 0, width: _actionWidth,
              child: Row(
                children: [
                  _ActionButton(
                    icon: widget.room.unreadCount > 0
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                    label: widget.room.unreadCount > 0 ? '已读' : '未读',
                    color: const Color(0xFF3B82F6),
                    onTap: () { _close(); widget.swipeController?._unregister(this); widget.onMarkUnread?.call(); },
                  ),
                  _ActionButton(
                    icon: widget.room.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                    label: widget.room.isPinned ? '取消置顶' : '置顶',
                    color: const Color(0xFFF59E0B),
                    onTap: () { _close(); widget.swipeController?._unregister(this); widget.onPin?.call(); },
                  ),
                  _ActionButton(
                    icon: Icons.delete_outline,
                    label: '删除',
                    color: const Color(0xFFEF4444),
                    onTap: () { _close(); widget.swipeController?._unregister(this); widget.onDelete?.call(); },
                  ),
                ],
              ),
            ),

            // Foreground tile (slides left).
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_slideAnimation.value, 0),
                  child: child,
                );
              },
              child: Container(
                color: widget.room.isPinned
                    ? const Color(0xFFF0F5FF) // Light blue for pinned
                    : Colors.white,
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final room = widget.room;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (!room.isDirect) ...[
                      Icon(room.isGroup ? Icons.group : Icons.tag, size: 14, color: EbiColors.textHint),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Row(children: [
                        Flexible(
                          child: Text(
                            room.name,
                            style: room.unreadCount > 0
                                ? EbiTextStyles.labelLarge
                                : EbiTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w400),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (room.tenantName != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: EbiColors.primaryBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(room.tenantName!, style: EbiTextStyles.labelSmall.copyWith(
                              fontSize: 10, color: EbiColors.primaryBlue, fontWeight: FontWeight.w500, letterSpacing: 0,
                            ), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ]),
                    ),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (room.isMuted)
                        const Padding(padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.notifications_off_outlined, size: 14, color: EbiColors.textHint)),
                      if (room.isPinned)
                        const Padding(padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.push_pin, size: 14, color: EbiColors.textHint)),
                      if (room.lastMessageAt != null)
                        Text(_formatTime(room.lastMessageAt!), style: EbiTextStyles.labelSmall.copyWith(
                          color: room.unreadCount > 0 ? EbiColors.primaryBlue : EbiColors.textHint)),
                    ]),
                  ],
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: Text(_lastMessagePreview(),
                      style: room.unreadCount > 0
                          ? EbiTextStyles.bodySmall.copyWith(color: EbiColors.textPrimary, fontWeight: FontWeight.w500)
                          : EbiTextStyles.bodySmall,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (room.unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: room.isMuted ? EbiColors.textHint : EbiColors.primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${room.unreadCount}', style: const TextStyle(
                        color: EbiColors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final room = widget.room;
    return Stack(clipBehavior: Clip.none, children: [
      room.isDirect ? EbiAvatar(name: room.name, radius: 24) : CircleAvatar(
        radius: 24,
        backgroundColor: room.isGroup
            ? EbiColors.primaryBlue.withValues(alpha: 0.12)
            : EbiColors.darkNavy.withValues(alpha: 0.08),
        child: Icon(room.isGroup ? Icons.group : Icons.tag, size: 22,
          color: room.isGroup ? EbiColors.primaryBlue : EbiColors.darkNavy),
      ),
      if (room.isDirect && room.isOnline)
        Positioned(bottom: 0, right: 0, child: Container(width: 14, height: 14,
          decoration: BoxDecoration(color: EbiColors.success, shape: BoxShape.circle,
            border: Border.all(color: EbiColors.white, width: 2)))),
      if (!room.isDirect && room.memberCount > 0)
        Positioned(bottom: -2, right: -4, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(color: EbiColors.textSecondary, borderRadius: BorderRadius.circular(7),
            border: Border.all(color: EbiColors.white, width: 1.5)),
          child: Text('${room.memberCount}', style: const TextStyle(
            color: EbiColors.white, fontSize: 9, fontWeight: FontWeight.w700)))),
    ]);
  }

  String _lastMessagePreview() {
    final room = widget.room;
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: color,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
