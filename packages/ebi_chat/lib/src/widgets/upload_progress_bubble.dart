import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/models/upload_state.dart';
import 'package:ebi_chat/src/widgets/file_message_widget.dart';

/// Displays a sending-in-progress bubble for a file being uploaded.
class UploadProgressBubble extends StatelessWidget {
  final PendingUpload upload;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  const UploadProgressBubble({
    super.key,
    required this.upload,
    this.onRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: EbiColors.primaryBlue.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContent(),
                  const SizedBox(height: 6),
                  _buildProgress(),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (upload.messageType == MessageType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 160,
          height: 120,
          child: Image.file(
            File(upload.localPath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: EbiColors.white.withValues(alpha: 0.2),
              child: const Icon(Icons.image, color: EbiColors.white, size: 32),
            ),
          ),
        ),
      );
    }

    // File / Video — show icon + name
    final ext = _extFromName(upload.fileName);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: EbiColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            upload.messageType == MessageType.video
                ? Icons.play_circle_fill_rounded
                : getFileIcon(ext),
            color: EbiColors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            upload.fileName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: EbiColors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    if (upload.status == UploadStatus.failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
          const SizedBox(width: 4),
          Text(
            upload.error ?? 'Failed',
            style: const TextStyle(fontSize: 11, color: Colors.redAccent),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  color: EbiColors.white,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: EbiColors.white,
                ),
              ),
            ),
          ],
        ],
      );
    }

    final label = switch (upload.status) {
      UploadStatus.picking => 'Preparing...',
      UploadStatus.uploading => 'Uploading ${(upload.progress * 100).toInt()}%',
      UploadStatus.sending => 'Sending...',
      UploadStatus.done => 'Sent',
      UploadStatus.failed => 'Failed',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (upload.status == UploadStatus.uploading ||
            upload.status == UploadStatus.sending)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: EbiColors.white.withValues(alpha: 0.8),
              value: upload.status == UploadStatus.uploading
                  ? upload.progress
                  : null,
            ),
          ),
        if (upload.status == UploadStatus.uploading ||
            upload.status == UploadStatus.sending)
          const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: EbiColors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  static String? _extFromName(String? name) {
    if (name == null) return null;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1);
  }
}
