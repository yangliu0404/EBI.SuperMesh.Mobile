import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/group_table.dart';
import '../tables/user_card_table.dart';

part 'contact_dao.g.dart';

@DriftAccessor(tables: [Groups, UserCards])
class ContactDao extends DatabaseAccessor<AppDatabase>
    with _$ContactDaoMixin {
  ContactDao(super.db);

  // ── Groups ──

  Future<void> upsertGroup(GroupsCompanion group) async {
    await into(groups).insertOnConflictUpdate(group);
  }

  Future<Group?> getGroupById(String id) async {
    return (select(groups)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<Group>> getAllGroups() async {
    return (select(groups)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<void> deleteGroup(String id) async {
    await (delete(groups)..where((t) => t.id.equals(id))).go();
  }

  // ── User Cards ──

  Future<void> upsertUserCard(UserCardsCompanion card) async {
    await into(userCards).insertOnConflictUpdate(card);
  }

  Future<void> upsertUserCards(List<UserCardsCompanion> cards) async {
    await batch((b) {
      for (final card in cards) {
        b.insert(userCards, card, onConflict: DoUpdate((_) => card));
      }
    });
  }

  Future<UserCard?> getUserById(String userId) async {
    return (select(userCards)..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<List<UserCard>> searchUsers(String query, {int limit = 20}) async {
    final pattern = '%$query%';
    return (select(userCards)
          ..where((t) =>
              t.userName.like(pattern) |
              t.nickName.like(pattern) |
              t.name.like(pattern) |
              t.email.like(pattern))
          ..limit(limit))
        .get();
  }

  Future<void> clearAllUsers() => delete(userCards).go();
  Future<void> clearAllGroups() => delete(groups).go();
}
