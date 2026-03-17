import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/services/oss_url_service.dart';
import 'package:ebi_chat/src/widgets/video_preview_widget.dart';
import 'package:ebi_chat/src/pages/message_search_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ebi_chat/src/widgets/media_action_buttons.dart';
import 'package:ebi_chat/src/widgets/forward_sheet.dart';
import 'package:ebi_chat/src/widgets/custom_share_sheet.dart';

/// A custom page route that fades in instead of sliding from the right.
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
}

/// Full-screen media gallery supporting swiping between images and videos.
class MediaGalleryPage extends ConsumerStatefulWidget {
  final List<ImChatMessage> mediaMessages;
  final int initialIndex;
  
  /// Optionally provide chat context to enable the quick-search button.
  final String? groupId;
  final String? userId;
  final bool isFromSearchPage;

  const MediaGalleryPage({
    super.key,
    required this.mediaMessages,
    this.initialIndex = 0,
    this.groupId,
    this.userId,
    this.isFromSearchPage = false,
  });

  @override
  ConsumerState<MediaGalleryPage> createState() => _MediaGalleryPageState();
}

class _MediaGalleryPageState extends ConsumerState<MediaGalleryPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openSearchHistory() {
    if (widget.groupId == null && widget.userId == null) return;
    
    // Jump to searching history, index 1 is "图片及视频" (Images/Videos)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageSearchPage(
          groupId: widget.groupId,
          userId: widget.userId,
          initialTabIndex: 1, // Focus on Images and Videos tab
        ),
      ),
    );
  }

  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) return;
    
    final msg = widget.mediaMessages[_currentIndex];
    final ossPath = msg.content;
    if (ossPath.isEmpty) return;

    setState(() => _isDownloading = true);

    try {
      final ossService = ref.read(ossUrlServiceProvider);
      final path = await ossService.downloadToTemp(ossPath);
      
      if (!mounted) return;
      
      final fileName = msg.extraProperties?['fileName'] as String? ?? 'media_file';
      await Share.shareXFiles([XFile(path)], subject: fileName);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下载/分享失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _handleForward() async {
    final target = await showForwardSheet(context, ref);
    if (target == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已转发给 ${target.displayName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleCustomShare() {
    showCustomShareSheet(
      context,
      ref: ref,
      onQuickForward: (room) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已转发给 ${room.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      actions: [
        ShareAction(
          icon: Icons.send_rounded,
          label: '转发',
          onTap: _handleForward,
        ),
        ShareAction(
          icon: Icons.download_rounded,
          label: '保存/分享',
          onTap: _download,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaMessages.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Text('无可用媒体', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.mediaMessages.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Dismissible(
        key: const Key('media_gallery_dismissible'),
        direction: DismissDirection.down,
        onDismissed: (_) => Navigator.of(context).pop(),
        child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaMessages.length,
            onPageChanged: (idx) {
              setState(() {
                _currentIndex = idx;
              });
            },
            itemBuilder: (context, index) {
              final msg = widget.mediaMessages[index];
              return _buildMediaItem(msg);
            },
          ),
            MediaActionButtons(
              onForward: _handleForward,
              onDownload: _download,
              onGallery: widget.isFromSearchPage 
                  ? null 
                  : ((widget.groupId != null || widget.userId != null) ? _openSearchHistory : null),
              onShare: _handleCustomShare,
            ),
            if (_isDownloading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaItem(ImChatMessage msg) {
    bool isVideo = msg.messageType == ImMessageType.video.value;
    final ossPath = msg.content;
    
    if (ossPath.isEmpty) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 50),
      );
    }

    if (isVideo) {
      // In a PageView, returning VideoPreviewWidget handles loading and playing.
      // Ebi's VideoPreviewWidget handles full screen natively with black bg.
      return VideoPreviewWidget(ossPath: ossPath);
    } else {
      // Image fetching and interactive viewer
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: _FutureImageLoader(ossPath: ossPath),
      );
    }
  }
}

class _FutureImageLoader extends ConsumerWidget {
  final String ossPath;

  const _FutureImageLoader({required this.ossPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ossService = ref.read(ossUrlServiceProvider);

    return FutureBuilder<String>(
      future: ossService.getFileUrl(ossPath), // get full img URL instead of thumbnail
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white54));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 50),
          );
        }

        return InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Center(
            child: Image.network(
              snapshot.data!,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    color: Colors.white54,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 50),
              ),
            ),
          ),
        );
      },
    );
  }
}
