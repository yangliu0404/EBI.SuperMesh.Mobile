import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_message.dart';

/// Formats seconds into "M:SS" duration string.
String formatDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '0:00';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Displays an audio/voice message with play button and duration.
class AudioMessageWidget extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const AudioMessageWidget({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isMe ? EbiColors.white : EbiColors.primaryBlue;
    final barColor = isMe
        ? EbiColors.white.withValues(alpha: 0.5)
        : EbiColors.border;
    final textColor = isMe ? EbiColors.white : EbiColors.textSecondary;
    final durationText = formatDuration(message.mediaDuration);

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice playback coming soon'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_fill,
            color: iconColor,
            size: 28,
          ),
          const SizedBox(width: 8),
          Container(
            width: 120,
            height: 2,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            durationText,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
