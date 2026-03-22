import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database.dart';
import '../daos/oss_cache_dao.dart';
import '../daos/app_cache_dao.dart';
import '../daos/message_dao.dart';
import '../daos/conversation_dao.dart';
import '../daos/contact_dao.dart';
import '../daos/draft_dao.dart';

/// The main database provider.
/// Must be overridden in ProviderScope with the actual database instance
/// created via `AppDatabase.create(userId: ...)`.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider must be overridden with an actual AppDatabase instance. '
    'Use ProviderScope overrides in main.dart after login.',
  );
});

/// DAO providers — derived from the database.
final ossCacheDaoProvider = Provider<OssCacheDao>((ref) {
  return ref.watch(databaseProvider).ossCacheDao;
});

final appCacheDaoProvider = Provider<AppCacheDao>((ref) {
  return ref.watch(databaseProvider).appCacheDao;
});

final messageDaoProvider = Provider<MessageDao>((ref) {
  return ref.watch(databaseProvider).messageDao;
});

final conversationDaoProvider = Provider<ConversationDao>((ref) {
  return ref.watch(databaseProvider).conversationDao;
});

final contactDaoProvider = Provider<ContactDao>((ref) {
  return ref.watch(databaseProvider).contactDao;
});

final draftDaoProvider = Provider<DraftDao>((ref) {
  return ref.watch(databaseProvider).draftDao;
});

/// Cache statistics for the settings page.
class CacheStats {
  final int databaseSizeBytes;
  final int messageCount;
  final int conversationCount;
  final int ossUrlCacheCount;

  const CacheStats({
    this.databaseSizeBytes = 0,
    this.messageCount = 0,
    this.conversationCount = 0,
    this.ossUrlCacheCount = 0,
  });

  String get formattedSize {
    if (databaseSizeBytes < 1024) return '$databaseSizeBytes B';
    if (databaseSizeBytes < 1024 * 1024) {
      return '${(databaseSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(databaseSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Provider to get cache statistics.
final cacheStatsProvider = FutureProvider<CacheStats>((ref) async {
  try {
    final db = ref.read(databaseProvider);
    final dbSize = await db.getDatabaseSize();

    // Count records
    final msgCount = await db
        .customSelect('SELECT COUNT(*) as c FROM messages')
        .getSingle();
    final convCount = await db
        .customSelect('SELECT COUNT(*) as c FROM conversations')
        .getSingle();
    final ossCount = await db
        .customSelect('SELECT COUNT(*) as c FROM oss_url_cache_entries')
        .getSingle();

    return CacheStats(
      databaseSizeBytes: dbSize,
      messageCount: msgCount.read<int>('c'),
      conversationCount: convCount.read<int>('c'),
      ossUrlCacheCount: ossCount.read<int>('c'),
    );
  } catch (_) {
    return const CacheStats();
  }
});
