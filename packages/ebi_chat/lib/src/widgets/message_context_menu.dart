import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ebi_chat/src/chat_message.dart';

/// Action that can be performed on a message via the context menu.
enum MessageAction {
  copy,
  reply,
  forward,
  recall,
  delete,
}

/// Long-press context menu for chat messages.
///
/// Shows a floating popup above or below the message with available actions.
class MessageContextMenu {
  /// Show the context menu near [targetRect].
  ///
  /// Returns the selected [MessageAction], or null if dismissed.
  static Future<MessageAction?> show({
    required BuildContext context,
    required ChatMessage message,
    required bool isMe,
    required Rect targetRect,
  }) async {
    final actions = _buildActions(message, isMe);
    if (actions.isEmpty) return null;

    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    // Calculate menu position.
    const menuHeight = 48.0;
    const menuPadding = 8.0;

    // Try to show above the message; if not enough space, show below.
    final showAbove = targetRect.top > menuHeight + menuPadding + 60;
    final top = showAbove
        ? targetRect.top - menuHeight - menuPadding
        : targetRect.bottom + menuPadding;

    // Horizontal: center on the message, but clamp to screen edges.
    final menuWidth = actions.length * 64.0;
    var left = targetRect.center.dx - menuWidth / 2;
    left = left.clamp(12.0, screenSize.width - menuWidth - 12.0);

    MessageAction? result;

    late final OverlayEntry menuEntry;
    late final OverlayEntry barrierEntry;

    barrierEntry = OverlayEntry(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          barrierEntry.remove();
          menuEntry.remove();
        },
        child: const SizedBox.expand(),
      ),
    );

    menuEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.8 + 0.2 * value,
                child: child,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: actions.map((action) {
                  return _MenuActionButton(
                    action: action,
                    onTap: () {
                      result = action;
                      barrierEntry.remove();
                      menuEntry.remove();
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(barrierEntry);
    overlay.insert(menuEntry);

    // Wait for menu to be dismissed.
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 50));
      return barrierEntry.mounted;
    });

    return result;
  }

  static List<MessageAction> _buildActions(ChatMessage message, bool isMe) {
    final actions = <MessageAction>[];

    // Copy — only for text messages.
    if (message.type == MessageType.text) {
      actions.add(MessageAction.copy);
    }

    // Reply — always available.
    actions.add(MessageAction.reply);

    // Forward — always available.
    actions.add(MessageAction.forward);

    // Recall — only for own messages within 2 minutes.
    if (isMe) {
      final elapsed = DateTime.now().difference(message.createdAt);
      if (elapsed.inMinutes < 2) {
        actions.add(MessageAction.recall);
      }
    }

    // Delete — always available.
    actions.add(MessageAction.delete);

    return actions;
  }
}

class _MenuActionButton extends StatelessWidget {
  final MessageAction action;
  final VoidCallback onTap;

  const _MenuActionButton({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (action) {
      MessageAction.copy => (Icons.copy_rounded, '复制'),
      MessageAction.reply => (Icons.reply_rounded, '引用'),
      MessageAction.forward => (Icons.shortcut_rounded, '转发'),
      MessageAction.recall => (Icons.undo_rounded, '撤回'),
      MessageAction.delete => (Icons.delete_outline_rounded, '删除'),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
