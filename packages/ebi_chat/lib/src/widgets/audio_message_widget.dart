import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_chat/src/services/oss_url_service.dart';
import 'package:just_audio/just_audio.dart';

/// Displays an audio/voice message with WeChat-style bubble and playback.
///
/// Only one voice message can play at a time across the entire app.
/// Tapping a playing message pauses it; tapping another stops the current one first.
class AudioMessageWidget extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const AudioMessageWidget({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  ConsumerState<AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends ConsumerState<AudioMessageWidget> {
  // ── Singleton: only one instance can be playing at a time ──────────────
  static _AudioMessageWidgetState? _activeInstance;

  late AudioPlayer _player;
  bool _isPlaying = false;
  int _animIndex = 3;
  Timer? _animTimer;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _stopPlaying();
      }
    });
  }

  @override
  void dispose() {
    if (_activeInstance == this) _activeInstance = null;
    _animTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _stopPlaying();
    } else {
      await _startPlaying();
    }
  }

  Future<void> _startPlaying() async {
    // Stop any other playing instance first.
    if (_activeInstance != null && _activeInstance != this) {
      await _activeInstance!._stopPlaying();
    }
    _activeInstance = this;

    try {
      final rawPath = widget.message.fileUrl ?? widget.message.content;
      
      if (rawPath.startsWith('/') || rawPath.startsWith('file://')) {
        await _player.setFilePath(rawPath.replaceFirst('file://', ''));
      } else {
        // Download to temp file via Dio first. 
        // This gracefully bypasses AVPlayer's strict SSL checks on self-signed certs!
        final localPath = await ref.read(ossUrlServiceProvider).downloadToTemp(rawPath);
        await _player.setFilePath(localPath);
      }
      
      if (!mounted) return;
      setState(() => _isPlaying = true);
      _startAnimation();
      await _player.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
      _stopPlaying(); // Cleanup on error
    }
  }

  Future<void> _stopPlaying() async {
    _animTimer?.cancel();
    if (_activeInstance == this) _activeInstance = null;
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _animIndex = 3; // Reset to full icon
      });
    }
    await _player.stop();
  }

  void _startAnimation() {
    _animIndex = 1;
    _animTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) return;
      setState(() {
        _animIndex = (_animIndex % 3) + 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isMe ? EbiColors.white : const Color(0xFF333333);
    final textColor = widget.isMe ? EbiColors.white : const Color(0xFF999999);
    final duration = widget.message.mediaDuration ?? 0;
    
    // Calculate width based on duration: WeChat style (min 60, max 220)
    final double calculatedWidth = 60.0 + (duration * 3.0);
    final double bubbleWidth = calculatedWidth.clamp(60.0, 220.0);

    final durationText = duration > 0 ? '$duration"' : '';

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (widget.isMe && durationText.isNotEmpty) ...[
          Text(durationText, style: TextStyle(color: textColor, fontSize: 13)),
          const SizedBox(width: 8),
        ],
          VoiceWaveIcon(
            step: !_isPlaying ? 3 : _animIndex,
            color: iconColor,
            isMe: widget.isMe,
          ),
        if (!widget.isMe && durationText.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(durationText, style: TextStyle(color: textColor, fontSize: 13)),
        ],
      ],
    );

    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        width: bubbleWidth,
        margin: const EdgeInsets.symmetric(vertical: 2),
        color: Colors.transparent,
        child: content,
      ),
    );
  }
}

class VoiceWaveIcon extends StatelessWidget {
  final int step; // 1 (dot), 2 (dot+arc1), 3 (dot+arc1+arc2)
  final Color color;
  final bool isMe;

  const VoiceWaveIcon({
    super.key,
    required this.step,
    required this.color,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _VoiceWavePainter(step: step, color: color, isMe: isMe),
    );
  }
}

class _VoiceWavePainter extends CustomPainter {
  final int step;
  final Color color;
  final bool isMe;

  _VoiceWavePainter({
    required this.step,
    required this.color,
    required this.isMe,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final double centerY = size.height / 2;
    final double centerX = isMe ? size.width - 4.0 : 4.0;

    // Draw the dot
    canvas.drawCircle(Offset(centerX, centerY), 1.5, Paint()..color = color);

    // Draw arcs
    final double startAngle = isMe ? 3.14159 * 0.75 : -3.14159 / 4;
    final double sweepAngle = isMe ? 3.14159 / 2 : 3.14159 / 2;

    if (step >= 2) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: 6.0),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
    if (step >= 3) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: 12.0),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWavePainter oldDelegate) {
    return oldDelegate.step != step ||
        oldDelegate.color != color ||
        oldDelegate.isMe != isMe;
  }
}
