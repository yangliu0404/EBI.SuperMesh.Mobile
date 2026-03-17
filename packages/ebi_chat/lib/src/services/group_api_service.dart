import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/im_group_models.dart';

/// API service for group management.
///
/// Corresponds to Web's `useGroupsApi.ts` and `useUserGroupsApi.ts`.
class GroupApiService {
  final ApiClient _api;

  GroupApiService(this._api);

  // ── Group CRUD ──────────────────────────────────────────────────────────

  /// Get group detail info.
  Future<ImGroup> getGroup(String groupId) async {
    final res = await _api.get('/api/im/groups/$groupId');
    final data = _unwrap(res.data);
    return ImGroup.fromJson(data);
  }

  /// Update group info (name, notice, description, avatarUrl).
  Future<ImGroup> updateGroup(String groupId, Map<String, dynamic> input) async {
    final res = await _api.put('/api/im/groups/$groupId', data: input);
    final data = _unwrap(res.data);
    return ImGroup.fromJson(data);
  }

  /// Create a new group.
  Future<ImGroup> createGroup({
    required String name,
    List<String>? userIds,
    String? description,
  }) async {
    final res = await _api.post('/api/im/groups', data: {
      'name': name,
      if (description != null) 'description': description,
      if (userIds != null) 'userIds': userIds,
    });
    final data = _unwrap(res.data);
    return ImGroup.fromJson(data);
  }

  /// Dissolve (delete) a group.
  Future<void> dissolveGroup(String groupId) async {
    await _api.delete('/api/im/groups/$groupId');
  }

  // ── Group Members ───────────────────────────────────────────────────────

  /// Get group member list.
  Future<List<ImGroupMember>> getGroupMembers(
    String groupId, {
    int skipCount = 0,
    int maxResultCount = 200,
  }) async {
    final res = await _api.get('/api/im/user-groups', queryParameters: {
      'groupId': groupId,
      'skipCount': skipCount,
      'maxResultCount': maxResultCount,
    });
    final data = _unwrap(res.data);
    final items = data['items'] as List? ?? [];
    return items.map((e) => ImGroupMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Invite users to a group.
  Future<void> inviteUsers(String groupId, List<String> userIds) async {
    await _api.post('/api/im/user-groups/invite', data: {
      'groupId': groupId,
      'userIds': userIds,
    });
  }

  /// Remove a user from a group.
  Future<void> removeUser(String groupId, String userId) async {
    await _api.put('/api/im/user-groups/remove', data: {
      'groupId': groupId,
      'userId': userId,
    });
  }

  /// Leave a group.
  Future<void> leaveGroup(String groupId) async {
    await _api.post('/api/im/user-groups/leave', data: {
      'groupId': groupId,
    });
  }

  /// Set/unset admin.
  Future<void> setAdmin(String groupId, String userId, bool isAdmin) async {
    await _api.put('/api/im/user-groups/set-admin', data: {
      'groupId': groupId,
      'userId': userId,
      'isAdmin': isAdmin,
    });
  }

  /// Set group nickname for the current user.
  Future<void> setNickName(String groupId, String nickName) async {
    await _api.put('/api/im/user-groups/nickname', data: {
      'groupId': groupId,
      'nickName': nickName,
    });
  }

  /// Transfer group ownership.
  Future<void> transferOwner(String groupId, String newAdminUserId) async {
    await _api.put('/api/im/user-groups/transfer-owner', data: {
      'groupId': groupId,
      'newAdminUserId': newAdminUserId,
    });
  }

  // ── User Card ───────────────────────────────────────────────────────────

  /// Get a user's profile card.
  Future<ImUserCard> getUserCard(String userId) async {
    final res = await _api.get('/api/im/chat/user-card/$userId');
    final data = _unwrap(res.data);
    return ImUserCard.fromJson(data);
  }

  // ── Message Search ──────────────────────────────────────────────────────

  /// Search messages globally within a conversation.
  Future<Map<String, dynamic>> searchMessages({
    String? filter,
    String? receiveUserId,
    String? groupId,
    int? messageType,
    int skipCount = 0,
    int maxResultCount = 20,
  }) async {
    final res = await _api.get('/api/im/chat/search', queryParameters: {
      if (filter != null) 'filter': filter,
      if (receiveUserId != null) 'receiveUserId': receiveUserId,
      if (groupId != null) 'groupId': groupId,
      if (messageType != null) 'messageType': messageType,
      'skipCount': skipCount,
      'maxResultCount': maxResultCount,
    });
    return _unwrap(res.data);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Unwrap ABP WrapResult `{ code, result }` if present.
  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map<String, dynamic>) {
      // ABP WrapResult format
      if (data.containsKey('result') && data['result'] is Map<String, dynamic>) {
        return data['result'] as Map<String, dynamic>;
      }
      return data;
    }
    return {};
  }
}
