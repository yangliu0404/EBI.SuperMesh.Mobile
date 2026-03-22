import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/conversation_table.dart';

part 'conversation_dao.g.dart';

@DriftAccessor(tables: [Conversations])
class ConversationDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationDaoMixin {
  ConversationDao(super.db);

  /// Upsert a single conversation (server data overwrites local).
  Future<void> upsertConversation(ConversationsCompanion conv) async {
    await into(conversations).insertOnConflictUpdate(conv);
  }

  /// Batch upsert conversations.
  Future<void> upsertConversations(List<ConversationsCompanion> convs) async {
    await batch((b) {
      for (final conv in convs) {
        b.insert(conversations, conv, onConflict: DoUpdate((_) => conv));
      }
    });
  }

  /// Get all conversations sorted: pinned first, then by sendTime desc.
  Future<List<Conversation>> getAllSorted() async {
    return (select(conversations)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.sendTime),
          ]))
        .get();
  }

  /// Watch all conversations (reactive stream for UI).
  Stream<List<Conversation>> watchAllSorted() {
    return (select(conversations)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.sendTime),
          ]))
        .watch();
  }

  /// Get a single conversation by ID.
  Future<Conversation?> getById(String id) async {
    return (select(conversations)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Update unread count.
  Future<void> updateUnreadCount(String id, int count) async {
    await (update(conversations)..where((t) => t.id.equals(id))).write(
      ConversationsCompanion(
        unreadCount: Value(count),
        localUpdatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Update conversation preview when a new message arrives.
  Future<void> updateOnNewMessage(
    String id, {
    required String messageId,
    required String content,
    required String sendTime,
    required int messageType,
    required String formUserName,
    int unreadIncrement = 1,
  }) async {
    final existing = await getById(id);
    final newUnread = (existing?.unreadCount ?? 0) + unreadIncrement;

    await (update(conversations)..where((t) => t.id.equals(id))).write(
      ConversationsCompanion(
        messageId: Value(messageId),
        content: Value(content),
        sendTime: Value(sendTime),
        messageType: Value(messageType),
        formUserName: Value(formUserName),
        unreadCount: Value(newUnread),
        localUpdatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Set pinned status.
  Future<void> setPinned(String id, bool pinned) async {
    await (update(conversations)..where((t) => t.id.equals(id))).write(
      ConversationsCompanion(
        isPinned: Value(pinned),
        localUpdatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Set muted status.
  Future<void> setMuted(String id, bool muted) async {
    await (update(conversations)..where((t) => t.id.equals(id))).write(
      ConversationsCompanion(
        isMuted: Value(muted),
        localUpdatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Delete a conversation.
  Future<void> removeById(String id) async {
    await (delete(conversations)..where((t) => t.id.equals(id))).go();
  }

  /// Clear all conversations.
  Future<void> clearAll() => delete(conversations).go();
}
