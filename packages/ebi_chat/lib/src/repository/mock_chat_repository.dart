import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/chat_room.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/repository/chat_repository.dart';

/// Mock implementation of [ChatRepository] for offline development.
/// Simulates incoming messages every 15 seconds via StreamController.
class MockChatRepository implements ChatRepository {
  static const _uuid = Uuid();
  static const _currentUserId = 'user-001';
  static const _currentUserName = 'Brian Chen';

  final Map<String, StreamController<ChatMessage>> _controllers = {};
  final Map<String, List<ChatMessage>> _messageCache = {};
  final Map<String, Timer> _simulationTimers = {};

  List<ChatRoom> get _mockRooms => [
        // ── Direct Messages (个人私聊) ──
        ChatRoom(
          id: 'user-002',
          name: 'Alice Wang',
          type: ChatRoomType.direct,
          tenantName: 'Delta',
          memberIds: const ['user-001', 'user-002'],
          lastMessage: 'Shipment confirmed for next week',
          lastSenderName: 'Alice Wang',
          lastMessageAt: DateTime.now().subtract(const Duration(minutes: 10)),
          unreadCount: 2,
          isOnline: true,
          createdAt: DateTime(2024, 11, 1),
        ),
        ChatRoom(
          id: 'user-003',
          name: 'David Liu',
          type: ChatRoomType.direct,
          tenantName: 'BKR',
          memberIds: const ['user-001', 'user-003'],
          lastMessage: 'I\'ll send the updated specs tonight',
          lastSenderName: 'David Liu',
          lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
          unreadCount: 0,
          isOnline: true,
          createdAt: DateTime(2025, 1, 5),
        ),
        ChatRoom(
          id: 'user-008',
          name: 'Sarah Miller',
          type: ChatRoomType.direct,
          tenantName: 'MTI',
          memberIds: const ['user-001', 'user-008'],
          lastMessage: 'Thanks for the quick response!',
          lastSenderName: 'Sarah Miller',
          lastMessageAt: DateTime.now().subtract(const Duration(hours: 6)),
          unreadCount: 1,
          isOnline: false,
          createdAt: DateTime(2025, 1, 20),
        ),

        // ── Group Chats (多人群聊) ──
        ChatRoom(
          id: 'group:group-001',
          name: 'PO-2024-0012 Discussion',
          type: ChatRoomType.group,
          tenantName: 'FELL',
          orderId: 'order-001',
          memberIds: const ['user-001', 'user-002', 'user-003', 'user-004'],
          memberCount: 4,
          lastMessage: 'Please check the updated specs',
          lastSenderName: 'Alice Wang',
          lastMessageAt: DateTime.now().subtract(const Duration(minutes: 45)),
          unreadCount: 3,
          createdAt: DateTime(2024, 12, 5),
        ),
        ChatRoom(
          id: 'group:group-002',
          name: 'Alpha Sample Review',
          type: ChatRoomType.group,
          tenantName: 'Delta',
          projectId: 'proj-001',
          memberIds: const ['user-001', 'user-005', 'user-006', 'user-007'],
          memberCount: 4,
          lastMessage: 'Inspection report uploaded',
          lastSenderName: 'Emma Zhang',
          lastMessageAt: DateTime.now().subtract(const Duration(hours: 3)),
          unreadCount: 5,
          createdAt: DateTime(2025, 1, 10),
        ),
      ];

  List<ChatMessage> _mockMessages(String conversationId) {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: _uuid.v4(),
        roomId: conversationId,
        senderId: 'user-002',
        senderName: 'Alice Wang',
        type: MessageType.text,
        content: 'Good morning! The sample has been approved by the client.',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      ChatMessage(
        id: _uuid.v4(),
        roomId: conversationId,
        senderId: _currentUserId,
        senderName: _currentUserName,
        type: MessageType.text,
        content: 'Great news! Let me update the production schedule.',
        createdAt: now.subtract(const Duration(hours: 3, minutes: 50)),
      ),
      ChatMessage(
        id: _uuid.v4(),
        roomId: conversationId,
        senderId: 'system',
        senderName: 'System',
        type: MessageType.system,
        content: 'Alice Wang added David Liu to the chat',
        createdAt: now.subtract(const Duration(hours: 3, minutes: 30)),
      ),
      ChatMessage(
        id: _uuid.v4(),
        roomId: conversationId,
        senderId: 'user-003',
        senderName: 'David Liu',
        type: MessageType.image,
        content: 'Sample photo',
        fileUrl: 'https://picsum.photos/400/300',
        fileName: 'sample_photo.jpg',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      ChatMessage(
        id: _uuid.v4(),
        roomId: conversationId,
        senderId: 'user-002',
        senderName: 'Alice Wang',
        type: MessageType.file,
        content: 'Updated specification document',
        fileUrl: 'https://example.com/spec_v2.pdf',
        fileName: 'spec_v2.pdf',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 30)),
      ),
      ChatMessage(
        id: _uuid.v4(),
        roomId: conversationId,
        senderId: 'user-003',
        senderName: 'David Liu',
        type: MessageType.video,
        content: 'Factory tour video',
        fileUrl: 'https://example.com/factory_tour.mp4',
        fileName: 'factory_tour.mp4',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      ChatMessage(
        id: _uuid.v4(),
        roomId: conversationId,
        senderId: _currentUserId,
        senderName: _currentUserName,
        type: MessageType.text,
        content: 'Looks good! Shipment confirmed for next week.',
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
    ];
  }

