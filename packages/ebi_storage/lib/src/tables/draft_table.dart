import 'package:drift/drift.dart';

/// Drafts table for saving unsent message text.
class Drafts extends Table {
  TextColumn get roomId => text()();      // conversation ID
  TextColumn get content => text()();     // draft text
  IntColumn get updatedAt => integer()(); // timestamp ms

  @override
  Set<Column> get primaryKey => {roomId};
}
