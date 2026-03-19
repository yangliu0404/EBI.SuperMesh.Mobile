import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/models/im_group_models.dart';
import 'package:ebi_chat/src/models/upload_state.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';
import 'package:ebi_chat/src/repository/chat_repository.dart';
import 'package:ebi_chat/src/services/signalr_connection_manager.dart';
import 'package:ebi_chat/src/services/oss_url_service.dart';
import 'package:ebi_chat/src/widgets/message_bubble.dart';
import 'package:ebi_chat/src/widgets/system_message_widget.dart';
import 'package:ebi_chat/src/widgets/chat_date_separator.dart';
import 'package:ebi_chat/src/widgets/chat_input_bar.dart';
import 'package:ebi_chat/src/widgets/typing_indicator.dart';
import 'package:ebi_chat/src/widgets/upload_progress_bubble.dart';
import 'package:ebi_chat/src/widgets/message_context_menu.dart';
import 'package:ebi_chat/src/widgets/forward_sheet.dart';
import 'package:ebi_chat/src/widgets/center_toast.dart';
import 'package:ebi_chat/src/pages/file_preview_page.dart';
import 'package:ebi_chat/src/pages/group_settings_page.dart';
import 'package:ebi_chat/src/pages/user_profile_page.dart';
import 'package:ebi_chat/src/pages/chat_settings_page.dart';
import 'package:ebi_chat/src/models/call_models.dart';
import 'package:ebi_chat/src/providers/call_providers.dart';
import 'package:ebi_chat/src/pages/outgoing_call_page.dart';

const _uuid = Uuid();

/// Chat detail page — message list with real-time stream + input bar.
class ChatDetailPage extends ConsumerStatefulWidget {
  final String roomId;
  final String? roomName;
  final int initialUnreadCount;

  const ChatDetailPage({
    super.key,
    required this.roomId,
    this.roomName,
    this.initialUnreadCount = 0,
  });

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final List<ChatMessage> _messages = [];
  final List<ChatMessage> _pendingMessages = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<ChatMessage>? _streamSub;
  StreamSubscription<ImMessagesReadEvent>? _readReceiptSub;
  StreamSubscription<ImChatMessage>? _recallSub;
  bool _initialLoaded = false;
  bool _isAtBottom = true;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  static const int _pageSize = 50;

  // ── Upload state ────────────────────────────────────────────────────────
  final List<PendingUpload> _pendingUploads = [];
  final _imagePicker = ImagePicker();

  // ── GlobalKey registry — keyed by message ID for precise scrolling ──────
  final Map<String, GlobalKey> _messageKeys = {};

  // ── "以下为新消息" divider ──────────────────────────────────────────────
  String? _unreadDividerMessageId;
  final GlobalKey _dividerKey = GlobalKey();

  // ── "↑ N 条新消息" badge ───────────────────────────────────────────────
  int _unreadAboveCount = 0;
  // ignore: unused_field — reserved for future scroll-to-divider detection.
  bool _dividerSeen = false;

  // ── Track first real-time message received while at bottom ────────────
  String? _firstRealtimeMessageId;
  int _realtimeMessageCount = 0;

  late final String _currentUserId;
  late final String _currentUserName;

  ImGroup? _groupInfo;

  // ── Reply state ────────────────────────────────────────────────────────
  ChatMessage? _replyingTo;

  // ── Highlight state (for scroll-to-quoted) ────────────────────────────
  String? _highlightedMessageId;

  String? get _otherUserId {
    if (widget.roomId.startsWith('group:')) return null;
    return widget.roomId;
  }

  String? get _groupId {
    if (widget.roomId.startsWith('group:')) {
      return widget.roomId.substring(6);
    }
    return null;
  }

  /// Conversation key for OSS upload paths.
  String get _conversationKey {
    if (_groupId != null) return 'group_$_groupId';
    return 'user_${_otherUserId ?? _currentUserId}';
  }

  bool get _isDirect => _otherUserId != null;

  GlobalKey _keyForMessage(String messageId) {
    if (messageId.isEmpty) {
      return GlobalKey(); // Prevent key duplication if ID is empty
    }
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  // ── Cached refs for dispose (widget tree is deactivated in dispose) ─────
  late final ChatRepository _repo;
  late final SignalRConnectionManager _manager;
  late final ChatRoomsNotifier _roomsNotifier;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(chatRepositoryProvider);
    _manager = ref.read(signalRConnectionProvider);
    _roomsNotifier = ref.read(chatRoomsProvider.notifier);
    _currentUserId = ref.read(currentUserIdProvider);
    _currentUserName = ref.read(authProvider).user?.name ?? '';
    _scrollController.addListener(_onScroll);
    _loadMessages();
    _listenToStream();
    _listenToReadReceipts();
    _listenToRecalls();
    _listenToGroupUpdates();
    // Optimistic local clear (like web's chatStore.clearUnreadCount).
    Future.microtask(() {
      if (mounted) _roomsNotifier.clearUnreadCount(widget.roomId);
    });
    _markAsRead();
  }

  // ── Mark as read ─────────────────────────────────────────────────────────

