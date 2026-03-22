import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/pages/media_gallery_page.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';
import 'package:ebi_chat/src/services/oss_url_service.dart';

/// Displays an image message with OSS-resolved thumbnail and full-screen preview.
class ImageMessageWidget extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const ImageMessageWidget({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  ConsumerState<ImageMessageWidget> createState() =>
      _ImageMessageWidgetState();
}

class _ImageMessageWidgetState extends ConsumerState<ImageMessageWidget> {
  late Future<String> _thumbnailFuture;
  bool _imageLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _resolveThumbnail();
  }

  Future<String> _resolveThumbnail() {
    final ossPath = widget.message.content;
    if (ossPath.isEmpty) {
      return Future.error(const OssUrlException('No image path'));
    }
    final ossService = ref.read(ossUrlServiceProvider);
    return ossService.getImageThumbnailUrl(ossPath);
  }

  void _retry() {
    // Evict stale cache entry so we hit the API again.
    final ossPath = widget.message.content;
    if (ossPath.isNotEmpty) {
      ref.read(ossUrlServiceProvider).evict(ossPath);
    }
    setState(() {
      _imageLoadFailed = false;
      _thumbnailFuture = _resolveThumbnail();
    });
  }

  Future<void> _openFullScreen() async {
    final ossPath = widget.message.content;
    if (ossPath.isEmpty) return;

    if (!mounted) return;
    
    // Show a loading indicator if fetching takes time
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ));

    try {
      final repo = ref.read(chatRepositoryProvider);
      final isGroup = widget.message.roomId.startsWith('group:');
      final groupId = isGroup ? widget.message.roomId.substring(6) : widget.message.roomId; // if using roomId logic
      
      final history = await repo.getMediaMessages(
        groupId: isGroup ? groupId : null,
        receiveUserId: !isGroup ? widget.message.roomId : null, // Assuming roomId is the receiveUserId for 1-1
        maxResultCount: 100,
      );
      
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      // Convert ChatMessage to ImChatMessage for the gallery
      final List<ImChatMessage> galleryItems = history.map((e) => ImChatMessage(
        messageId: e.id,
        groupId: isGroup ? groupId : '',
        formUserId: e.senderId,
        formUserName: e.senderName,
        messageType: e.type == MessageType.image ? ImMessageType.image.value : ImMessageType.video.value,
        content: e.content,
        sendTime: e.createdAt.toIso8601String(),
        extraProperties: {
          'fileName': e.fileName,
          'fileSize': e.fileSize,
          'fileExt': e.fileExt,
          'mimeType': e.mimeType,
        },
      )).toList();

      int initialIndex = galleryItems.indexWhere((m) => m.messageId == widget.message.id);
      if (initialIndex < 0) {
        // Fallback if not found in recent 100
        final fallbackMsg = ImChatMessage(
          messageId: widget.message.id,
          groupId: isGroup ? groupId : '',
          formUserId: widget.message.senderId,
          formUserName: widget.message.senderName,
          messageType: ImMessageType.image.value,
          content: ossPath,
          sendTime: widget.message.createdAt.toIso8601String(),
        );
        galleryItems.insert(0, fallbackMsg);
        initialIndex = 0;
      }

      await Navigator.of(context).push(
        FadePageRoute(
          page: MediaGalleryPage(
            mediaMessages: galleryItems,
            initialIndex: initialIndex,
            groupId: isGroup ? groupId : null,
            userId: !isGroup ? widget.message.roomId : null,
          ),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // dismiss
      AppLogger.error('[ImageMessageWidget] Failed to load gallery context', e);
      
      // Fallback: Just open this single image
      if (!mounted) return;
      final fallbackMsg = ImChatMessage(
        messageId: widget.message.id,
        groupId: widget.message.roomId,
        formUserId: widget.message.senderId,
        formUserName: widget.message.senderName,
        messageType: ImMessageType.image.value,
        content: ossPath,
        sendTime: widget.message.createdAt.toIso8601String(),
      );
      await Navigator.of(context).push(
        FadePageRoute(
          page: MediaGalleryPage(
            mediaMessages: [fallbackMsg],
            initialIndex: 0,
            groupId: widget.message.roomId, 
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openFullScreen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 250),
          color: EbiColors.divider,
          child: FutureBuilder<String>(
            future: _thumbnailFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _loadingPlaceholder();
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return _errorPlaceholder(
                  onRetry: _retry,
                  message: _errorMessage(snapshot.error),
                );
              }
              if (_imageLoadFailed) {
                return _errorPlaceholder(
                  onRetry: _retry,
                  message: 'Image load failed',
                );
              }
              return CachedNetworkImage(
                imageUrl: snapshot.data!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _loadingPlaceholder(),
                errorWidget: (_, __, ___) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_imageLoadFailed) {
                      setState(() => _imageLoadFailed = true);
                    }
                  });
                  return _errorPlaceholder(
                    onRetry: _retry,
                    message: 'Image load failed',
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  static String _errorMessage(Object? error) {
    if (error is OssUrlException) return error.message;
    return 'Load failed';
  }

  Widget _loadingPlaceholder({double? progress}) {
    return Container(
      width: 200,
      height: 150,
      color: EbiColors.divider,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: progress,
          ),
        ),
      ),
    );
  }

  Widget _errorPlaceholder({VoidCallback? onRetry, String? message}) {
    return Container(
      width: 200,
      height: 150,
      color: EbiColors.divider,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, size: 32, color: EbiColors.textHint),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 11, color: EbiColors.textHint),
                  textAlign: TextAlign.center,
                ),
              ),
            if (onRetry != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: EbiColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(widget.isMe ? 12 : 4),
                        bottomRight: Radius.circular(widget.isMe ? 4 : 12),
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(fontSize: 11, color: EbiColors.primaryBlue),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
