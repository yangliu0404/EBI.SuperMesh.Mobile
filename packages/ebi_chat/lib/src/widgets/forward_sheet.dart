import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/chat_room.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';

/// Forward target info.
class ForwardTarget {
  final String conversationKey;
  final String? groupId;
  final String type; // 'user' or 'group'
  final String displayName;

  const ForwardTarget({
    required this.conversationKey,
    this.groupId,
    required this.type,
    required this.displayName,
  });
}

/// Bottom sheet for forwarding a file/message to another user or group.
///
/// 3 tabs: 最近会话 / 联系人 / 群组
/// Reference: Web's `ForwardModal.vue`.
Future<ForwardTarget?> showForwardSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<ForwardTarget>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ForwardSheetContent(ref: ref),
  );
}

class _ForwardSheetContent extends StatefulWidget {
  final WidgetRef ref;

  const _ForwardSheetContent({required this.ref});

  @override
  State<_ForwardSheetContent> createState() => _ForwardSheetContentState();
}

class _ForwardSheetContentState extends State<_ForwardSheetContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // User search state
  List<Map<String, dynamic>> _userResults = [];
  bool _userLoading = false;
  Timer? _userSearchTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _userResults.isEmpty) {
        _doUserSearch();
      }
    });
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.toLowerCase());
    // Debounced user search when on 联系人 tab
    if (_tabController.index == 1) {
      _userSearchTimer?.cancel();
      _userSearchTimer = Timer(const Duration(milliseconds: 300), _doUserSearch);
    }
  }

  Future<void> _doUserSearch() async {
    setState(() => _userLoading = true);
    try {
      final apiClient = widget.ref.read(apiClientProvider);
      final response = await apiClient.get(
        '/api/identity/users',
        queryParameters: {
          'filter': _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          'maxResultCount': 20,
          'sorting': 'userName asc',
        },
      );
      final data = response.data;
      List<dynamic> items;
      if (data is Map<String, dynamic>) {
        // ABP wrapped response: {result: {items: [...]}} or {items: [...]}
        if (data.containsKey('result') && data['result'] is Map) {
          items = (data['result']['items'] as List?) ?? [];
        } else {
          items = (data['items'] as List?) ?? [];
        }
      } else {
        items = [];
      }
      if (mounted) {
        setState(() {
          _userResults = items.cast<Map<String, dynamic>>();
          _userLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _userLoading = false);
    }
  }

  @override
  void dispose() {
    _userSearchTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ChatRoom> get _filteredRooms {
    final rooms = widget.ref.read(chatRoomsProvider).valueOrNull ?? [];
    if (_searchQuery.isEmpty) return rooms;
    return rooms
        .where((r) => r.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '转发给...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: EbiColors.textPrimary,
              ),
            ),
          ),
          // Tab bar — 3 tabs
          TabBar(
            controller: _tabController,
            labelColor: EbiColors.primaryBlue,
            unselectedLabelColor: EbiColors.textSecondary,
            indicatorColor: EbiColors.primaryBlue,
            tabs: const [
              Tab(text: '最近会话'),
              Tab(text: '联系人'),
              Tab(text: '群组'),
            ],
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: EbiColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: EbiColors.divider),
                ),
              ),
            ),
          ),
          // List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecentList(),
                _buildUserList(),
                _buildGroupList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentList() {
    final rooms = _filteredRooms;
    if (rooms.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? '无匹配结果' : '暂无最近会话',
          style: TextStyle(color: EbiColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      key: const PageStorageKey('forward_recent'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _ConversationTile(
          key: ValueKey('recent_${room.id}'),
          name: room.name,
          isGroup: room.isGroup,
          isSelected: false,
          onTap: () {
            Navigator.of(context).pop(ForwardTarget(
              conversationKey: room.id,
              groupId: room.isGroup ? room.id.replaceFirst('group:', '') : null,
              type: room.isGroup ? 'group' : 'user',
              displayName: room.name,
            ));
          },
        );
      },
    );
  }

  Widget _buildUserList() {
    if (_userLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final users = _userResults;
    if (users.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? '无匹配用户' : '输入关键字搜索联系人',
          style: TextStyle(color: EbiColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      key: const PageStorageKey('forward_users'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final userId = (user['id'] as String?)?.toLowerCase() ?? '';
        final name = (user['name'] ?? user['userName'] ?? '') as String;
        final userName = (user['userName'] ?? '') as String;
        return _UserTile(
          key: ValueKey('user_$userId'),
          name: name,
          userName: userName,
          onTap: () {
            Navigator.of(context).pop(ForwardTarget(
              conversationKey: userId,
              type: 'user',
              displayName: name.isNotEmpty ? name : userName,
            ));
          },
        );
      },
    );
  }

  Widget _buildGroupList() {
    final rooms = _filteredRooms.where((r) => r.isGroup).toList();
    if (rooms.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? '无匹配结果' : '暂无群组',
          style: TextStyle(color: EbiColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      key: const PageStorageKey('forward_groups'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _ConversationTile(
          key: ValueKey('group_${room.id}'),
          name: room.name,
          isGroup: true,
          isSelected: false,
          onTap: () {
            Navigator.of(context).pop(ForwardTarget(
              conversationKey: room.id,
              groupId: room.id.replaceFirst('group:', ''),
              type: 'group',
              displayName: room.name,
            ));
          },
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final bool isGroup;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConversationTile({
    super.key,
    required this.name,
    required this.isGroup,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selected: isSelected,
      selectedTileColor: EbiColors.primaryBlue.withValues(alpha: 0.1),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor:
            isGroup ? Colors.blue.shade50 : Colors.grey.shade100,
        child: Icon(
          isGroup ? Icons.group : Icons.person,
          size: 18,
          color: isGroup ? Colors.blue.shade600 : Colors.grey.shade600,
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

class _UserTile extends StatelessWidget {
  final String name;
  final String userName;
  final VoidCallback onTap;

  const _UserTile({
    super.key,
    required this.name,
    required this.userName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey.shade100,
        child: Icon(Icons.person, size: 18, color: Colors.grey.shade600),
      ),
      title: Text(
        name.isNotEmpty ? name : userName,
        style: const TextStyle(fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: name.isNotEmpty
          ? Text(
              userName,
              style: TextStyle(fontSize: 12, color: EbiColors.textSecondary),
            )
          : null,
      onTap: onTap,
    );
  }
}
