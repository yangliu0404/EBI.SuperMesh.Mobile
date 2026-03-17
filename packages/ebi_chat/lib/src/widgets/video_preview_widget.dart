import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/services/oss_url_service.dart';

/// Inline video player.
///
/// Downloads the video to a local temp file first (to bypass self-signed
/// SSL certs), then plays with `video_player` + `chewie`.
class VideoPreviewWidget extends ConsumerStatefulWidget {
  /// OSS path (e.g. "blobs:im/conv/video/file.mp4") — download via OssUrlService.
  final String? ossPath;

  /// Direct download URL (already resolved, absolute) — download directly.
  final String? directUrl;

  const VideoPreviewWidget({super.key, this.ossPath, this.directUrl})
      : assert(ossPath != null || directUrl != null,
            'Either ossPath or directUrl must be provided');

  @override
  ConsumerState<VideoPreviewWidget> createState() =>
      _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends ConsumerState<VideoPreviewWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  bool _isDownloading = true;
  double _downloadProgress = 0.0;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _downloadAndInit();
  }

  Future<void> _downloadAndInit() async {
    try {
      final ossService = ref.read(ossUrlServiceProvider);
      String localPath;

      if (widget.ossPath != null) {
        // Evict URL cache and clear any stale temp file.
        ossService.evict(widget.ossPath!);
        await _clearCachedFile(widget.ossPath!);

        localPath = await ossService.downloadToTemp(
          widget.ossPath!,
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
      } else {
        // Direct URL — download via the raw downloader.
        final tempDir = await Directory.systemTemp.createTemp('ebi_video_');
        final ext = widget.directUrl!.split('.').last.split('?').first;
        localPath = '${tempDir.path}/video.${ext.isEmpty ? "mp4" : ext}';
        await ossService.downloadUrlToFile(
          widget.directUrl!,
          localPath,
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
      }

      // Validate downloaded file.
      final file = File(localPath);
      if (!await file.exists() || await file.length() < 100) {
        throw const OssUrlException('下载的视频文件无效');
      }

      if (!mounted) return;
      setState(() => _isDownloading = false);

      // Init player from local file.
      _videoController = VideoPlayerController.file(File(localPath));
      await _videoController!.initialize();

      if (!mounted) return;
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true, // Enable controls so a tap toggles play/pause
        showControlsOnInitialize: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: EbiColors.primaryBlue,
          handleColor: EbiColors.primaryBlue,
          bufferedColor: EbiColors.primaryBlue.withValues(alpha: 0.3),
          backgroundColor: EbiColors.divider,
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _hasError = true;
          _errorMessage = '视频加载失败: $e';
        });
      }
    }
  }

  /// Delete cached temp file for an ossPath to force re-download.
  Future<void> _clearCachedFile(String ossPath) async {
    try {
      final colonIdx = ossPath.indexOf(':');
      if (colonIdx < 0) return;
      final fullPath = ossPath.substring(colonIdx + 1);
      final lastSlash = fullPath.lastIndexOf('/');
      if (lastSlash < 0) return;
      final fileName = fullPath.substring(lastSlash + 1);
      final tempDir = await getTemporaryDirectory();
      final cachedFile = File('${tempDir.path}/ebi_preview/$fileName');
      if (await cachedFile.exists()) {
        await cachedFile.delete();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDownloading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
            ),
            const SizedBox(height: 16),
            Text(
              _downloadProgress > 0
                  ? '下载中 ${(_downloadProgress * 100).toInt()}%'
                  : '正在加载视频...',
              style: TextStyle(fontSize: 14, color: EbiColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage ?? '视频加载失败',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: EbiColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _errorMessage = null;
                  _isDownloading = true;
                  _downloadProgress = 0.0;
                });
                _chewieController?.dispose();
                _videoController?.dispose();
                _chewieController = null;
                _videoController = null;
                _downloadAndInit();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_chewieController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }
}
