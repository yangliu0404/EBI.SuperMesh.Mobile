import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/oss_url_cache_table.dart';

part 'oss_cache_dao.g.dart';

@DriftAccessor(tables: [OssUrlCacheEntries])
class OssCacheDao extends DatabaseAccessor<AppDatabase>
    with _$OssCacheDaoMixin {
  OssCacheDao(super.db);

  /// Get a valid (non-expired) signed URL for the given OSS path.
  Future<String?> getValidUrl(String ossPath) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = await (select(ossUrlCacheEntries)
          ..where((t) => t.ossPath.equals(ossPath))
          ..where((t) => t.expiresAt.isBiggerThanValue(now)))
        .getSingleOrNull();
    return entry?.signedUrl;
  }

  /// Save a signed URL with TTL.
  Future<void> put(String ossPath, String signedUrl,
      {Duration ttl = const Duration(minutes: 10)}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(ossUrlCacheEntries).insertOnConflictUpdate(
      OssUrlCacheEntriesCompanion.insert(
        ossPath: ossPath,
        signedUrl: signedUrl,
        createdAt: now,
        expiresAt: now + ttl.inMilliseconds,
      ),
    );
  }

  /// Delete all expired entries.
  Future<int> deleteExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (delete(ossUrlCacheEntries)
          ..where((t) => t.expiresAt.isSmallerOrEqualValue(now)))
        .go();
  }

  /// Evict a single entry.
  Future<void> evict(String ossPath) async {
    await (delete(ossUrlCacheEntries)
          ..where((t) => t.ossPath.equals(ossPath)))
        .go();
  }

  /// Clear all cached URLs.
  Future<void> clearAll() => delete(ossUrlCacheEntries).go();
}
