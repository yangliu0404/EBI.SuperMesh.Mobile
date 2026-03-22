import 'package:drift/drift.dart';

/// Persisted OSS signed URL cache.
/// Replaces the in-memory LRU cache in OssUrlService.
class OssUrlCacheEntries extends Table {
  TextColumn get ossPath => text()();
  TextColumn get signedUrl => text()();
  IntColumn get createdAt => integer()();  // timestamp ms
  IntColumn get expiresAt => integer()();  // timestamp ms

  @override
  Set<Column> get primaryKey => {ossPath};
}
