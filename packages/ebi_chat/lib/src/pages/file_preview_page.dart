
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/models/file_preview_info.dart';
import 'package:ebi_chat/src/services/oss_url_service.dart';
import 'package:ebi_chat/src/widgets/file_message_widget.dart';
import 'package:ebi_chat/src/widgets/pdf_preview_widget.dart';
import 'package:ebi_chat/src/widgets/video_preview_widget.dart';
import 'package:ebi_chat/src/widgets/audio_preview_widget.dart';
import 'package:ebi_chat/src/widgets/text_preview_widget.dart';
import 'package:ebi_chat/src/widgets/media_action_buttons.dart';
import 'package:ebi_chat/src/widgets/forward_sheet.dart';
import 'package:ebi_chat/src/widgets/center_toast.dart';
import 'package:ebi_chat/src/widgets/custom_share_sheet.dart';


/// Full-screen file preview page that loads preview info and signed URLs
/// internally from an [ossPath].
///
/// Now supports inline previews for:
/// - Images: [InteractiveViewer] + [Image.network]
/// - PDF: [PdfPreviewWidget] (downloads to temp, renders natively)
/// - Video: [VideoPreviewWidget] (streams via video_player + chewie)
/// - Audio: [AudioPreviewWidget] (plays via just_audio)
/// - Text/Code/JSON/Markdown/CSV: [TextPreviewWidget]
/// - Office & unsupported: download + open with system viewer (fallback)
class FilePreviewPage extends ConsumerStatefulWidget {
  final String ossPath;
  final String? fileName;

  const FilePreviewPage({
    super.key,
    required this.ossPath,
    this.fileName,
  });

  @override
  ConsumerState<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends ConsumerState<FilePreviewPage> {
  FilePreviewInfo? _info;
  String? _signedUrl;
  bool _isLoading = true;
  String? _error;

  // Download state for fallback (Office / unsupported files).
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _loadPreviewData();
  }

  Future<void> _loadPreviewData() async {
    try {
      final ossService = ref.read(ossUrlServiceProvider);
      // Fetch preview info and signed URL in parallel.
      final results = await Future.wait([
        ossService.getPreviewInfo(widget.ossPath),
        ossService.getFileUrl(widget.ossPath),
      ]);
      if (!mounted) return;
      setState(() {
        _info = results[0] as FilePreviewInfo;
        _signedUrl = results[1] as String;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is OssUrlException ? e.message : '加载预览失败';
        _isLoading = false;
      });
    }
  }

