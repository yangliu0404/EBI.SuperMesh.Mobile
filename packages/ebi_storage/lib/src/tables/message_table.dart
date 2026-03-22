import 'package:drift/drift.dart';

/// Messages table — mirrors backend ImChatMessage exactly.
class Messages extends Table {
  // ── Backend fields (mirror ImChatMessage) ──
  TextColumn get messageId => text()();
  TextColumn get tenantId => text().nullable()();
  TextColumn get groupId => text().withDefault(const Constant(''))();
  TextColumn get formUserId => text()();
  TextColumn get formUserName => text()();
  TextColumn get toUserId => text().nullable()();
  TextColumn get content => text()();
  TextColumn get sendTime => text()();           // ISO8601
  BoolColumn get isAnonymous => boolean().withDefault(const Constant(false))();
  IntColumn get messageType => integer().withDefault(const Constant(0))();
  IntColumn get source => integer().withDefault(const Constant(0))();
  IntColumn get state => integer().nullable()();
  TextColumn get extraProperties => text().nullable()(); // JSON string

  // ── Local extension fields ──
  TextColumn get roomId => text()();             // computed: userId or group:{groupId}
  IntColumn get syncState => integer().withDefault(const Constant(0))();
      // 0: synced, 1: pendingSend, 2: sendFailed
  IntColumn get localCreatedAt => integer()();   // timestamp ms

  @override
  Set<Column> get primaryKey => {messageId};
}
