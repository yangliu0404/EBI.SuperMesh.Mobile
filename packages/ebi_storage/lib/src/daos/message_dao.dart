import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/message_table.dart';

part 'message_dao.g.dart';

@DriftAccessor(tables: [Messages])
class MessageDao extends DatabaseAccessor<AppDatabase>
    with _$MessageDaoMixin {
  MessageDao(super.db);

  /// Upsert a single message (server data overwrites local).
  Future<void> upsertMessage(MessagesCompanion msg) async {
    await into(messages).insertOnConflictUpdate(msg);
  }

  /// Batch upsert messages within a transaction.
  Future<void> upsertMessages(List<MessagesCompanion> msgs) async {
    await batch((b) {
      for (final msg in msgs) {
        b.insert(messages, msg, onConflict: DoUpdate((_) => msg));
      }
    });
  }

  /// Get messages for a room, paged by sendTime descending.
  Future<List<Message>> getByRoom(
    String roomId, {
    int limit = 50,
    String? beforeSendTime,
  }) async {
    final query = select(messages)
      ..where((t) => t.roomId.equals(roomId))
      ..orderBy([(t) => OrderingTerm.desc(t.sendTime)])
      ..limit(limit);

    if (beforeSendTime != null) {
      query.where((t) => t.sendTime.isSmallerThanValue(beforeSendTime));
    }

    return query.get();
  }

  /// Get messages by room and type (e.g., images + videos).
  Future<List<Message>> getByRoomAndType(
    String roomId,
    List<int> messageTypes, {
    int limit = 50,
  }) async {
    return (select(messages)
          ..where((t) =>
              t.roomId.equals(roomId) & t.messageType.isIn(messageTypes))
          ..orderBy([(t) => OrderingTerm.desc(t.sendTime)])
          ..limit(limit))
        .get();
  }

  /// Get messages newer than a given messageId (for incremental sync).
  Future<List<Message>> getNewerThan(String roomId, String sendTime) async {
    return (select(messages)
          ..where((t) =>
              t.roomId.equals(roomId) &
              t.sendTime.isBiggerThanValue(sendTime))
          ..orderBy([(t) => OrderingTerm.asc(t.sendTime)]))
        .get();
  }

  /// Get pending-send messages (offline queue).
  /// Returns messages with syncState = 1 (pendingSend) or 2 (sendFailed).
  Future<List<Message>> getPendingSend() async {
    return (select(messages)
          ..where((t) => t.syncState.isIn([1, 2]))
          ..orderBy([(t) => OrderingTerm.asc(t.sendTime)]))
        .get();
  }

  /// Update sync state of a message.
  Future<void> updateSyncState(String messageId, int newSyncState) async {
    await (update(messages)..where((t) => t.messageId.equals(messageId)))
        .write(MessagesCompanion(syncState: Value(newSyncState)));
  }

  /// Update message state (e.g., recall).
  Future<void> updateState(String messageId, int newState) async {
    await (update(messages)..where((t) => t.messageId.equals(messageId)))
        .write(MessagesCompanion(state: Value(newState)));
  }

  /// Count messages in a room.
  Future<int> countByRoom(String roomId) async {
    final count = messages.messageId.count();
    final query = selectOnly(messages)
      ..addColumns([count])
      ..where(messages.roomId.equals(roomId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Simple text search in message content and sender name.
  Future<List<Message>> searchContent(String query,
      {String? roomId, int limit = 50}) async {
    final pattern = '%$query%';
    final q = select(messages)
      ..where((t) {
        final contentMatch =
            t.content.like(pattern) | t.formUserName.like(pattern);
        if (roomId != null) {
          return contentMatch & t.roomId.equals(roomId);
        }
        return contentMatch;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.sendTime)])
      ..limit(limit);
    return q.get();
  }
}
