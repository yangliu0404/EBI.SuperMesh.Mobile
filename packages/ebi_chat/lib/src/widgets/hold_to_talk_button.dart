import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

enum RecordState { idle, recording, cancelling }

class HoldToTalkButton extends StatefulWidget {
  final Future<void> Function(String path, int durationSeconds) onVoiceRecorded;

  const HoldToTalkButton({
    super.key,
    required this.onVoiceRecorded,
  });

  @override
  State<HoldToTalkButton> createState() => _HoldToTalkButtonState();
}

class _HoldToTalkButtonState extends State<HoldToTalkButton> {
  RecordState _state = RecordState.idle;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordPath;
  DateTime? _startTime;
  Timer? _durationTimer;
  int _recordDuration = 0;
  
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _audioRecorder.dispose();
    _durationTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _updateState(RecordState newState) {
    if (_state == newState) return;
    setState(() => _state = newState);
    _overlayEntry?.markNeedsBuild();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _currentRecordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.pcm16bits),
          path: _currentRecordPath!,
        );

        _startTime = DateTime.now();
        _recordDuration = 0;
        _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _recordDuration++;
          _overlayEntry?.markNeedsBuild();
        });

        _updateState(RecordState.recording);
        _showOverlay();
      }
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      _updateState(RecordState.idle);
    }
  }

  Future<void> _stopRecording({required bool cancel}) async {
    _durationTimer?.cancel();
    _durationTimer = null;
    
    _removeOverlay();
    _updateState(RecordState.idle);

    final path = await _audioRecorder.stop();
    if (path != null) {
      if (cancel) {
        // Delete the file if cancelled
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } else {
        // Send if recorded for at least 1 second
        final duration = _startTime != null ? DateTime.now().difference(_startTime!).inSeconds : 0;
        if (duration >= 1) {
          widget.onVoiceRecorded(path, duration);
        } else {
          // Too short
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('录音时间太短 (Message too short)'), duration: Duration(seconds: 1)),
            );
          }
        }
      }
    }
    _currentRecordPath = null;
    _startTime = null;
  }

  void _onPanDown(DragDownDetails details) {
    _startRecording();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_state == RecordState.idle) return;

    // Local position Y: negative means moving finger UP.
    // E.g. -50 means 50 logical pixels above the top edge of the button
    if (details.localPosition.dy < -50) {
      _updateState(RecordState.cancelling);
    } else {
      _updateState(RecordState.recording);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_state == RecordState.idle) return;
    _stopRecording(cancel: _state == RecordState.cancelling);
  }

  void _onPanCancel() {
    if (_state == RecordState.idle) return;
    _stopRecording(cancel: true);
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _state == RecordState.cancelling
                        ? Icon(Icons.delete_outline, color: EbiColors.error, size: 64)
                        : const _PulsingIcon(Icons.mic, Colors.white, 64),
                    const SizedBox(height: 12),
                    Text(
                      _state == RecordState.cancelling ? '松开手指，取消发送' : '手指上滑，取消发送',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    if (_state == RecordState.recording) ...[
                      const SizedBox(height: 8),
                      Text(
                        '00:${_recordDuration.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    if (_overlayEntry != null && _overlayEntry!.mounted) {
      _overlayEntry!.remove();
    }
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = _state != RecordState.idle;
    
    return GestureDetector(
      onPanDown: _onPanDown,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isRecording ? const Color(0xFFC5C6C9) : EbiColors.white,
          borderRadius: BorderRadius.circular(20),
          border: isRecording ? null : Border.all(color: EbiColors.divider),
        ),
        child: Text(
          isRecording ? '松开 结束' : '按住 说话',
          style: TextStyle(
            fontSize: 15,
            fontWeight: isRecording ? FontWeight.bold : FontWeight.w500,
            color: isRecording ? Colors.black87 : const Color(0xFF333333),
          ),
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PulsingIcon(this.icon, this.color, this.size);

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.2), // pulses from 1.0 to 1.2
          child: Opacity(
            opacity: 0.6 + (_controller.value * 0.4), // pulses from 0.6 to 1.0
            child: Icon(widget.icon, color: widget.color, size: widget.size),
          ),
        );
      },
    );
  }
}
