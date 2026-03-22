import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/draft_table.dart';

part 'draft_dao.g.dart';

@DriftAccessor(tables: [Drafts])
class DraftDao extends DatabaseAccessor<AppDatabase> with _$DraftDaoMixin {
  DraftDao(super.db);

  /// Get draft text for a conversation, or null if none exists.
  Future<String?> getDraft(String roomId) async {
    final entry = await (select(drafts)
          ..where((t) => t.roomId.equals(roomId)))
        .getSingleOrNull();
    return entry?.content;
  }

  /// Save or update a draft. If content is empty/whitespace, deletes the draft.
  Future<void> saveDraft(String roomId, String content) async {
    if (content.trim().isEmpty) {
      await (delete(drafts)..where((t) => t.roomId.equals(roomId))).go();
      return;
    }
    await into(drafts).insertOnConflictUpdate(
      DraftsCompanion.insert(
        roomId: roomId,
        content: content,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Delete draft for a conversation (e.g., after sending).
  Future<void> deleteDraft(String roomId) async {
    await (delete(drafts)..where((t) => t.roomId.equals(roomId))).go();
  }

  /// Clear all drafts.
  Future<void> clearAll() => delete(drafts).go();
}
