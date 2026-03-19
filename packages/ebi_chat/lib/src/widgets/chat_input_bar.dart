import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'hold_to_talk_button.dart';

/// Input bar with text field, attachment buttons, and emoji picker.
class ChatInputBar extends StatefulWidget {
  final ValueChanged<String> onSendText;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickPhotos;
  final VoidCallback? onPickFile;
  final VoidCallback? onPickVideo;
  final VoidCallback? onVoiceCall;
  final VoidCallback? onVideoCall;
  final void Function(String path, int durationSeconds)? onSendVoice;

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
    this.onVoiceCall,
    this.onVideoCall,
    this.onSendVoice,
    this.onTypingChanged,
    this.replyWidget,
  });

  @override
  ChatInputBarState createState() => ChatInputBarState();
}

class ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _showAttachments = false;
  bool _showEmoji = false;
  bool _isVoiceMode = false;

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

  /// Closes the attachment/emoji panels and removes keyboard focus.
  void closePanels() {
    if (_showAttachments || _showEmoji || _focusNode.hasFocus) {
      setState(() {
        _showAttachments = false;
        _showEmoji = false;
      });
      _focusNode.unfocus();
    }
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                height: 44,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isVoiceMode = !_isVoiceMode;
                      if (_isVoiceMode) {
                        _showAttachments = false;
                        _showEmoji = false;
                        _focusNode.unfocus();
                      } else {
                        _focusNode.requestFocus();
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Icon(
                      _isVoiceMode ? Icons.keyboard_alt_outlined : Icons.settings_voice_outlined,
                      color: EbiColors.textHint,
                      size: 28,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _isVoiceMode
                      ? HoldToTalkButton(
                          onVoiceRecorded: (path, duration) async {
                            widget.onSendVoice?.call(path, duration);
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6F9),
                            borderRadius: BorderRadius.circular(20),
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
              ),
              if (!_isVoiceMode)
                SizedBox(
                  height: 44,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showEmoji = !_showEmoji;
                        if (_showEmoji) {
                          _showAttachments = false;
                          _focusNode.unfocus();
                        } else {
                          _focusNode.requestFocus();
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Icon(
                        _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                        color: _showEmoji ? EbiColors.primaryBlue : EbiColors.textHint,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              if (!_isVoiceMode && !_hasText)
                SizedBox(
                  height: 44,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAttachments = !_showAttachments;
                        if (_showAttachments) {
                          _showEmoji = false;
                          _focusNode.unfocus();
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Icon(
                        _showAttachments ? Icons.close : Icons.add_circle_outline,
                        color: _showAttachments ? EbiColors.textPrimary : EbiColors.textHint,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              if (!_isVoiceMode && _hasText)
                SizedBox(
                  height: 44,
                  child: GestureDetector(
                    onTap: _send,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Icon(
                        Icons.send_rounded,
                        color: EbiColors.primaryBlue,
                        size: 28,
                      ),
                    ),
                  ),
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
    final List<Widget> items = [
      _attachmentOption(Icons.photo_library, '相册', () {
        widget.onPickPhotos?.call();
        setState(() => _showAttachments = false);
      }),
      _attachmentOption(Icons.camera_alt, '拍摄', () {
        widget.onPickCamera?.call();
        setState(() => _showAttachments = false);
      }),
      _attachmentOption(Icons.videocam, '视频', () {
        widget.onPickVideo?.call();
        setState(() => _showAttachments = false);
      }),
      _attachmentOption(Icons.attach_file, '文件', () {
        widget.onPickFile?.call();
        setState(() => _showAttachments = false);
      }),
      _attachmentOption(Icons.phone_in_talk, '语音通话', () {
        setState(() => _showAttachments = false);
        widget.onVoiceCall?.call();
      }),
      _attachmentOption(Icons.video_call, '视频通话', () {
        setState(() => _showAttachments = false);
        widget.onVideoCall?.call();
      }),
      _attachmentOption(Icons.groups, '会议', () {
        setState(() => _showAttachments = false);
        // TODO: Placeholder for meeting
      }),
      _attachmentOption(Icons.location_on, '位置', () {
        setState(() => _showAttachments = false);
        // TODO: Placeholder for location
      }),
      _attachmentOption(Icons.person, '名片', () {
        setState(() => _showAttachments = false);
        // TODO: Placeholder for contact card
      }),
      _attachmentOption(Icons.bolt, '快捷回复', () {
        setState(() => _showAttachments = false);
        // TODO: Placeholder for quick reply
      }),
      _attachmentOption(Icons.bookmark, '收藏', () {
        setState(() => _showAttachments = false);
        // TODO: Placeholder for favorites
      }),
      _attachmentOption(Icons.monetization_on, '转账', () {
        setState(() => _showAttachments = false);
        // TODO: Placeholder for monetary transfer
      }),
    ];

    // Split items into pages of 8 (2 rows * 4 columns)
    const int itemsPerPage = 8;
    final int pageCount = (items.length / itemsPerPage).ceil();

    return Container(
      height: 210, // Fixed height for the panel
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
        border: Border(top: BorderSide(color: EbiColors.divider)),
      ),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              itemCount: pageCount,
              itemBuilder: (context, pageIndex) {
                final int startIndex = pageIndex * itemsPerPage;
                final int endIndex = (startIndex + itemsPerPage < items.length)
                    ? startIndex + itemsPerPage
                    : items.length;
                final List<Widget> pageItems = items.sublist(startIndex, endIndex);

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const NeverScrollableScrollPhysics(), // Scroll is handled by PageView
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.95, // Adjust ratio to fit icon and text tighter
                  ),
                  itemCount: pageItems.length,
                  itemBuilder: (context, index) {
                    return pageItems[index];
                  },
                );
              },
            ),
          ),
          // Pagination indicator (simplified, could use a package like smooth_page_indicator if imported)
          if (pageCount > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pageCount,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == 0 ? EbiColors.primaryBlue : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: EbiColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: const Color(0xFF333333),
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: EbiTextStyles.labelSmall),
        ],
      ),
    );
  }
}
