import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/services/oss_url_service.dart';

/// Inline audio player — downloads the file first to avoid SSL issues,
/// then plays locally with `just_audio`.
class AudioPreviewWidget extends ConsumerStatefulWidget {
  /// OSS path — download via OssUrlService.
  final String? ossPath;

  /// Direct download URL (already resolved, absolute).
  final String? audioUrl;

  final String? fileName;

  const AudioPreviewWidget({
    super.key,
    this.ossPath,
    this.audioUrl,
    this.fileName,
  }) : assert(ossPath != null || audioUrl != null,
            'Either ossPath or audioUrl must be provided');

  @override
  ConsumerState<AudioPreviewWidget> createState() =>
      _AudioPreviewWidgetState();
}

class _AudioPreviewWidgetState extends ConsumerState<AudioPreviewWidget> {
  late final AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isDownloading = true;
  double _downloadProgress = 0.0;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _downloadAndInit();
  }

  Future<void> _downloadAndInit() async {
    try {
      final ossService = ref.read(ossUrlServiceProvider);
      String localPath;

      if (widget.ossPath != null) {
        ossService.evict(widget.ossPath!);
        await _clearCachedFile(widget.ossPath!);
        localPath = await ossService.downloadToTemp(
          widget.ossPath!,
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
      } else {
        // Direct URL download
        final tempDir = await getTemporaryDirectory();
        final ext = widget.audioUrl!.split('.').last.split('?').first;
        localPath =
            '${tempDir.path}/ebi_preview/audio_${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? "mp3" : ext}';
        final dir = Directory('${tempDir.path}/ebi_preview');
        if (!await dir.exists()) await dir.create(recursive: true);
        await ossService.downloadUrlToFile(
          widget.audioUrl!,
          localPath,
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p);
          },
        );
      }

      // Validate file
      final file = File(localPath);
      if (!await file.exists() || await file.length() < 50) {
        throw const OssUrlException('下载的音频文件无效');
      }

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _isLoading = true;
      });

      // Load from local file
      final duration = await _player.setFilePath(localPath);
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
          _isLoading = false;
        });
      }

      _player.positionStream.listen((position) {
        if (mounted) setState(() => _position = position);
      });

      _player.playerStateStream.listen((state) {
        if (mounted) setState(() {});
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '音频加载失败: $e';
          _isDownloading = false;
          _isLoading = false;
        });
      }
    }
  }

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
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
                  : '正在加载音频...',
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
                style: TextStyle(fontSize: 14, color: EbiColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isDownloading = true;
                  _downloadProgress = 0.0;
                });
                _downloadAndInit();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isPlaying = _player.playing;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Audio icon
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: EbiColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.audiotrack_rounded,
                size: 48,
                color: EbiColors.primaryBlue,
              ),
            ),
            if (widget.fileName != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.fileName!,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 24),
            // Seek slider
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: EbiColors.primaryBlue,
                inactiveTrackColor: EbiColors.divider,
                thumbColor: EbiColors.primaryBlue,
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                min: 0,
                max: _duration.inMilliseconds
                    .toDouble()
                    .clamp(1, double.infinity),
                value: _position.inMilliseconds.toDouble().clamp(
                    0,
                    _duration.inMilliseconds
                        .toDouble()
                        .clamp(1, double.infinity)),
                onChanged: (value) {
                  _player.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
            // Duration labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_position),
                    style: TextStyle(
                        fontSize: 12, color: EbiColors.textSecondary),
                  ),
                  Text(
                    _formatDuration(_duration),
                    style: TextStyle(
                        fontSize: 12, color: EbiColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Play/Pause control
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 32,
                  onPressed: () {
                    final newPos = _position - const Duration(seconds: 10);
                    _player.seek(
                        newPos < Duration.zero ? Duration.zero : newPos);
                  },
                  icon: const Icon(Icons.replay_10),
                  color: EbiColors.textSecondary,
                ),
                const SizedBox(width: 16),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: EbiColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    iconSize: 36,
                    onPressed: () {
                      if (isPlaying) {
                        _player.pause();
                      } else {
                        _player.play();
                      }
                    },
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  iconSize: 32,
                  onPressed: () {
                    final newPos = _position + const Duration(seconds: 10);
                    _player
                        .seek(newPos > _duration ? _duration : newPos);
                  },
                  icon: const Icon(Icons.forward_10),
                  color: EbiColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
