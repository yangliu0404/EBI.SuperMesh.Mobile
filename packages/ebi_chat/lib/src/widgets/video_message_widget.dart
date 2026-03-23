import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/pages/file_preview_page.dart';
import 'package:ebi_chat/src/pages/media_gallery_page.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';
import 'package:ebi_chat/src/services/oss_url_service.dart';
import 'package:ebi_chat/src/widgets/file_message_widget.dart';

/// Displays a video message with thumbnail preview + play button overlay.
/// Tapping navigates to [FilePreviewPage] for full video playback.
class VideoMessageWidget extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const VideoMessageWidget({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  ConsumerState<VideoMessageWidget> createState() =>
      _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends ConsumerState<VideoMessageWidget> {
  String? _resolvedUrl;
  FileInfo? _cachedFile;
  bool _thumbnailFailed = false;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final ossPath = widget.message.content;
    if (ossPath.isEmpty) {
      if (mounted) setState(() => _resolved = true);
      return;
    }
    final cacheKey = 'thumb_$ossPath';

    // 1. Disk cache first.
    try {
      final cached = await DefaultCacheManager().getFileFromCache(cacheKey);
      if (cached != null && mounted) {
        setState(() { _cachedFile = cached; _resolved = true; });
        return;
      }
    } catch (_) {}

    // 2. Network fallback.
    try {
      final ossService = ref.read(ossUrlServiceProvider);
      final url = await ossService.getImageThumbnailUrl(ossPath, maxWidth: 320, maxHeight: 240);
      if (mounted) setState(() { _resolvedUrl = url; _resolved = true; });
    } catch (_) {
      if (mounted) setState(() => _resolved = true);
    }
  }

  Future<void> _openPreview() async {
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
      final groupId = isGroup ? widget.message.roomId.substring(6) : widget.message.roomId; 
      
      final history = await repo.getMediaMessages(
        groupId: isGroup ? groupId : null,
        receiveUserId: !isGroup ? widget.message.roomId : null, 
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
          messageType: ImMessageType.video.value,
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
      AppLogger.error('[VideoMessageWidget] Failed to load gallery context', e);
      
      // Fallback: Just open this single video
      if (!mounted) return;
      final fallbackMsg = ImChatMessage(
        messageId: widget.message.id,
        groupId: widget.message.roomId,
        formUserId: widget.message.senderId,
        formUserName: widget.message.senderName,
        messageType: ImMessageType.video.value,
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
      onTap: _openPreview,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 250),
          color: EbiColors.divider,
          child: _buildThumbnail(),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (!_resolved) return _buildPlaceholder(loading: true);
    if (_thumbnailFailed) return _buildFallbackCard();

    // Disk cache hit — show from file.
    if (_cachedFile != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Image.file(_cachedFile!.file, fit: BoxFit.cover, width: 250, height: 180),
          _buildPlayButton(),
          _buildDurationBadge(),
        ],
      );
    }

    // Network — download and cache.
    if (_resolvedUrl != null && _resolvedUrl!.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: _resolvedUrl!,
            cacheKey: 'thumb_${widget.message.content}',
            fit: BoxFit.cover,
            width: 250,
            height: 180,
            placeholder: (_, __) => _buildPlaceholder(loading: true),
            errorWidget: (_, __, ___) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_thumbnailFailed) {
                  setState(() => _thumbnailFailed = true);
                }
              });
              return _buildFallbackCard();
            },
            imageBuilder: (_, imageProvider) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Image(image: imageProvider, fit: BoxFit.cover, width: 250, height: 180),
                  _buildPlayButton(),
                  _buildDurationBadge(),
                ],
              );
            },
          ),
        ],
      );
    }

    return _buildFallbackCard();
  }

  /// Fallback when thumbnail unavailable: dark card with play icon + file name.
  Widget _buildFallbackCard() {
    final fgColor = widget.isMe ? EbiColors.white : EbiColors.textPrimary;
    return Container(
      width: 220,
      height: 120,
      color: widget.isMe
          ? Colors.black.withValues(alpha: 0.2)
          : Colors.grey.shade200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_rounded,
                size: 36,
                color: fgColor.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  widget.message.fileName ?? '视频',
                  style: TextStyle(
                    fontSize: 12,
                    color: fgColor.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (widget.message.fileSize != null)
                Text(
                  formatFileSize(widget.message.fileSize),
                  style: TextStyle(
                    fontSize: 10,
                    color: fgColor.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          _buildPlayButton(size: 36),
        ],
      ),
    );
  }

  Widget _buildPlayButton({double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }

  Widget _buildDurationBadge() {
    final sizeText = formatFileSize(widget.message.fileSize);
    if (sizeText.isEmpty) return const SizedBox.shrink();
    return Positioned(
      right: 6,
      bottom: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(widget.isMe ? 16 : 6),
            bottomRight: Radius.circular(widget.isMe ? 6 : 16),
          ),
        ),
        child: Text(
          sizeText,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder({bool loading = false}) {
    return Container(
      width: 220,
      height: 150,
      color: EbiColors.divider,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.videocam_rounded,
                size: 32,
                color: EbiColors.textHint,
              ),
      ),
    );
  }
}
