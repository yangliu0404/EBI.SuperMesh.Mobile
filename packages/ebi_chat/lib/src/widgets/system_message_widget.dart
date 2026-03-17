import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_message.dart';

/// System message — centered gray text.
class SystemMessageWidget extends StatelessWidget {
  final ChatMessage message;

  const SystemMessageWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: EbiColors.divider.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.content,
            style: EbiTextStyles.bodySmall.copyWith(
              fontSize: 12,
              color: EbiColors.textHint,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
