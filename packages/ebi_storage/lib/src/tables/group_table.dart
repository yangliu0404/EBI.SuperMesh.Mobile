import 'package:drift/drift.dart';

/// Groups table — mirrors backend ImGroup.
class Groups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get notice => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get alias => text().nullable()();
  TextColumn get adminUserId => text().nullable()();
  TextColumn get tag => text().nullable()();
  IntColumn get maxUserCount => integer().withDefault(const Constant(200))();
  BoolColumn get allowAnonymous => boolean().withDefault(const Constant(false))();
  BoolColumn get allowSendMessage => boolean().withDefault(const Constant(true))();
  IntColumn get groupAcceptJoinType => integer().withDefault(const Constant(0))();
  TextColumn get creationTime => text().nullable()(); // ISO8601

  // ── Local ──
  IntColumn get localUpdatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
