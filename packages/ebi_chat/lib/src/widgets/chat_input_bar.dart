import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

/// Input bar with text field, attachment buttons, and emoji picker.
class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSendText;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickPhotos;
  final VoidCallback? onPickFile;
  final VoidCallback? onPickVideo;

  /// Called when the user starts/stops typing (for typing indicator).
  /// Only meaningful in 1-to-1 chats.
  final ValueChanged<bool>? onTypingChanged;

  /// Optional widget shown above the input bar (e.g. reply quote bar).
  final Widget? replyWidget;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    this.onPickCamera,
    this.onPickPhotos,
    this.onPickFile,
    this.onPickVideo,
    this.onTypingChanged,
    this.replyWidget,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _showAttachments = false;
  bool _showEmoji = false;

  // Typing indicator debounce.
  bool _isTyping = false;
  Timer? _typingTimer;
  static const _typingTimeout = Duration(seconds: 3);

  static const _emojis = [
    // Smileys
    '\u{1F600}', '\u{1F603}', '\u{1F604}', '\u{1F601}', '\u{1F606}', '\u{1F605}', '\u{1F923}', '\u{1F602}',
    '\u{1F642}', '\u{1F609}', '\u{1F60A}', '\u{1F607}', '\u{1F970}', '\u{1F60D}', '\u{1F929}', '\u{1F618}',
    '\u{1F60B}', '\u{1F61B}', '\u{1F61C}', '\u{1F92A}', '\u{1F61D}', '\u{1F911}', '\u{1F917}', '\u{1F92D}',
    '\u{1F914}', '\u{1F610}', '\u{1F611}', '\u{1F636}', '\u{1F60F}', '\u{1F612}', '\u{1F644}', '\u{1F62C}',
    // Gestures
    '\u{1F44D}', '\u{1F44E}', '\u{1F44C}', '\u270C\uFE0F', '\u{1F91E}', '\u{1F91D}', '\u{1F44F}', '\u{1F64F}',
    '\u{1F4AA}', '\u{1F91F}', '\u270B', '\u{1F44B}', '\u{1F590}\uFE0F', '\u261D\uFE0F', '\u{1F446}', '\u{1F447}',
    // Objects & Symbols
    '\u2764\uFE0F', '\u{1F9E1}', '\u{1F49B}', '\u{1F49A}', '\u{1F499}', '\u{1F49C}', '\u{1F5A4}', '\u{1F4AF}',
    '\u2705', '\u274C', '\u2B50', '\u{1F525}', '\u{1F389}', '\u{1F38A}', '\u{1F4A1}', '\u{1F4E6}',
    // Work / Supply chain
    '\u{1F4CB}', '\u{1F4CA}', '\u{1F4C8}', '\u{1F69A}', '\u{1F6A2}', '\u2708\uFE0F', '\u{1F4F7}', '\u{1F4CE}',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _stopTyping();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendText(text);
    _controller.clear();
    _stopTyping();
    setState(() {
      _hasText = false;
      _showAttachments = false;
      _showEmoji = false;
    });
  }

  void _onTextChanged(String value) {
    setState(() => _hasText = value.trim().isNotEmpty);

    // Typing indicator logic.
    if (value.trim().isNotEmpty) {
      if (!_isTyping) {
        _isTyping = true;
        widget.onTypingChanged?.call(true);
      }
      // Reset the stop-typing timer.
      _typingTimer?.cancel();
      _typingTimer = Timer(_typingTimeout, _stopTyping);
    } else {
      _stopTyping();
    }
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      widget.onTypingChanged?.call(false);
    }
    _typingTimer?.cancel();
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final offset = selection.isValid ? selection.baseOffset : text.length;
    final newText = text.substring(0, offset) + emoji + text.substring(offset);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: offset + emoji.length,
    );
    setState(() => _hasText = newText.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showAttachments) _buildAttachmentBar(),
        if (_showEmoji) _buildEmojiPicker(),
        if (widget.replyWidget != null) widget.replyWidget!,
        Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: const BoxDecoration(
            color: EbiColors.white,
            border: Border(
              top: BorderSide(color: EbiColors.divider),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _showAttachments ? Icons.close : Icons.add_circle_outline,
                  color: EbiColors.primaryBlue,
                ),
                onPressed: () {
                  setState(() {
                    _showAttachments = !_showAttachments;
                    if (_showAttachments) _showEmoji = false;
                  });
                },
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _send(),
                    onTap: () {
                      if (_showEmoji) {
                        setState(() => _showEmoji = false);
                      }
                    },
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                  color: _showEmoji
                      ? EbiColors.primaryBlue
                      : EbiColors.textHint,
                ),
                onPressed: () {
                  setState(() {
                    _showEmoji = !_showEmoji;
                    if (_showEmoji) {
                      _showAttachments = false;
                      _focusNode.unfocus();
                    }
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _hasText ? EbiColors.primaryBlue : EbiColors.textHint,
                ),
                onPressed: _hasText ? _send : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 250,
      decoration: const BoxDecoration(
        color: EbiColors.white,
        border: Border(top: BorderSide(color: EbiColors.divider)),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: _emojis.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _insertEmoji(_emojis[index]),
            child: Center(
              child: Text(
                _emojis[index],
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttachmentBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: EbiColors.white,
        border: Border(top: BorderSide(color: EbiColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _attachmentOption(Icons.camera_alt, 'Camera', () {
            widget.onPickCamera?.call();
            setState(() => _showAttachments = false);
          }),
          _attachmentOption(Icons.photo_library, 'Photos', () {
            widget.onPickPhotos?.call();
            setState(() => _showAttachments = false);
          }),
          _attachmentOption(Icons.attach_file, 'File', () {
            widget.onPickFile?.call();
            setState(() => _showAttachments = false);
          }),
          _attachmentOption(Icons.videocam, 'Video', () {
            widget.onPickVideo?.call();
            setState(() => _showAttachments = false);
          }),
        ],
      ),
    );
  }

  Widget _attachmentOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: EbiColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: EbiColors.primaryBlue, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: EbiTextStyles.labelSmall),
        ],
      ),
    );
  }
}
