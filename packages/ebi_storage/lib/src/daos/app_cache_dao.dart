import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/app_cache_table.dart';

part 'app_cache_dao.g.dart';

@DriftAccessor(tables: [AppCacheEntries])
class AppCacheDao extends DatabaseAccessor<AppDatabase>
    with _$AppCacheDaoMixin {
  AppCacheDao(super.db);

  /// Get cached value by key. Returns null if not found.
  Future<String?> get(String key) async {
    final entry = await (select(appCacheEntries)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return entry?.value;
  }

  /// Get cached entry with version info.
  Future<AppCacheEntry?> getEntry(String key) async {
    return (select(appCacheEntries)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
  }

  /// Get the version of a cached entry (for incremental update checks).
  Future<String?> getVersion(String key) async {
    final entry = await (select(appCacheEntries)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return entry?.version;
  }

  /// Save or update a cache entry.
  Future<void> put(String key, String value, {String? version}) async {
    await into(appCacheEntries).insertOnConflictUpdate(
      AppCacheEntriesCompanion.insert(
        key: key,
        value: value,
        version: Value(version),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Delete a cache entry.
  Future<void> remove(String key) async {
    await (delete(appCacheEntries)..where((t) => t.key.equals(key))).go();
  }

  /// Clear all cache entries.
  Future<void> clearAll() => delete(appCacheEntries).go();
}
