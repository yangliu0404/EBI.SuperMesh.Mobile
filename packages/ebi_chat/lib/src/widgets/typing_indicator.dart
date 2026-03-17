import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';

/// Shows "对方正在输入..." above the input bar when the other user is typing.
/// Only used in 1-to-1 (direct) conversations.
class TypingIndicator extends ConsumerWidget {
  final String conversationId;

  const TypingIndicator({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typingAsync = ref.watch(typingIndicatorProvider(conversationId));

    return typingAsync.when(
      data: (event) {
        if (!event.isTyping) return const SizedBox.shrink();
        return _TypingBanner();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TypingBanner extends StatefulWidget {
  @override
  State<_TypingBanner> createState() => _TypingBannerState();
}

class _TypingBannerState extends State<_TypingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _dotController,
            builder: (_, __) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i * 0.2;
                  final t = (_dotController.value - delay).clamp(0.0, 1.0);
                  final bounce = (t < 0.5)
                      ? (t * 2)
                      : (2 - t * 2);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Transform.translate(
                      offset: Offset(0, -3 * bounce),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: EbiColors.textHint,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            '对方正在输入...',
            style: TextStyle(
              fontSize: 12,
              color: EbiColors.textHint,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