  /// Download file via Dio to temp dir, then open with system viewer.
  Future<void> _downloadAndOpen() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final ossService = ref.read(ossUrlServiceProvider);
      final path = await ossService.downloadToTemp(
        widget.ossPath,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _localPath = path;
        _isDownloading = false;
      });

      await Share.shareXFiles([XFile(path)]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _error = '下载失败: ${e is OssUrlException ? e.message : e}';
      });
    }
  }

  /// Download file for saving/sharing.
  Future<void> _download() async {
    try {
      String? path = _localPath;

      // If not yet downloaded, download first.
      if (path == null) {
        if (_isDownloading) return;
        setState(() {
          _isDownloading = true;
          _downloadProgress = 0.0;
        });

        final ossService = ref.read(ossUrlServiceProvider);
        path = await ossService.downloadToTemp(
          widget.ossPath,
          onProgress: (progress) {
            if (mounted) setState(() => _downloadProgress = progress);
          },
        );

        if (!mounted) return;
        setState(() {
          _localPath = path;
          _isDownloading = false;
        });
      }

      // Open system share sheet.
      await Share.shareXFiles(
        [XFile(path)],
        subject: _displayName,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('分享失败: ${e is OssUrlException ? e.message : e}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Wrap a media preview widget with floating action buttons.
  Widget _wrapWithMediaActions(Widget child) {
    return Stack(
      children: [
        child,
        MediaActionButtons(
          onForward: _handleForward,
          onDownload: _download,
          onGallery: _handleGallery,
          onShare: _handleCustomShare,
        ),
      ],
    );
  }

  /// Open forward sheet.
  void _handleForward() async {
    final target = await showForwardSheet(context, ref);
    if (target == null || !mounted) return;

    showCenterToast(context, '已转发给 ${target.displayName}');
    // TODO: Call repo.sendMessage() to actually forward the file message.
  }

  /// Gallery placeholder.
  void _handleGallery() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('媒体画廊功能开发中...'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Open custom share panel.
  void _handleCustomShare() {
    showCustomShareSheet(
      context,
      ref: ref,
      onQuickForward: (room) {
        showCenterToast(context, '已转发给 ${room.name}');
        // TODO: Call repo.sendMessage() to forward.
      },
      actions: [
        ShareAction(
          icon: Icons.send_rounded,
          label: '转发',
          onTap: _handleForward,
        ),
        ShareAction(
          icon: Icons.download_rounded,
          label: '保存',
          onTap: _download,
        ),
        ShareAction(
          icon: Icons.star_border_rounded,
          label: '收藏',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('收藏功能开发中...'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        ShareAction(
          icon: Icons.photo_library_rounded,
          label: '画廊',
          onTap: _handleGallery,
        ),
      ],
    );
  }

  String get _displayName =>
      _info?.fileName ?? widget.fileName ?? '文件';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _displayName,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_signedUrl != null || _localPath != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _download,
              tooltip: '分享',
            ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _InfoCard(
        icon: Icons.error_outline,
        iconColor: Colors.red,
        title: _error!,
      );
    }
    final info = _info!;
    final signedUrl = _signedUrl!;

    switch (info.previewMode) {
      // ── Image: unchanged ──
      case FilePreviewMode.inlineImage:
        return _wrapWithMediaActions(_buildImagePreview(signedUrl));

      // ── PDF: inline native rendering ──
      case FilePreviewMode.inlinePdf:
        return PdfPreviewWidget(ossPath: widget.ossPath);

      // ── Office-to-PDF: use the converted preview URL ──
      case FilePreviewMode.officeToPdf:
        return PdfPreviewWidget(
          downloadUrl: info.previewUrl.isNotEmpty ? info.previewUrl : signedUrl,
        );

      // ── Video: inline player (download first, then play locally) ──
      case FilePreviewMode.inlineVideo:
        return _wrapWithMediaActions(VideoPreviewWidget(ossPath: widget.ossPath));

      // ── Audio: inline player (download first, then play locally) ──
      case FilePreviewMode.inlineAudio:
        return AudioPreviewWidget(
          ossPath: widget.ossPath,
          fileName: info.fileName,
        );

      // ── Text / Code / JSON / Markdown / HTML / CSV: inline text viewer ──
      case FilePreviewMode.inlineText:
      case FilePreviewMode.inlineCode:
      case FilePreviewMode.inlineJson:
      case FilePreviewMode.inlineMarkdown:
      case FilePreviewMode.inlineHtml:
      case FilePreviewMode.csvClientRender:
        return TextPreviewWidget(
          ossPath: widget.ossPath,
          previewMode: info.previewMode,
          fileName: info.fileName,
        );

      // ── Office docs: fallback to download + system viewer ──
      case FilePreviewMode.excelClientRender:
      case FilePreviewMode.wordClientRender:
      case FilePreviewMode.pptClientRender:
      case FilePreviewMode.officeToHtml:
        return _buildDocumentFallback(context, info);

      // ── Download only ──
      case FilePreviewMode.downloadOnly:
        return _buildDownloadOnly(context, info);
    }
  }

  Widget _buildImagePreview(String signedUrl) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          signedUrl,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (_, error, stackTrace) => const _InfoCard(
            icon: Icons.broken_image,
            iconColor: Colors.red,
            title: '图片加载失败',
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentFallback(BuildContext context, FilePreviewInfo info) {
    final ext = _extFromName(info.fileName);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: getFileIconColor(ext).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              getFileIcon(ext),
              size: 36,
              color: getFileIconColor(ext),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              info.fileName,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          if (info.size > 0) ...[
            const SizedBox(height: 8),
            Text(
              formatFileSize(info.size),
              style:
                  TextStyle(fontSize: 14, color: EbiColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '此文件类型需使用外部应用打开',
            style: TextStyle(fontSize: 13, color: EbiColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _isDownloading
              ? _buildDownloadProgress()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: _downloadAndOpen,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(_localPath != null ? '再次打开' : '打开文件'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _download,
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text('下载文件'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildDownloadOnly(BuildContext context, FilePreviewInfo info) {
    final ext = _extFromName(info.fileName);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: getFileIconColor(ext).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              getFileIcon(ext),
              size: 36,
              color: getFileIconColor(ext),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              info.fileName,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          if (info.size > 0) ...[
            const SizedBox(height: 8),
            Text(
              formatFileSize(info.size),
              style:
                  TextStyle(fontSize: 14, color: EbiColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '此文件类型无法预览',
            style: TextStyle(fontSize: 13, color: EbiColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _isDownloading
              ? _buildDownloadProgress()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: _downloadAndOpen,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(_localPath != null ? '再次打开' : '打开文件'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _download,
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      ),
                      icon: const Icon(Icons.download),
                      label: const Text('下载文件'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            value: _downloadProgress > 0 ? _downloadProgress : null,
            backgroundColor: EbiColors.primaryBlue.withValues(alpha: 0.1),
            color: EbiColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _downloadProgress > 0
              ? '${(_downloadProgress * 100).toInt()}%'
              : '下载中...',
          style: TextStyle(fontSize: 13, color: EbiColors.textSecondary),
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: iconColor),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