  @override
  Future<List<ChatRoom>> getConversations({int? maxResultCount}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockRooms;
  }

  @override
  Future<List<ChatMessage>> getUserMessages(
    String receiveUserId, {
    int skipCount = 0,
    int maxResultCount = 50,
    int? messageType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _messageCache[receiveUserId] ??= _mockMessages(receiveUserId);
    return List.from(_messageCache[receiveUserId]!);
  }

  @override
  Future<List<ChatMessage>> getGroupMessages(
    String groupId, {
    int skipCount = 0,
    int maxResultCount = 50,
    int? messageType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final convId = 'group:$groupId';
    _messageCache[convId] ??= _mockMessages(convId);
    return List.from(_messageCache[convId]!);
  }

  @override
  Future<List<ChatMessage>> getMediaMessages({
    String? groupId,
    String? receiveUserId,
    int skipCount = 0,
    int maxResultCount = 50,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final String convId = groupId != null ? 'group:$groupId' : receiveUserId!;
    _messageCache[convId] ??= _mockMessages(convId);
    final allMessages = _messageCache[convId]!;
    final mediaMessages = allMessages.where((m) => 
        m.type == MessageType.image || m.type == MessageType.video).toList();
    mediaMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mediaMessages;
  }

  @override
  Future<String> sendMessage(ImChatMessage message) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final convId = message.isGroupMessage
        ? 'group:${message.groupId}'
        : (message.toUserId ?? message.formUserId);
    final uiMessage = ChatMessage(
      id: _uuid.v4(),
      roomId: convId,
      senderId: _currentUserId,
      senderName: _currentUserName,
      type: MessageType.text,
      content: message.content,
      createdAt: DateTime.now(),
    );
    _messageCache[convId] ??= _mockMessages(convId);
    _messageCache[convId]!.add(uiMessage);
    return uiMessage.id;
  }

  @override
  Stream<ChatMessage> messageStream(String conversationId) {
    _controllers[conversationId] ??=
        StreamController<ChatMessage>.broadcast();
    _startSimulation(conversationId);
    return _controllers[conversationId]!.stream;
  }

  void _startSimulation(String conversationId) {
    if (_simulationTimers.containsKey(conversationId)) return;

    final mockSenders = [
      ('user-002', 'Alice Wang'),
      ('user-003', 'David Liu'),
      ('user-005', 'Emma Zhang'),
    ];
    final mockTexts = [
      'Just got an update from the factory.',
      'The shipment is on schedule.',
      'Can we review the latest QC report?',
      'I\'ve uploaded the revised documents.',
      'Meeting at 3 PM to discuss progress.',
      'Client feedback has been positive!',
    ];
    var index = 0;

    _simulationTimers[conversationId] = Timer.periodic(
      const Duration(seconds: 15),
      (timer) {
        if (_controllers[conversationId]?.isClosed == true) {
          timer.cancel();
          return;
        }
        final sender = mockSenders[index % mockSenders.length];
        final text = mockTexts[index % mockTexts.length];
        final message = ChatMessage(
          id: _uuid.v4(),
          roomId: conversationId,
          senderId: sender.$1,
          senderName: sender.$2,
          type: MessageType.text,
          content: text,
          createdAt: DateTime.now(),
        );
        _messageCache[conversationId]?.add(message);
        _controllers[conversationId]?.add(message);
        index++;
      },
    );
  }

  @override
  Future<void> markConversationAsRead(String senderUserId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> readGroupConversation(
      String groupId, String lastReadMessageId) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    for (final timer in _simulationTimers.values) {
      timer.cancel();
    }
    _simulationTimers.clear();
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
  @override
  Future<void> deleteMessage({
    required String messageId,
    required String conversationId,
    String? groupId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _messageCache[conversationId]?.removeWhere((m) => m.id == messageId);
  }

  @override
  Future<void> recallMessage(ImChatMessage message) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
