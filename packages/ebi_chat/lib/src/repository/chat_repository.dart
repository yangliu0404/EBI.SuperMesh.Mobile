import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/chat_room.dart';
import 'package:ebi_chat/src/models/im_models.dart';

/// Abstract chat repository — swap implementations without touching UI.
abstract class ChatRepository {
  /// Fetch the conversation list (last messages per conversation).
  Future<List<ChatRoom>> getConversations({int? maxResultCount});

  /// Fetch 1-to-1 message history with a specific user.
  Future<List<ChatMessage>> getUserMessages(
    String receiveUserId, {
    int skipCount = 0,
    int maxResultCount = 50,
  });

  /// Fetch group message history.
  Future<List<ChatMessage>> getGroupMessages(
    String groupId, {
    int skipCount = 0,
    int maxResultCount = 50,
  });

  /// Send a message via SignalR. Returns the server-assigned messageId.
  Future<String> sendMessage(ImChatMessage message);

  /// Mark a 1-to-1 conversation as read.
  Future<void> markConversationAsRead(String senderUserId);

  /// Mark a group conversation as read up to a specific message.
  Future<void> readGroupConversation(String groupId, String lastReadMessageId);

  /// Stream of incoming messages for a conversation.
  Stream<ChatMessage> messageStream(String conversationId);

  /// Delete a message (only for current user, server-side soft delete).
  Future<void> deleteMessage({
    required String messageId,
    required String conversationId,
    String? groupId,
  });

  /// Recall a message (within time limit, removes for everyone).
  /// Backend expects the full message object via SignalR.
  Future<void> recallMessage(ImChatMessage message);

  /// Dispose resources (e.g. StreamControllers).
  void dispose();
}
