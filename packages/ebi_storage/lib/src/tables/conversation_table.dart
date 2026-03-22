import 'package:drift/drift.dart';

/// Conversations table — mirrors backend ImLastChatMessage.
class Conversations extends Table {
  // ── Backend fields (mirror ImLastChatMessage) ──
  TextColumn get id => text()();                 // userId (direct) or group:{groupId}
  TextColumn get avatarUrl => text().withDefault(const Constant(''))();
  TextColumn get object => text().withDefault(const Constant(''))(); // display name
  TextColumn get tenantId => text().nullable()();
  TextColumn get groupId => text().withDefault(const Constant(''))();
  TextColumn get messageId => text().withDefault(const Constant(''))();
  TextColumn get formUserId => text().withDefault(const Constant(''))();
  TextColumn get formUserName => text().withDefault(const Constant(''))();
  TextColumn get toUserId => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get sendTime => text().withDefault(const Constant(''))();
  BoolColumn get isAnonymous => boolean().withDefault(const Constant(false))();
  IntColumn get messageType => integer().withDefault(const Constant(0))();
  IntColumn get source => integer().withDefault(const Constant(0))();
  BoolColumn get online => boolean().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  TextColumn get extraProperties => text().nullable()(); // JSON string

  // ── Local extension fields ──
  IntColumn get type => integer().withDefault(const Constant(0))(); // 0:direct, 1:group
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  IntColumn get localUpdatedAt => integer()();   // timestamp ms

  @override
  Set<Column> get primaryKey => {id};
}
