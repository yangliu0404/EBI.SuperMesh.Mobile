import 'package:drift/drift.dart';

/// General-purpose KV cache table.
/// Used for localization translations, ABP config, language list, etc.
class AppCacheEntries extends Table {
  TextColumn get key => text()();       // e.g. 'l10n:zh-Hans', 'abp:config'
  TextColumn get value => text()();     // JSON string
  TextColumn get version => text().nullable()(); // version/hash for incremental check
  IntColumn get updatedAt => integer()();        // timestamp ms

  @override
  Set<Column> get primaryKey => {key};
}
