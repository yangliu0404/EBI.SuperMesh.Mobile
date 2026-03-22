import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/oss_url_cache_table.dart';
import 'tables/app_cache_table.dart';
import 'tables/message_table.dart';
import 'tables/conversation_table.dart';
import 'tables/group_table.dart';
import 'tables/user_card_table.dart';
import 'tables/draft_table.dart';
import 'daos/oss_cache_dao.dart';
import 'daos/app_cache_dao.dart';
import 'daos/message_dao.dart';
import 'daos/conversation_dao.dart';
import 'daos/contact_dao.dart';
import 'daos/draft_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    OssUrlCacheEntries,
    AppCacheEntries,
    Messages,
    Conversations,
    Groups,
    UserCards,
    Drafts,
  ],
  daos: [
    OssCacheDao,
    AppCacheDao,
    MessageDao,
    ConversationDao,
    ContactDao,
    DraftDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(super.e);

  /// Create a database instance for the given user.
  /// Each user gets their own DB file to isolate data.
  static Future<AppDatabase> create({String? userId}) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final name = userId != null ? 'supermesh_$userId.db' : 'supermesh.db';
    final file = File(p.join(dbFolder.path, name));
    return AppDatabase._internal(NativeDatabase.createInBackground(file));
  }

  /// In-memory database for testing.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: Add drafts table.
            await m.createTable(drafts);
          }
        },
      );

  /// Delete all data (used on logout / clear cache).
  Future<void> clearAllData() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }

  /// Get the database file size in bytes.
  Future<int> getDatabaseSize() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final files = dbFolder.listSync().where((f) => f.path.endsWith('.db'));
    int total = 0;
    for (final f in files) {
      if (f is File) {
        total += await f.length();
      }
    }
    return total;
  }

  /// Clean up only non-essential caches (OSS URLs, app cache).
  /// Messages and conversations are NEVER auto-deleted — they belong to the user.
  Future<void> cleanupCaches() async {
    await ossCacheDao.deleteExpired();
  }
}
