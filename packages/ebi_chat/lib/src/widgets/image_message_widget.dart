import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_message.dart';
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
    try {
      final ossService = ref.read(ossUrlServiceProvider);
      final fullUrl = await ossService.getFileUrl(ossPath);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullScreenImageView(
              imageUrl: fullUrl,
              heroTag: widget.message.id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is OssUrlException ? 'Image load failed: ${e.message}' : 'Failed to load image',
            ),
          ),
        );
      }
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
              return Image.network(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  // Defer setState to after build.
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
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  final total = progress.expectedTotalBytes;
                  return _loadingPlaceholder(
                    progress: total != null && total > 0
                        ? progress.cumulativeBytesLoaded / total
                        : null,
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
                      borderRadius: BorderRadius.circular(12),
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

/// Full-screen image preview with pinch-to-zoom.
class _FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const _FullScreenImageView({
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, size: 64, color: Colors.white54),
                  SizedBox(height: 12),
                  Text(
                    'Image failed to load',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              final total = progress.expectedTotalBytes;
              return Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  value: total != null && total > 0
                      ? progress.cumulativeBytesLoaded / total
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
