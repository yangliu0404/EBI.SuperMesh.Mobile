import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/services/oss_url_service.dart';

/// Inline PDF viewer using `pdfrx` (PDFium-based, cross-platform).
class PdfPreviewWidget extends ConsumerStatefulWidget {
  final String? ossPath;
  final String? downloadUrl;

  const PdfPreviewWidget({super.key, this.ossPath, this.downloadUrl})
      : assert(ossPath != null || downloadUrl != null,
            'Either ossPath or downloadUrl must be provided');

  @override
  ConsumerState<PdfPreviewWidget> createState() => _PdfPreviewWidgetState();
}

class _PdfPreviewWidgetState extends ConsumerState<PdfPreviewWidget> {
  String? _localPath;
  bool _isLoading = true;
  double _downloadProgress = 0.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final ossService = ref.read(ossUrlServiceProvider);
      String path;

      if (widget.ossPath != null) {
        // Evict stale OSS cache so we get a fresh signed URL.
        ossService.evict(widget.ossPath!);

        // Clear any previously cached temp file (may be corrupted / non-PDF).
        await _clearCachedFile(widget.ossPath!);

        path = await ossService.downloadToTemp(
          widget.ossPath!,
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final dir = Directory('${tempDir.path}/ebi_pdf_preview');
        if (!await dir.exists()) await dir.create(recursive: true);
        path =
            '${dir.path}/preview_${DateTime.now().millisecondsSinceEpoch}.pdf';

        await ossService.downloadUrlToFile(
          widget.downloadUrl!,
          path,
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
      }

      // Validate: PDF files start with "%PDF-"
      final file = File(path);
      if (!await file.exists()) {
        throw const OssUrlException('下载的文件不存在');
      }
      final fileSize = await file.length();
      if (fileSize < 5) {
        await file.delete();
        throw const OssUrlException('下载的文件为空');
      }
      final header = await file.openRead(0, 5).expand((b) => b).toList();
      final headerStr = String.fromCharCodes(header);
      if (!headerStr.startsWith('%PDF-')) {
        // Read first 200 bytes for debug info
        final debugBytes =
            await file.openRead(0, 200).expand((b) => b).toList();
        final debugStr = String.fromCharCodes(debugBytes);
        debugPrint('[PdfPreview] File is not valid PDF. Header: $debugStr');
        await file.delete();
        throw OssUrlException(
            '下载的文件不是有效的 PDF 格式（可能是服务器返回了错误页面）');
      }

      if (mounted) {
        setState(() {
          _localPath = path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is OssUrlException ? e.message : 'PDF 下载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Delete the cached temp file for an ossPath so we force a re-download.
  Future<void> _clearCachedFile(String ossPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      // OssUrlService saves to: ${tempDir}/ebi_preview/<filename>
      final parsed = ossPath.split('/');
      final fileName = parsed.isNotEmpty ? parsed.last : '';
      if (fileName.isEmpty) return;
      // Check both possible cache locations
      final colonIdx = fileName.indexOf(':');
      final cleanName = colonIdx >= 0 ? fileName.substring(colonIdx + 1) : fileName;
      final cachedFile = File('${tempDir.path}/ebi_preview/$cleanName');
      if (await cachedFile.exists()) {
        await cachedFile.delete();
        debugPrint('[PdfPreview] Cleared cached file: ${cachedFile.path}');
      }
    } catch (_) {
      // Ignore cleanup failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
                  : '正在下载 PDF...',
              style: TextStyle(fontSize: 14, color: EbiColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                  _downloadProgress = 0.0;
                });
                _download();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PdfViewer.file(
            _localPath!,
            params: const PdfViewerParams(
              enableTextSelection: true,
              maxScale: 8.0,
            ),
          ),
        ),
      ],
    );
  }
}