  Future<void> _markAsRead() async {
    final manager = ref.read(signalRConnectionProvider);

    for (int i = 0; i < 5; i++) {
      if (!mounted) return;
      if (manager.isConnected) {
        try {
          await _doMarkAsRead();
          if (mounted) ref.read(chatRoomsProvider.notifier).refresh();
          return;
        } catch (_) {}
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _doMarkAsRead() async {
    final repo = ref.read(chatRepositoryProvider);
    if (_groupId != null) {
      final lastMsgId = _messages.isNotEmpty ? _messages.last.id : null;
      if (lastMsgId != null) {
        await repo.readGroupConversation(_groupId!, lastMsgId);
      }
    } else if (_otherUserId != null) {
      await repo.markConversationAsRead(_otherUserId!);
    }
  }

  // ── Read receipt listener ──────────────────────────────────────────────

  void _listenToReadReceipts() {
    _readReceiptSub = _manager.messagesReadStream.listen((event) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _messages.length; i++) {
          final msg = _messages[i];
          if (msg.senderId == _currentUserId &&
              event.messageIds.contains(msg.id) &&
              msg.status != MessageStatus.read) {
            _messages[i] = msg.copyWith(status: MessageStatus.read);
          }
        }
      });
    });
  }

  void _listenToGroupUpdates() {
    if (_groupId == null) return;
    _manager.groupInfoUpdatedStream.listen((event) {
      if (!mounted || event.groupId != _groupId) return;

      if (event.notice != null &&
          _groupInfo != null &&
          event.notice != _groupInfo!.notice) {
        // Notice changed, log system message
        final sysMsg = ChatMessage(
          id: 'sys-${DateTime.now().millisecondsSinceEpoch}',
          roomId: widget.roomId,
          senderId: 'system',
          senderName: 'System',
          type: MessageType.system,
          content: '群公告已更新',
          createdAt: DateTime.now(),
        );

        setState(() {
          _messages.insert(0, sysMsg);
          _groupInfo = _groupInfo!.copyWith(
            notice: event.notice,
            name: event.name ?? _groupInfo!.name,
            description: event.description ?? _groupInfo!.description,
            avatarUrl: event.avatarUrl ?? _groupInfo!.avatarUrl,
          );
        });
      }
    });
  }

  // ── Recall listener ─────────────────────────────────────────────────────

  void _listenToRecalls() {
    _recallSub = _manager.recallStream.listen((imMsg) {
      if (!mounted) return;

      // The recall event sends a NEW system message. The real recalled message ID
      // may be in extraProperties.MessageId (Web pattern: useChatBell.ts:344).
      final extraMessageId =
          imMsg.extraProperties?['MessageId'] as String? ??
          imMsg.extraProperties?['messageId'] as String?;
      final recalledId = (extraMessageId ?? imMsg.messageId).toLowerCase();
      setState(() {
        final idx = _messages.indexWhere(
          (m) => m.id.toLowerCase() == recalledId,
        );
        if (idx >= 0) {
          final oldMsg = _messages[idx];
          final isSelf = oldMsg.senderId == _currentUserId;
          _messages[idx] = oldMsg.copyWith(
            type: MessageType.system,
            content: isSelf ? '你撤回了一条消息' : '${oldMsg.senderName} 撤回了一条消息',
            senderId: 'system',
            senderName: 'System',
          );
        }
      });
    });
  }

  // ── Scroll tracking ─────────────────────────────────────────────────────

  void _onScroll() {
    final atBottom = _scrollController.offset < 50;
    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
        if (_isAtBottom) {
          if (_pendingMessages.isNotEmpty) _flushPending();
          _unreadAboveCount = 0;
        }
      });
    }

    if (_hasMoreMessages &&
        !_isLoadingMore &&
        _scrollController.hasClients &&
        _scrollController.offset >=
            _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _flushPending() {
    _messages.addAll(_pendingMessages);
    _pendingMessages.clear();
  }

  // ── Scroll helpers ─────────────────────────────────────────────────────

  void scrollToMessageId(String messageId, {bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _messageKeys[messageId];
      if (key == null) return;
      _scrollToKey(key, animate: animate);
    });
  }

  void _scrollToDivider({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToKey(_dividerKey, animate: animate);
    });
  }

  void _scrollToKey(GlobalKey key, {bool animate = true}) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      if (!mounted) return;
      final targetCtx = key.currentContext;

      if (targetCtx != null) {
        await Scrollable.ensureVisible(
          targetCtx,
          duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
          curve: Curves.easeOutCubic,
          alignment: 1.0,
        );
        return;
      }

      if (!_scrollController.hasClients) return;

      int msgIdx = -1;
      if (key == _dividerKey && _unreadDividerMessageId != null) {
        msgIdx = _messages.indexWhere((m) => m.id == _unreadDividerMessageId);
      } else {
        final entry = _messageKeys.entries
            .where((e) => e.value == key)
            .firstOrNull;
        if (entry != null) {
          msgIdx = _messages.indexWhere((m) => m.id == entry.key);
        }
      }

      if (msgIdx != -1) {
        final reverseIdx = _messages.length - 1 - msgIdx;
        final estimatedOffset = reverseIdx * 80.0;
        if (attempt == 0 && animate) {
          await _scrollController.animateTo(
            estimatedOffset.clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(
            estimatedOffset.clamp(
              0.0,
              _scrollController.position.maxScrollExtent,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } else {
        break;
      }
    }
  }

  /// Scroll to a quoted message and briefly highlight it.
  void _scrollToQuotedMessage(String messageId) {
    // Check if the message exists in the current list.
    final exists = _messages.any((m) => m.id == messageId);
    if (!exists) return;

    // Scroll to the message.
    scrollToMessageId(messageId);

    // Highlight with a brief flash.
    setState(() => _highlightedMessageId = messageId);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _highlightedMessageId = null);
      }
    });
  }

  // ── Load & stream ────────────────────────────────────────────────────────

  Future<void> _loadMessages() async {
    final List<ChatMessage> messages;
    try {
      if (_groupId != null) {
        messages = await _repo.getGroupMessages(
          _groupId!,
          maxResultCount: _pageSize,
        );
      } else {
        messages = await _repo.getUserMessages(
          widget.roomId,
          maxResultCount: _pageSize,
        );
      }
    } catch (e, st) {
      debugPrint('[ChatDetail] _loadMessages FAILED: $e\n$st');
      return;
    }
    if (mounted) {
      setState(() {
        _messages.clear();
        _messageKeys.clear();
        _messages.addAll(messages);
        _initialLoaded = true;
        _hasMoreMessages = messages.length >= _pageSize;

        final unread = widget.initialUnreadCount;
        if (unread > 0 && messages.isNotEmpty) {
          final userId = _currentUserId;
          int othersCount = 0;
          int anchorIdx = messages.length;
          for (int i = messages.length - 1; i >= 0; i--) {
            if (messages[i].senderId != userId) {
              othersCount++;
            }
            if (othersCount >= unread) {
              anchorIdx = i;
              break;
            }
          }
          if (othersCount > 0 && anchorIdx < messages.length) {
            _unreadDividerMessageId = messages[anchorIdx].id;
            _unreadAboveCount = othersCount;
          }
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMoreMessages) return;
    _isLoadingMore = true;
    if (mounted) setState(() {});

    try {
      final List<ChatMessage> older;
      if (_groupId != null) {
        older = await _repo.getGroupMessages(
          _groupId!,
          skipCount: _messages.length,
          maxResultCount: _pageSize,
        );
      } else {
        older = await _repo.getUserMessages(
          widget.roomId,
          skipCount: _messages.length,
          maxResultCount: _pageSize,
        );
      }
      if (mounted) {
        setState(() {
          _messages.insertAll(0, older);
          _hasMoreMessages = older.length >= _pageSize;
        });
      }
    } catch (_) {}
    _isLoadingMore = false;
    if (mounted) setState(() {});
  }

  void _listenToStream() {
    final repo = ref.read(chatRepositoryProvider);
    _streamSub = repo.messageStream(widget.roomId).listen((message) {
      if (!mounted) return;
      // Dedup: skip if this message ID already exists (e.g. provisional echo).
      if (_messages.any((m) => m.id == message.id)) return;
      setState(() {
        if (_isAtBottom) {
          _messages.add(message);
          if (_firstRealtimeMessageId == null) {
            _firstRealtimeMessageId = message.id;
            _realtimeMessageCount = 1;
          } else {
            _realtimeMessageCount++;
          }
          _checkFirstRealtimeVisibility();
        } else {
          _pendingMessages.add(message);
        }
      });
    });
  }

  void _checkFirstRealtimeVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_firstRealtimeMessageId == null) return;

      final key = _messageKeys[_firstRealtimeMessageId];
      if (key == null) return;

      final ctx = key.currentContext;
      if (ctx == null) {
        _onRealtimeMessagesOffScreen();
        return;
      }

      final renderObj = ctx.findRenderObject();
      if (renderObj == null) {
        _onRealtimeMessagesOffScreen();
        return;
      }

      final viewport = RenderAbstractViewport.maybeOf(renderObj);
      if (viewport == null) return;

      final revealOffset = viewport.getOffsetToReveal(renderObj, 1.0).offset;
      final currentOffset = _scrollController.offset;

      if (revealOffset > currentOffset + 50) {
        _onRealtimeMessagesOffScreen();
      }
    });
  }

  void _onRealtimeMessagesOffScreen() {
    if (_realtimeMessageCount <= 0) return;
    setState(() {
      _unreadDividerMessageId = _firstRealtimeMessageId;
      _unreadAboveCount = _realtimeMessageCount;
      _dividerSeen = false;
    });
  }

  // ── Scroll actions ──────────────────────────────────────────────────────

  void _scrollToUnreadAbove() {
    setState(() {
      _unreadAboveCount = 0;
      _dividerSeen = true;
      _firstRealtimeMessageId = null;
      _realtimeMessageCount = 0;
    });
    _scrollToDivider();
  }

  void _scrollToNewBelow() {
    if (_pendingMessages.isEmpty) return;
    final firstNewId = _pendingMessages.first.id;
    setState(() {
      _unreadDividerMessageId = firstNewId;
      _flushPending();
    });
    _scrollController.jumpTo(0);
  }

  // Key to access ChatInputBar state for closing panels.
  final GlobalKey<ChatInputBarState> _inputBarKey =
      GlobalKey<ChatInputBarState>();

  // ── Send text ──────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final repo = ref.read(chatRepositoryProvider);
    final userId = _currentUserId;

    // Build extraProperties for quoted reply (matches Web's QuotedMessageExtra).
    Map<String, dynamic>? extraProps;
    if (_replyingTo != null) {
      final quotedType = switch (_replyingTo!.type) {
        MessageType.text => ImMessageType.text.value,
        MessageType.image => ImMessageType.image.value,
        MessageType.video => ImMessageType.video.value,
        MessageType.audio => ImMessageType.voice.value,
        MessageType.file => ImMessageType.file.value,
        MessageType.system => ImMessageType.notifier.value,
        MessageType.contactCard => ImMessageType.contactCard.value,
        MessageType.voiceCall => ImMessageType.voiceCall.value,
        MessageType.videoCall => ImMessageType.videoCall.value,
      };
      extraProps = {
        'quotedMessageId': _replyingTo!.id,
        'quotedSenderName': _replyingTo!.senderName,
        'quotedContent': _replyingTo!.type == MessageType.text
            ? _replyingTo!.content
            : '[${_replyingTo!.type.name}]',
        'quotedMessageType': quotedType,
      };
    }

    final imMessage = ImChatMessage(
      messageId: '',
      formUserId: userId,
      formUserName: _currentUserName,
      toUserId: _otherUserId,
      groupId: _groupId ?? '',
      content: text,
      sendTime: DateTime.now().toUtc().toIso8601String(),
      messageType: ImMessageType.text.value,
      source: ImMessageSourceType.user.value,
      extraProperties: extraProps,
    );

    final messageId = await repo.sendMessage(imMessage);

    if (mounted) {
      final provisional = ChatMessage(
        id: messageId,
        roomId: widget.roomId,
        senderId: userId,
        senderName: '',
        type: MessageType.text,
        content: text,
        createdAt: DateTime.now(),
        status: MessageStatus.sent,
        quotedMessageId: _replyingTo?.id,
        quotedSenderName: _replyingTo?.senderName,
        quotedContent: _replyingTo?.type == MessageType.text
            ? _replyingTo?.content
            : '[${_replyingTo?.type.name ?? ''}]',
        quotedMessageType: _replyingTo?.type,
      );
      setState(() {
        _replyingTo = null;
        _flushPending();
        if (!_messages.any((m) => m.id == provisional.id)) {
          _messages.add(provisional);
        }
        _unreadDividerMessageId = null;
        _unreadAboveCount = 0;
        _firstRealtimeMessageId = null;
        _realtimeMessageCount = 0;
      });
      _scrollController.jumpTo(0);
    }
  }

  // ── Message actions ────────────────────────────────────────────────────

  void _onMessageAction(MessageAction action, ChatMessage message) {
    switch (action) {
      case MessageAction.copy:
        // Handled in MessageBubble directly.
        break;
      case MessageAction.reply:
        setState(() => _replyingTo = message);
        break;
      case MessageAction.forward:
        _handleForward(message);
        break;
      case MessageAction.recall:
        _handleRecall(message);
        break;
      case MessageAction.delete:
        _handleDelete(message);
        break;
    }
  }

  Future<void> _handleRecall(ChatMessage message) async {
    try {
      // Build the ImChatMessage that the backend hub expects.
      final imMsgType = switch (message.type) {
        MessageType.text => ImMessageType.text.value,
        MessageType.image => ImMessageType.image.value,
        MessageType.video => ImMessageType.video.value,
        MessageType.audio => ImMessageType.voice.value,
        MessageType.file => ImMessageType.file.value,
        MessageType.system => ImMessageType.text.value,
        MessageType.contactCard => ImMessageType.contactCard.value,
        MessageType.voiceCall => ImMessageType.voiceCall.value,
        MessageType.videoCall => ImMessageType.videoCall.value,
      };

      final imMessage = ImChatMessage(
        messageId: message.id,
        formUserId: message.senderId,
        formUserName: message.senderName,
        toUserId: _isDirect ? _otherUserId : null,
        groupId: _groupId ?? '',
        content: message.content,
        sendTime: message.createdAt.toUtc().toIso8601String(),
        messageType: imMsgType,
        source: ImMessageSourceType.user.value,
      );

      await _repo.recallMessage(imMessage);
      if (mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == message.id);
          if (idx >= 0) {
            _messages[idx] = ChatMessage(
              id: message.id,
              roomId: message.roomId,
              senderId: 'system',
              senderName: 'System',
              type: MessageType.system,
              content: '你撤回了一条消息',
              createdAt: message.createdAt,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('撤回失败: $e')));
      }
    }
  }

  Future<void> _handleDelete(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定要删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _repo.deleteMessage(
        messageId: message.id,
        conversationId: widget.roomId,
        groupId: _groupId,
      );
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == message.id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  Future<void> _handleForward(ChatMessage message) async {
    final target = await showForwardSheet(context, ref);
    if (target == null || !mounted) return;

    // Show WeChat-style bottom sheet confirmation.
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForwardConfirmSheet(
        message: message,
        targetName: target.displayName,
      ),
    );
    // result == null → cancelled, result == '' → no extra text, else has text.
    if (result == null || !mounted) return;

    try {
      final repo = ref.read(chatRepositoryProvider);

      // Determine forwarded message type.
      final imMsgType = switch (message.type) {
        MessageType.text => ImMessageType.text.value,
        MessageType.image => ImMessageType.image.value,
        MessageType.video => ImMessageType.video.value,
        MessageType.audio => ImMessageType.voice.value,
        MessageType.file => ImMessageType.file.value,
        MessageType.system => ImMessageType.text.value,
        MessageType.contactCard => ImMessageType.contactCard.value,
        MessageType.voiceCall => ImMessageType.voiceCall.value,
        MessageType.videoCall => ImMessageType.videoCall.value,
      };

      final forwardContent = message.fileUrl ?? message.content;

      final extraProps = <String, dynamic>{
        'isForwarded': true,
        'originalSenderName': message.senderName,
        'originalContent': message.content,
        'originalMessageType': imMsgType,
      };

      if (message.fileName != null) extraProps['fileName'] = message.fileName;
      if (message.fileSize != null) extraProps['fileSize'] = message.fileSize;
      if (message.fileExt != null) extraProps['fileExt'] = message.fileExt;
      if (message.mimeType != null) extraProps['mimeType'] = message.mimeType;

      // Send the forwarded message.
      final fwdMessage = ImChatMessage(
        messageId: '',
        formUserId: _currentUserId,
        formUserName: _currentUserName,
        toUserId: target.type == 'user' ? target.conversationKey : null,
        groupId: target.groupId ?? '',
        content: forwardContent,
        sendTime: DateTime.now().toUtc().toIso8601String(),
        messageType: imMsgType,
        source: ImMessageSourceType.user.value,
        extraProperties: extraProps,
      );
      await repo.sendMessage(fwdMessage);

      // If user typed an accompanying message, send it too.
      if (result.isNotEmpty) {
        final textMessage = ImChatMessage(
          messageId: '',
          formUserId: _currentUserId,
          formUserName: _currentUserName,
          toUserId: target.type == 'user' ? target.conversationKey : null,
          groupId: target.groupId ?? '',
          content: result,
          sendTime: DateTime.now().toUtc().toIso8601String(),
          messageType: ImMessageType.text.value,
          source: ImMessageSourceType.user.value,
        );
        await repo.sendMessage(textMessage);
      }

      if (mounted) {
        showCenterToast(context, '已转发给 ${target.displayName}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('转发失败: $e')));
      }
    }
  }

  Widget _buildReplyBar() {
    final msg = _replyingTo!;
    final preview = msg.type == MessageType.text
        ? msg.content
        : '[${msg.type.name}]';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: EbiColors.divider,
        border: Border(
          left: BorderSide(color: EbiColors.primaryBlue, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.senderName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: EbiColors.primaryBlue,
                  ),
                ),
                Text(
                  preview,
                  style: const TextStyle(
                    fontSize: 12,
                    color: EbiColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyingTo = null),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 18, color: EbiColors.textHint),
            ),
          ),
        ],
      ),
    );
  }

  // ── Media picking ──────────────────────────────────────────────────────

  Future<void> _pickCamera() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) return;
    _uploadAndSend(
      localPath: file.path,
      fileName: file.name,
      messageType: MessageType.image,
      subDir: 'image',
      imMessageType: ImMessageType.image,
    );
  }

  Future<void> _pickPhotos() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 85);
    for (final file in files) {
      _uploadAndSend(
        localPath: file.path,
        fileName: file.name,
        messageType: MessageType.image,
        subDir: 'image',
        imMessageType: ImMessageType.image,
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    _uploadAndSend(
      localPath: file.path!,
      fileName: file.name,
      messageType: MessageType.file,
      subDir: 'file',
      imMessageType: ImMessageType.file,
      fileSize: file.size,
    );
  }

  void _startVoiceCall() {
    if (!_isDirect || _otherUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('群聊暂不支持语音通话')));
      }
      return;
    }
    ref
        .read(callStateProvider.notifier)
        .startCall(
          targetUserId: _otherUserId!,
          targetUserName: widget.roomName ?? '未知用户',
          callType: CallType.voice,
        );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OutgoingCallPage()));
  }

  void _startVideoCall() {
    if (!_isDirect || _otherUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('群聊暂不支持视频通话')));
      }
      return;
    }
    ref
        .read(callStateProvider.notifier)
        .startCall(
          targetUserId: _otherUserId!,
          targetUserName: widget.roomName ?? '未知用户',
          callType: CallType.video,
        );
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OutgoingCallPage()));
  }

  Future<void> _pickVideo() async {
    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    _uploadAndSend(
      localPath: file.path,
      fileName: file.name,
      messageType: MessageType.video,
      subDir: 'video',
      imMessageType: ImMessageType.video,
    );
  }

  Future<void> _sendVoice(String localPath, int durationSeconds) async {
    final file = File(localPath);
    int? fileSize;
    if (await file.exists()) {
      fileSize = await file.length();
    }
    _uploadAndSend(
      localPath: localPath,
      fileName: localPath.split('/').last,
      messageType: MessageType.audio,
      subDir: 'voice',
      imMessageType: ImMessageType.voice,
      fileSize: fileSize,
      duration: durationSeconds,
    );
  }

  // ── Upload & send pipeline ─────────────────────────────────────────────

  Future<void> _uploadAndSend({
    required String localPath,
    required String fileName,
    required MessageType messageType,
    required String subDir,
    required ImMessageType imMessageType,
    int? fileSize,
    int? duration,
  }) async {
    final localId = _uuid.v4();
    final pending = PendingUpload(
      localId: localId,
      localPath: localPath,
      fileName: fileName,
      messageType: messageType,
      status: UploadStatus.uploading,
    );

    setState(() => _pendingUploads.add(pending));
    _scrollController.jumpTo(0);

    try {
      // 1. Upload to OSS
      final ossService = ref.read(ossUrlServiceProvider);
      final ossPath = await ossService.uploadFile(
        localPath: localPath,
        fileName: fileName,
        conversationKey: _conversationKey,
        subDir: subDir,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            final idx = _pendingUploads.indexWhere((u) => u.localId == localId);
            if (idx >= 0) {
              _pendingUploads[idx] = _pendingUploads[idx].copyWith(
                progress: progress,
              );
            }
          });
        },
      );

      // 2. Update status to sending
      _updatePendingStatus(localId, UploadStatus.sending, ossPath: ossPath);

      // 3. Send message via SignalR/REST
      final mimeType = lookupMimeType(fileName);
      final extraProps = <String, dynamic>{
        'fileName': fileName,
        if (mimeType != null) 'mimeType': mimeType,
        if (fileSize != null) 'fileSize': fileSize,
        'fileExt': _extFromName(fileName) ?? '',
        if (duration != null) 'duration': duration,
      };

      final imMessage = ImChatMessage(
        messageId: '',
        formUserId: _currentUserId,
        formUserName: _currentUserName,
        toUserId: _otherUserId,
        groupId: _groupId ?? '',
        content: ossPath,
        sendTime: DateTime.now().toUtc().toIso8601String(),
        messageType: imMessageType.value,
        source: ImMessageSourceType.user.value,
        extraProperties: extraProps,
      );

      final repo = ref.read(chatRepositoryProvider);
      final messageId = await repo.sendMessage(imMessage);

      // 4. Add provisional message to list
      if (mounted) {
        final provisional = ChatMessage(
          id: messageId,
          roomId: widget.roomId,
          senderId: _currentUserId,
          senderName: '',
          type: messageType,
          content: ossPath,
          fileName: fileName,
          fileSize: fileSize,
          mimeType: mimeType,
          fileExt: _extFromName(fileName),
          mediaDuration: duration,
          createdAt: DateTime.now(),
          status: MessageStatus.sent,
        );

        setState(() {
          _flushPending();
          if (!_messages.any((m) => m.id == provisional.id)) {
            _messages.add(provisional);
          }
          _pendingUploads.removeWhere((u) => u.localId == localId);
          _unreadDividerMessageId = null;
          _unreadAboveCount = 0;
          _firstRealtimeMessageId = null;
          _realtimeMessageCount = 0;
        });
        _scrollController.jumpTo(0);
      }
    } catch (e) {
      if (mounted) {
        _updatePendingStatus(
          localId,
          UploadStatus.failed,
          error: e is OssUrlException ? e.message : 'Upload failed',
        );
      }
    }
  }

  void _updatePendingStatus(
    String localId,
    UploadStatus status, {
    String? ossPath,
    String? error,
  }) {
    setState(() {
      final idx = _pendingUploads.indexWhere((u) => u.localId == localId);
      if (idx >= 0) {
        _pendingUploads[idx] = _pendingUploads[idx].copyWith(
          status: status,
          ossPath: ossPath,
          error: error,
        );
      }
    });
  }

  // ── Typing indicator ──────────────────────────────────────────────────

  void _onTypingChanged(bool isTyping) {
    if (!_isDirect || _otherUserId == null) return;
    if (isTyping) {
      _manager.sendTyping(_otherUserId!);
    } else {
      _manager.sendStopTyping(_otherUserId!);
    }
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────

  @override
  void dispose() {
    _streamSub?.cancel();
    _readReceiptSub?.cancel();
    _recallSub?.cancel();
    _scrollController.dispose();
    _markAsReadOnExit();
    super.dispose();
  }

  void _markAsReadOnExit() {
    if (!_manager.isConnected) return;

    if (_groupId != null) {
      final lastMsgId = _messages.isNotEmpty ? _messages.last.id : null;
      if (lastMsgId != null) {
        _repo
            .readGroupConversation(_groupId!, lastMsgId)
            .then((_) {
              _roomsNotifier.refresh();
            })
            .catchError((_) {});
      }
    } else if (_otherUserId != null) {
      _repo
          .markConversationAsRead(_otherUserId!)
          .then((_) {
            _roomsNotifier.refresh();
          })
          .catchError((_) {});
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.roomName ?? 'Chat',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            if (_groupId != null)
              const Text(
                '群聊',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: EbiColors.primaryBlue,
        foregroundColor: EbiColors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () async {
              if (_groupId != null) {
                final didChange = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => GroupSettingsPage(
                      groupId: _groupId!,
                      groupName: _groupInfo?.name ?? widget.roomName,
                    ),
                  ),
                );

                if (didChange == true && mounted) {
                  // Reload group info so the app bar title updates
                  try {
                    final api = ref.read(groupApiServiceProvider);
                    final updatedGroup = await api.getGroup(_groupId!);
                    if (mounted) {
                      setState(() {
                        _groupInfo = updatedGroup;
                      });
                    }
                  } catch (e) {
                    AppLogger.error(
                      'Failed to reload group info after settings edit',
                      e,
                    );
                  }
                }
              } else if (_otherUserId != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatSettingsPage(
                      otherUserId: _otherUserId!,
                      otherUserName: widget.roomName,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _initialLoaded
                ? _buildMessageList()
                : const EbiLoading(message: 'Loading messages...'),
          ),
          // Typing indicator (only for 1-to-1).
          if (_isDirect && _otherUserId != null)
            TypingIndicator(conversationId: _otherUserId!),
          ChatInputBar(
            key: _inputBarKey,
            onSendText: _sendMessage,
            onPickCamera: _pickCamera,
            onPickPhotos: _pickPhotos,
            onPickFile: _pickFile,
            onPickVideo: _pickVideo,
            onVoiceCall: _startVoiceCall,
            onVideoCall: _startVideoCall,
            onSendVoice: _sendVoice,
            onTypingChanged: _isDirect ? _onTypingChanged : null,
            replyWidget: _replyingTo != null ? _buildReplyBar() : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty && _pendingUploads.isEmpty) {
      return const EbiEmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No Messages Yet',
        subtitle: 'Start the conversation!',
      );
    }

    final userId = _currentUserId;
    final messageCount = _messages.length;
    final totalCount = messageCount + _pendingUploads.length;

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            _inputBarKey.currentState?.closePanels();
          },
          behavior: HitTestBehavior.opaque,
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: totalCount + (_isLoadingMore ? 1 : 0),
            findChildIndexCallback: (key) {
              if (key is ValueKey<String>) {
                final idx = _messages.indexWhere((m) => m.id == key.value);
                if (idx >= 0) return totalCount - 1 - idx;
              }
              return null;
            },
            itemBuilder: (context, index) {
              // Loading indicator at the top (last index in reverse list).
              if (index == totalCount) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              // Pending uploads appear at the bottom (index 0..N-1 in reverse).
              if (index < _pendingUploads.length) {
                final uploadIdx = _pendingUploads.length - 1 - index;
                final upload = _pendingUploads[uploadIdx];
                return UploadProgressBubble(
                  key: ValueKey('upload-${upload.localId}'),
                  upload: upload,
                  onRetry: upload.status == UploadStatus.failed
                      ? () {
                          // Remove failed upload and retry.
                          setState(() => _pendingUploads.removeAt(uploadIdx));
                          _uploadAndSend(
                            localPath: upload.localPath,
                            fileName: upload.fileName,
                            messageType: upload.messageType,
                            subDir: _subDirForType(upload.messageType),
                            imMessageType: _imTypeForType(upload.messageType),
                          );
                        }
                      : null,
                );
              }

              final msgIndex =
                  messageCount - 1 - (index - _pendingUploads.length);
              final msg = _messages[msgIndex];
              final msgKey = _keyForMessage(msg.id);
              final widgets = <Widget>[];

              // ── "以下为新消息" divider ──
              if (_unreadDividerMessageId != null &&
                  msg.id == _unreadDividerMessageId) {
                widgets.add(_UnreadDivider(key: _dividerKey));
              }

              // ── Date separator ──
              if (msgIndex == 0) {
                widgets.add(ChatDateSeparator(date: msg.createdAt));
              } else {
                final prevMsg = _messages[msgIndex - 1];
                final msgDate = DateTime(
                  msg.createdAt.year,
                  msg.createdAt.month,
                  msg.createdAt.day,
                );
                final prevDate = DateTime(
                  prevMsg.createdAt.year,
                  prevMsg.createdAt.month,
                  prevMsg.createdAt.day,
                );
                if (msgDate != prevDate) {
                  widgets.add(ChatDateSeparator(date: msg.createdAt));
                }
              }

              // ── Message bubble ──
              if (msg.type == MessageType.system) {
                widgets.add(
                  KeyedSubtree(
                    key: msgKey,
                    child: SystemMessageWidget(message: msg),
                  ),
                );
              } else {
                final isHighlighted = _highlightedMessageId == msg.id;
                widgets.add(
                  KeyedSubtree(
                    key: msgKey,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? EbiColors.primaryBlue.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: MessageBubble(
                        message: msg,
                        isMe: msg.senderId == userId,
                        onAction: _onMessageAction,
                        onQuoteTap: _scrollToQuotedMessage,
                        onAvatarTap: (senderId) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UserProfilePage(userId: senderId),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }

              return Column(
                key: ValueKey(msg.id),
                mainAxisSize: MainAxisSize.min,
                children: widgets,
              );
            },
          ),
        ),

        // ↑ N 条新消息
        Positioned(
          right: 16,
          top: 12,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _unreadAboveCount > 0
                ? _buildFloatingButton(
                    key: 'unread-up',
                    icon: Icons.arrow_upward,
                    count: _unreadAboveCount,
                    onTap: _scrollToUnreadAbove,
                  )
                : const SizedBox.shrink(),
          ),
        ),

        // ↓ N 条新消息
        Positioned(
          right: 16,
          bottom: 12,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: (_pendingMessages.isNotEmpty && !_isAtBottom)
                ? _buildFloatingButton(
                    key: 'new-down',
                    icon: Icons.arrow_downward,
                    count: _pendingMessages.length,
                    onTap: _scrollToNewBelow,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required String key,
    required IconData icon,
    required int count,
    required VoidCallback onTap,
  }) {
    return Material(
      key: ValueKey(key),
      color: EbiColors.primaryBlue,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: EbiColors.white),
              const SizedBox(width: 4),
              Text(
                '$count 条新消息',
                style: const TextStyle(
                  color: EbiColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _subDirForType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'image';
      case MessageType.video:
        return 'video';
      case MessageType.audio:
        return 'voice';
      default:
        return 'file';
    }
  }

  static ImMessageType _imTypeForType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return ImMessageType.image;
      case MessageType.video:
        return ImMessageType.video;
      case MessageType.audio:
        return ImMessageType.voice;
      default:
        return ImMessageType.file;
    }
  }

  static String? _extFromName(String? name) {
    if (name == null) return null;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }
}

