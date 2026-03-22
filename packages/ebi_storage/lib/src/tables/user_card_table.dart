import 'package:drift/drift.dart';

/// User cards table — mirrors backend ImUserCard.
class UserCards extends Table {
  TextColumn get userId => text()();
  TextColumn get userName => text()();
  TextColumn get nickName => text().nullable()();
  TextColumn get name => text().nullable()();
  TextColumn get surname => text().nullable()();
  TextColumn get nativeName => text().nullable()();
  TextColumn get firstName => text().nullable()();
  TextColumn get lastName => text().nullable()();
  TextColumn get phoneNumber => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get company => text().nullable()();
  TextColumn get department => text().nullable()();
  TextColumn get position => text().nullable()();
  TextColumn get employeeNumber => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  IntColumn get sex => integer().withDefault(const Constant(0))();
  IntColumn get age => integer().withDefault(const Constant(0))();
  TextColumn get birthday => text().nullable()();
  TextColumn get sign => text().nullable()();
  TextColumn get description => text().nullable()();
  BoolColumn get online => boolean().withDefault(const Constant(false))();
  TextColumn get lastOnlineTime => text().nullable()();

  // ── Local ──
  IntColumn get localUpdatedAt => integer()();

  @override
  Set<Column> get primaryKey => {userId};
}
