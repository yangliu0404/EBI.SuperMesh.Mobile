import 'package:ebi_chat/src/chat_message.dart';

/// Status of a pending file upload.
enum UploadStatus { picking, uploading, sending, done, failed }

/// Tracks a file being uploaded and sent as a chat message.
class PendingUpload {
  final String localId;
  final String localPath;
  final String fileName;
  final MessageType messageType;
  final UploadStatus status;
  final double progress;
  final String? error;
  final String? ossPath;

  const PendingUpload({
    required this.localId,
    required this.localPath,
    required this.fileName,
    required this.messageType,
    this.status = UploadStatus.uploading,
    this.progress = 0.0,
    this.error,
    this.ossPath,
  });

  PendingUpload copyWith({
    UploadStatus? status,
    double? progress,
    String? error,
    String? ossPath,
  }) {
    return PendingUpload(
      localId: localId,
      localPath: localPath,
      fileName: fileName,
      messageType: messageType,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      ossPath: ossPath ?? this.ossPath,
    );
  }
}