/// "以下为新消息" — visual divider between read and unread messages.
class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Row(
        children: const [
          Expanded(
            child: Divider(color: EbiColors.primaryBlue, thickness: 0.5),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '以下为新消息',
              style: TextStyle(
                color: EbiColors.primaryBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: EbiColors.primaryBlue, thickness: 0.5),
          ),
        ],
      ),
    );
  }
}

/// ── WeChat-style forward confirm bottom sheet ─────────────────────────────
///
/// Shows: recipient info → message preview → optional text input → send/cancel.
/// Returns the accompanying text (empty string if none) or null if cancelled.
class _ForwardConfirmSheet extends StatefulWidget {
  final ChatMessage message;
  final String targetName;

  const _ForwardConfirmSheet({required this.message, required this.targetName});

  @override
  State<_ForwardConfirmSheet> createState() => _ForwardConfirmSheetState();
}

class _ForwardConfirmSheetState extends State<_ForwardConfirmSheet> {
  final _textController = TextEditingController();
  bool _showEmojiPicker = false;

  // Common emojis for quick insert.
  static const _quickEmojis = [
    '😀',
    '😂',
    '🤣',
    '😍',
    '🥰',
    '😘',
    '😊',
    '🤗',
    '🤔',
    '😏',
    '😢',
    '😭',
    '😤',
    '🥺',
    '👍',
    '👏',
    '🎉',
    '❤️',
    '🔥',
    '💯',
    '✅',
    '👌',
    '🙏',
    '💪',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle bar ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header: 发送给 ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '转发给',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
              ),

