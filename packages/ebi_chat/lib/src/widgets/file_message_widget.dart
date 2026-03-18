import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/pages/file_preview_page.dart';

/// Returns an icon for the given file extension.
IconData getFileIcon(String? ext) {
  switch (ext?.toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf;
    case 'doc':
    case 'docx':
      return Icons.description;
    case 'xls':
    case 'xlsx':
      return Icons.table_chart;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow;
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return Icons.folder_zip;
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'bmp':
    case 'webp':
      return Icons.image;
    case 'mp4':
    case 'avi':
    case 'mov':
    case 'mkv':
      return Icons.videocam;
    case 'mp3':
    case 'wav':
    case 'aac':
    case 'flac':
      return Icons.audiotrack;
    default:
      return Icons.insert_drive_file;
  }
}

/// Returns an icon color for the given file extension.
Color getFileIconColor(String? ext) {
  switch (ext?.toLowerCase()) {
    case 'pdf':
      return const Color(0xFFE53935); // red
    case 'doc':
    case 'docx':
      return const Color(0xFF1E88E5); // blue
    case 'xls':
    case 'xlsx':
      return const Color(0xFF43A047); // green
    case 'ppt':
    case 'pptx':
      return const Color(0xFFE65100); // orange
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return const Color(0xFFFDD835); // yellow
    default:
      return const Color(0xFF78909C); // grey
  }
}

/// Formats byte count into a human-readable string.
String formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Displays a file attachment message with type-specific icon, name, and size.
/// Tapping navigates directly to [FilePreviewPage] which handles loading
/// preview info and signed URLs internally.
class FileMessageWidget extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const FileMessageWidget({
    super.key,
    required this.message,
    required this.isMe,
  });

  void _onTap(BuildContext context) {
    final ossPath = message.content;
    if (ossPath.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FilePreviewPage(
          ossPath: ossPath,
          fileName: message.fileName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext =
        message.fileExt ?? _extFromName(message.fileName) ?? _extFromName(message.content);
    final fgColor = isMe ? EbiColors.white : EbiColors.textPrimary;
    final iconColor = isMe ? EbiColors.white : getFileIconColor(ext);
    final iconBg = isMe
        ? EbiColors.white.withValues(alpha: 0.2)
        : iconColor.withValues(alpha: 0.1);
    final sizeText = formatFileSize(message.fileSize);

    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(getFileIcon(ext), color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'File',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sizeText.isNotEmpty)
                    Text(
                      sizeText,
                      style: TextStyle(
                        fontSize: 11,
                        color: fgColor.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String? _extFromName(String? name) {
    if (name == null) return null;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1);
  }
}
