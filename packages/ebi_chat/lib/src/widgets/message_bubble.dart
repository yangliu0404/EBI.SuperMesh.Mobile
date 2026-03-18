import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/widgets/image_message_widget.dart';
import 'package:ebi_chat/src/widgets/file_message_widget.dart';
import 'package:ebi_chat/src/widgets/video_message_widget.dart';
import 'package:ebi_chat/src/widgets/audio_message_widget.dart';
import 'package:ebi_chat/src/widgets/message_context_menu.dart';
import 'package:ebi_chat/src/pages/user_profile_page.dart';

/// Chat message bubble — left-aligned for others, right-aligned blue for current user.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  /// Called when a context menu action is selected.
  final void Function(MessageAction action, ChatMessage message)? onAction;

  /// Called when the quoted message block is tapped.
  final void Function(String quotedMessageId)? onQuoteTap;

  /// Called when the sender's avatar is tapped.
  final void Function(String senderId)? onAvatarTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onAction,
    this.onQuoteTap,
    this.onAvatarTap,
  });

  final _bubbleKey = const ValueKey('bubble');

  void _onLongPress(BuildContext context) async {
    HapticFeedback.mediumImpact();

    // Find the render box of this bubble to position the menu.
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final targetRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      size.width,
      size.height,
    );

    final action = await MessageContextMenu.show(
      context: context,
      message: message,
      isMe: isMe,
      targetRect: targetRect,
    );

    if (action != null) {
      // Handle copy directly here.
      if (action == MessageAction.copy && message.type == MessageType.text) {
        await Clipboard.setData(ClipboardData(text: message.content));
        if (context.mounted) {
          _showCopyToast(context);
        }
        return;
      }
      onAction?.call(action, message);
    }
  }

  static void _showCopyToast(BuildContext context) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CopyToastOverlay(onDismiss: () => entry.remove()),
    );
    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: onAvatarTap != null
                  ? () => onAvatarTap!(message.senderId)
                  : null,
              child: EbiAvatar(name: message.senderName, radius: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _onLongPress(context),
              child: Container(
                key: _bubbleKey,
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? EbiColors.primaryBlue : EbiColors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 6),
                    bottomRight: Radius.circular(isMe ? 6 : 16),
                  ),
                  boxShadow: [
                    if (!isMe)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isMe
                                ? EbiColors.white.withValues(alpha: 0.8)
                                : EbiColors.primaryBlue,
                          ),
                        ),
                      ),
                    // Show quote block if this message is a reply.
                    if (message.quotedSenderName != null &&
                        message.quotedContent != null)
                      GestureDetector(
                        onTap: () {
                          if (message.quotedMessageId != null) {
                            onQuoteTap?.call(message.quotedMessageId!);
                          }
                        },
                        child: _buildQuoteBlock(),
                      ),
                    _buildContent(context),
                    const SizedBox(height: 4),
                    _buildTimeAndStatus(),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildQuoteBlock() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? EbiColors.white.withValues(alpha: 0.15)
            : const Color(0xFFF5F6F9),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: isMe
                ? EbiColors.white.withValues(alpha: 0.5)
                : const Color(0xFFD0D5DD),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.quotedSenderName!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMe
                  ? EbiColors.white.withValues(alpha: 0.8)
                  : EbiColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.quotedContent!,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isMe
                  ? EbiColors.white.withValues(alpha: 0.8)
                  : const Color(0xFF666666),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(
            fontSize: 15, // Slightly larger base text
            color: isMe ? EbiColors.white : const Color(0xFF111111),
            height: 1.45, // Better line height for readability
          ),
        );
      case MessageType.image:
        return ImageMessageWidget(message: message, isMe: isMe);
      case MessageType.file:
        return FileMessageWidget(message: message, isMe: isMe);
      case MessageType.video:
        return VideoMessageWidget(message: message, isMe: isMe);
      case MessageType.audio:
        return AudioMessageWidget(message: message, isMe: isMe);
      case MessageType.system:
        return const SizedBox.shrink();
      case MessageType.contactCard:
        return _buildContactCardContent(context);
    }
  }

  Widget _buildContactCardContent(BuildContext context) {
    final card = Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isMe ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFE2EFFF),
            radius: 20,
            child: Icon(Icons.person, color: isMe ? Colors.white : const Color(0xFF0052D9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content, // Content holds the display name
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white : const Color(0xFF111111),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '个人名片',
                  style: TextStyle(
                    fontSize: 12,
                    color: isMe ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        final userId = message.extraProperties?['UserId'] as String? ?? 
                       message.extraProperties?['userId'] as String?;
        if (userId != null && userId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserProfilePage(userId: userId),
            ),
          );
        }
      },
      child: card,
    );
  }

  Widget _buildTimeAndStatus() {
    final timeColor = isMe
        ? EbiColors.white.withValues(alpha: 0.7)
        : EbiColors.textHint;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.createdAt),
          style: TextStyle(fontSize: 10, color: timeColor),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(),
        ],
      ],
    );
  }

  Widget _buildStatusIcon() {
    switch (message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: EbiColors.white.withValues(alpha: 0.7),
          ),
        );
      case MessageStatus.sent:
      case MessageStatus.delivered:
        return Icon(
          Icons.check,
          size: 14,
          color: EbiColors.white.withValues(alpha: 0.7),
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: 14,
          color: const Color(0xFF80D8FF), // light blue for read
        );
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$h12:$minute $period';
  }
}

/// Centered overlay toast for "已复制" — fades in then out automatically.
class _CopyToastOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  const _CopyToastOverlay({required this.onDismiss});

  @override
  State<_CopyToastOverlay> createState() => _CopyToastOverlayState();
}

class _CopyToastOverlayState extends State<_CopyToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _anim.forward();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _anim.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _anim,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                  SizedBox(height: 6),
                  Text(
                    '已复制',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