              // ── Recipient row ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Avatar placeholder.
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: EbiColors.primaryBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: EbiColors.primaryBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.targetName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: EbiColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 22,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.shade200),

              // ── Message preview ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: _buildPreview(),
              ),

              Divider(height: 1, color: Colors.grey.shade200),

              // ── Text input with emoji toggle ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        maxLines: 2,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: '发消息',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() => _showEmojiPicker = !_showEmojiPicker);
                      },
                      child: Icon(
                        _showEmojiPicker
                            ? Icons.keyboard
                            : Icons.emoji_emotions_outlined,
                        size: 28,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Emoji picker grid ──
              if (_showEmojiPicker)
                Container(
                  height: 160,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemCount: _quickEmojis.length,
                    itemBuilder: (_, index) {
                      return GestureDetector(
                        onTap: () {
                          final text = _textController.text;
                          final selection = _textController.selection;
                          final newText = text.replaceRange(
                            selection.start.clamp(0, text.length),
                            selection.end.clamp(0, text.length),
                            _quickEmojis[index],
                          );
                          _textController.text = newText;
                          _textController.selection = TextSelection.collapsed(
                            offset:
                                (selection.start.clamp(0, text.length)) +
                                _quickEmojis[index].length,
                          );
                        },
                        child: Center(
                          child: Text(
                            _quickEmojis[index],
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // ── Actions: Cancel + Send ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 16,
                            color: EbiColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pop(_textController.text.trim());
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF07C160),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '转发',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final msg = widget.message;
    switch (msg.type) {
      case MessageType.text:
      case MessageType.voiceCall:
      case MessageType.videoCall:
        return Row(
          children: [
            Expanded(
              child: Text(
                msg.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: EbiColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '详情',
              style: TextStyle(fontSize: 13, color: EbiColors.primaryBlue),
            ),
          ],
        );

      case MessageType.image:
        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                msg.fileUrl ?? '',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey.shade200,
                  child: const Icon(
                    Icons.image,
                    color: EbiColors.textHint,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '[图片]',
                style: TextStyle(fontSize: 14, color: EbiColors.textSecondary),
              ),
            ),
            Text(
              '详情',
              style: TextStyle(fontSize: 13, color: EbiColors.primaryBlue),
            ),
          ],
        );

      case MessageType.video:
        return Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.play_circle_fill,
                size: 28,
                color: EbiColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg.fileName ?? '[视频]',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: EbiColors.textSecondary,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                // Preview video.
                if (msg.fileUrl != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: Colors.black,
                        appBar: AppBar(
                          backgroundColor: Colors.black,
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        body: Center(
                          child: Text(
                            '[视频预览]',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              },
              child: Text(
                '详情',
                style: TextStyle(fontSize: 13, color: EbiColors.primaryBlue),
              ),
            ),
          ],
        );

      case MessageType.file:
        return Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: EbiColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.insert_drive_file,
                size: 22,
                color: EbiColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.fileName ?? '[文件]',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (msg.fileSize != null)
                    Text(
                      _formatBytes(msg.fileSize!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: EbiColors.textHint,
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                if (msg.fileUrl != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FilePreviewPage(
                        ossPath: msg.fileUrl!,
                        fileName: msg.fileName ?? '文件',
                      ),
                    ),
                  );
                }
              },
              child: Text(
                '预览',
                style: TextStyle(fontSize: 13, color: EbiColors.primaryBlue),
              ),
            ),
          ],
        );

      case MessageType.audio:
        return const Row(
          children: [
            Icon(Icons.mic, size: 20, color: EbiColors.primaryBlue),
            SizedBox(width: 8),
            Text(
              '[语音消息]',
              style: TextStyle(fontSize: 13, color: EbiColors.textSecondary),
            ),
          ],
        );

      case MessageType.system:
        return Row(
          children: [
            const Icon(Icons.info_outline, size: 16, color: EbiColors.textHint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: EbiColors.textSecondary,
                ),
              ),
            ),
          ],
        );

      case MessageType.contactCard:
        return Row(
          children: [
            const Icon(Icons.person, size: 16, color: EbiColors.textHint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '[个人名片] ${msg.content}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: EbiColors.textSecondary,
                ),
              ),
            ),
          ],
        );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
