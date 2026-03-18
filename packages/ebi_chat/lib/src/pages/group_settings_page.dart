import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/models/im_group_models.dart';
import 'package:ebi_chat/src/services/group_api_service.dart';
import 'package:ebi_chat/src/pages/user_profile_page.dart';
import 'package:ebi_chat/src/pages/user_selection_page.dart';
import 'package:ebi_chat/src/pages/message_search_page.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';

/// Provider for the GroupApiService.
final groupApiServiceProvider = Provider<GroupApiService>((ref) {
  final api = ref.read(apiClientProvider);
  return GroupApiService(api);
});

/// Group settings page — view and edit group info, members, notice.
///
/// Corresponds to Web's `GroupSettingsPanel.vue`.
class GroupSettingsPage extends ConsumerStatefulWidget {
  final String groupId;
  final String? groupName;

  const GroupSettingsPage({
    super.key,
    required this.groupId,
    this.groupName,
  });

  @override
  ConsumerState<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends ConsumerState<GroupSettingsPage> {
  ImGroup? _groupInfo;
  List<ImGroupMember> _members = [];
  bool _loading = true;
  String _currentUserId = '';
  final Map<String, String?> _memberAvatars = {};
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = ref.read(authProvider).user?.id.toLowerCase() ?? '';
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(groupApiServiceProvider);
      final results = await Future.wait([
        api.getGroup(widget.groupId),
        api.getGroupMembers(widget.groupId),
      ]);
      if (!mounted) return;
      // Initialize _isPinned and _isMuted from ChatRoomsNotifier
      // Group IDs in ChatRoom are prefixed with "group:"
      final conversationKey = 'group:${widget.groupId}';
      final rooms = ref.read(chatRoomsProvider).valueOrNull;
      if (rooms != null) {
        final room = rooms.where((r) => r.id == conversationKey).firstOrNull;
        if (room != null) {
          _isPinned = room.isPinned;
          _isMuted = room.isMuted;
        }
      }

      setState(() {
        _groupInfo = results[0] as ImGroup;
        _members = results[1] as List<ImGroupMember>;
        _loading = false;
      });
      _fetchAvatars();
    } catch (e) {
      if (!mounted) return;
      AppLogger.error('[GroupSettings] Failed to load', e);
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchAvatars() async {
    final api = ref.read(groupApiServiceProvider);
    final gridMembers = _members.take(9).toList();
    for (final m in gridMembers) {
      if (!_memberAvatars.containsKey(m.userId)) {
        try {
          final card = await api.getUserCard(m.userId);
          if (mounted) {
            setState(() {
              _memberAvatars[m.userId] = card.avatarUrl;
            });
          }
        } catch (_) {
          // ignore error for a single member avatar fetch
        }
      }
    }
  }

  bool get _isOwner =>
      _groupInfo?.adminUserId?.toLowerCase() == _currentUserId;

  bool get _isAdmin {
    final me = _members.where(
      (m) => m.userId.toLowerCase() == _currentUserId,
    );
    if (me.isEmpty) return false;
    return me.first.isAdmin || me.first.isSuperAdmin;
  }

  String get _currentUserName {
    final me = _members.where(
      (m) => m.userId.toLowerCase() == _currentUserId,
    );
    if (me.isEmpty) return '我';
    return me.first.displayName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '群设置',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFFF2F2F6),
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(_didChange),
        ),
      ),
      backgroundColor: const Color(0xFFF2F2F6),
      body: WillPopScope(
        onWillPop: () async {
          Navigator.of(context).pop(_didChange);
          return false;
        },
        child: _loading
            ? const EbiLoading(message: '加载中...')
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                children: [
                  _buildTopHeader(),
                  _buildMemberSection(),
                  _buildSearchAndToolsSection(),
                  
                  // Hint label
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 12, bottom: 24),
                    child: const Text('该群已开启 “新成员入群可查看最近 100 条聊天记录”', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 8),
                    child: const Text('群聊信息', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                  ),
                  
                  // Group Info Card
                  _buildGroupInfoSection(),
                  
                  // Label "个性化设置，仅对自己生效"
                  const Padding(
                    padding: EdgeInsets.only(left: 20, top: 12, bottom: 8),
                    child: Text('个性化设置，仅对自己生效', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                  ),
                  _buildPersonalizationSection(),
                  
                  // Label "管理"
                  const Padding(
                    padding: EdgeInsets.only(left: 20, top: 12, bottom: 8),
                    child: Text('管理', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                  ),
                  _buildManagementSection(),
                  
                  // Label "其他功能"
                  const Padding(
                    padding: EdgeInsets.only(left: 20, top: 12, bottom: 8),
                    child: Text('其他功能', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                  ),
                  _buildOtherFeaturesSection(),

                  const SizedBox(height: 20),
                  _buildActionsSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      ),
    );
  }

  // Helper for white rounded cards
  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Top Header Section ────────────────────────────────────────────────
  
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Group Avatar (Squircle)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF0052D9),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            // Simple placeholder for grid avatar
            child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 14),
          // Info Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _groupInfo?.name ?? widget.groupName ?? '群聊',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111111)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 20, color: Color(0xFF999999)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        '归属于 北京友宝...', // Hardcoded for demo matching
                        style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F4FD),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('内部群', style: TextStyle(fontSize: 10, color: Color(0xFF0052D9))),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // QR Code Button
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE5E5EA),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.qr_code, size: 18, color: Color(0xFF333333)),
          ),
        ],
      ),
    );
  }

  // ── Members Section ───────────────────────────────────────────────────

  Widget _buildMemberSection() {
    // Show max 9 members + 1 "add" tile.
    final gridMembers = _members.take(9).toList();
    final canAdd = _isOwner || _isAdmin;

    return _buildCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / 5;
            return Wrap(
              alignment: WrapAlignment.start,
              spacing: 0,
              runSpacing: 20,
              children: [
                ...gridMembers.map((m) => _buildMemberAvatar(m, itemWidth)),
                if (canAdd) _buildAddMemberButton(itemWidth),
              ],
            );
          }),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _showAllMembers,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '查看全部群成员 (${_members.length}/1000)',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: Color(0xFF999999)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(ImGroupMember member, double width) {
    final avatarUrl = _memberAvatars[member.userId] ?? member.avatarUrl;
    
    return GestureDetector(
      onTap: () => _openUserProfile(member.userId),
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4FD),
                    borderRadius: BorderRadius.circular(14), // Squircle
                    image: avatarUrl != null && avatarUrl.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Text(
                          member.displayName.isNotEmpty ? member.displayName.characters.first : '?',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0052D9),
                          ),
                        )
                      : null,
                ),
                if (member.isAdmin || member.isSuperAdmin)
                  Positioned(
                    bottom: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ],
                      ),
                      child: Text(
                        member.isSuperAdmin ? '群主' : '群管理员',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              member.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMemberButton(double width) {
    return GestureDetector(
      onTap: _inviteMembers,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add,
                color: Color(0xFF999999),
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '添加',
              style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search & Tools Section ────────────────────────────────────────────

  Widget _buildSearchAndToolsSection() {
    return _buildCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: [
          // Search bar
          GestureDetector(
            onTap: () => _searchHistory(0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20), // More rounded like screenshot
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, size: 18, color: Color(0xFF999999)),
                  SizedBox(width: 8),
                  Text(
                    '搜索',
                    style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Category icons Wrap
          LayoutBuilder(builder: (context, constraints) {
            // Calculate width for 4 items per row for more breathing room for text
            final itemWidth = constraints.maxWidth / 4;
            return Wrap(
              spacing: 0,
              runSpacing: 20,
              children: [
                _categoryIcon(Icons.chat_bubble_outline, '聊天记录', width: itemWidth, onTap: () => _searchHistory(0)),
                _categoryIcon(Icons.image_outlined, '图片及视频', width: itemWidth, onTap: () => _searchHistory(1)),
                _categoryIcon(Icons.folder_outlined, '文件', width: itemWidth, onTap: () => _searchHistory(2)),
                _categoryIcon(Icons.link, '链接', width: itemWidth, onTap: () => _searchHistory(3)),
                
                // ERP & Enterprise integrations
                _categoryIcon(Icons.assignment_outlined, '相关项目', width: itemWidth, onTap: () => _showComingSoon('相关项目')),
                _categoryIcon(Icons.task_alt, '相关任务', width: itemWidth, onTap: () => _showComingSoon('相关任务')),
                _categoryIcon(Icons.fact_check_outlined, '相关审批', width: itemWidth, onTap: () => _showComingSoon('相关审批')),
                _categoryIcon(Icons.receipt_long_outlined, '往来单据', width: itemWidth, onTap: () => _showComingSoon('往来单据')),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _categoryIcon(IconData icon, String label, {required double width, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: const Color(0xFF333333)),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
          ],
        ),
      ),
    );
  }

  // ── Group Info Section ─────────────────────────────────────────────────

  Widget _buildGroupInfoSection() {
    return _buildCard(
      child: Column(
        children: [
          _buildInfoRow(
            '群名称',
            _groupInfo?.name ?? widget.groupName ?? '无名字',
            canEdit: _isOwner || _isAdmin,
            onTap: () => _editField('name', _groupInfo?.name ?? ''),
          ),
          const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          _buildInfoRow(
            '群公告',
            _groupInfo?.notice?.isNotEmpty == true ? _groupInfo!.notice! : '无',
            canEdit: _isOwner || _isAdmin,
            onTap: () => _editField('notice', _groupInfo?.notice ?? ''),
          ),
          const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          _buildInfoRow(
            '群描述',
            _groupInfo?.description ?? '无',
            canEdit: _isOwner || _isAdmin,
            onTap: () => _editField('description', _groupInfo?.description ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool canEdit = false,
    VoidCallback? onTap,
    Widget? customRight,
    String? subtitle,
  }) {
    return InkWell(
      onTap: canEdit ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: customRight ?? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
                    ),
                  ),
                  if (canEdit)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Personalization Section ────────────────────────────────────────────

  bool _isPinned = false;
  bool _isMuted = false;

  Widget _buildPersonalizationSection() {
    return _buildCard(
      child: Column(
        children: [
          _buildInfoRow(
            '我在本群的昵称',
            _myNickName?.isNotEmpty == true ? _myNickName! : '未设置',
            subtitle: '由于管理员开启了内部群仅显示真名，此功能被禁用。',
            canEdit: true,
            onTap: () => _editField('nickname', _myNickName ?? ''),
          ),
          const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          _buildInfoRow(
            '群备注',
            _groupInfo?.alias?.isNotEmpty == true ? _groupInfo!.alias! : '未设置',
            canEdit: true,
            onTap: () => _editField('alias', _groupInfo?.alias ?? ''),
          ),
          const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          _buildToggleRow('置顶会话', _isPinned, (v) async {
            final old = _isPinned;
            setState(() => _isPinned = v);
            try {
              final repo = ref.read(chatRepositoryProvider);
              // For group conv ids, the repo expects the prefixed 'group:{groupId}'
              // Actually, signalR chat repo takes 'group:{groupId}' natively for some, 
              // but pin/mute endpoints from web usually take raw ID.
              // We will pass the group ID directly if that's what backend expects, 
              // but if backend expects prefixed, we pass prefixed.
              // Wait, Web usually expects the `groupId` as the conversationId for groups when pinning.
              await repo.pinConversation(widget.groupId, v);
              // Refresh conversation list to re-order and show pin icon
              if (mounted) {
                ref.read(chatRoomsProvider.notifier).refresh();
                _didChange = true;
              }
            } catch (e) {
              if (mounted) {
                setState(() => _isPinned = old);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('置顶失败: $e')),
                );
              }
            }
          }),
          const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          _buildToggleRow('消息免打扰', _isMuted, (v) async {
            final old = _isMuted;
            setState(() => _isMuted = v);
            try {
              final repo = ref.read(chatRepositoryProvider);
              await repo.muteConversation(widget.groupId, v);
              // Refresh conversation list to show/hide mute icon
              if (mounted) {
                ref.read(chatRoomsProvider.notifier).refresh();
                _didChange = true;
              }
            } catch (e) {
              if (mounted) {
                setState(() => _isMuted = old);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('设置免打扰失败: $e')),
                );
              }
            }
          }),
          const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          _buildInfoRow('设置聊天背景', '', canEdit: true, onTap: () => _showComingSoon('聊天背景')),
          const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          _buildInfoRow('AI实时翻译', '', canEdit: true, onTap: () => _showComingSoon('AI实时翻译')),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Color(0xFF111111))),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF007AFF),
          ),
        ],
      ),
    );
  }

  String? get _myNickName {
    final me = _members.where((m) => m.userId.toLowerCase() == _currentUserId);
    if (me.isEmpty) return null;
    return me.first.nickName;
  }

  void _showComingSoon(String featureName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$featureName功能即将上线')),
    );
  }

  // ── Management Section ────────────────────────────────────────────────

  Widget _buildManagementSection() {
    return _buildCard(
      child: Column(
        children: [
          // 机器人
          InkWell(
            onTap: () => _showComingSoon('机器人管理'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('机器人', style: TextStyle(fontSize: 16, color: Color(0xFF111111))),
                      Row(
                        children: const [
                          Text('1个', style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                          SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC)),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  // App badge placeholder
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.smart_toy_outlined, color: Color(0xFF0052D9), size: 20),
                  ),
                  const SizedBox(height: 12),
                  const Text('机器人具备丰富的技能，让沟通协同更智能高效', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          // 群类型
          _buildInfoRow(
            '群类型',
            '内部群',
            subtitle: '企业内部安全沟通群，仅内部员工可入群，离职员工自动退群',
            canEdit: false,
          ),
        ],
      ),
    );
  }

  // ── Other Features Section ─────────────────────────────────────────────

  Widget _buildOtherFeaturesSection() {
    return _buildCard(
      child: Column(
        children: [
          _buildInfoRow('标签', '未设置', canEdit: true, onTap: () => _showComingSoon('标签设置')),
        ],
      ),
    );
  }

  // ── Actions Section ────────────────────────────────────────────────────

  Widget _buildActionsSection() {
    return _buildCard(
      child: Column(
        children: [
          InkWell(
            onTap: () => _showComingSoon('清空聊天记录'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  '清空聊天记录',
                  style: TextStyle(fontSize: 16, color: Color(0xFFFF4D4F)),
                ),
              ),
            ),
          ),
          const Divider(height: 1, indent: 0, color: Color(0xFFF0F0F0)),
          InkWell(
            onTap: _leaveGroup,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _isOwner ? '解散群聊' : '退出群聊',
                  style: const TextStyle(fontSize: 16, color: Color(0xFFFF4D4F)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  void _showAllMembers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AllMembersPage(
          members: _members,
          groupId: widget.groupId,
          isOwner: _isOwner,
          isAdmin: _isAdmin,
          currentUserId: _currentUserId,
          onRefresh: _loadData,
        ),
      ),
    );
  }

  void _openUserProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(userId: userId),
      ),
    );
  }

  void _inviteMembers() async {
    final existingUserIds = _members.map((m) => m.userId).toSet();
    final selectedUsers = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(
        builder: (_) => UserSelectionPage(
          title: '邀请联系人',
          disabledIds: existingUserIds,
          confirmButtonText: '确定邀请',
        ),
      ),
    );

    if (selectedUsers != null && selectedUsers.isNotEmpty && mounted) {
      try {
        final api = ref.read(groupApiServiceProvider);
        final userIds = selectedUsers.map((u) => (u['id'] as String).toLowerCase()).toList();
        await api.inviteUsers(widget.groupId, userIds);

        // Broadcast new members invited
        final sm = ref.read(signalRConnectionProvider);
        if (sm.isConnected) {
          final summary = '邀请了 ${userIds.length} 位新成员加入群聊';
          await sm.notifyMembersInvited(widget.groupId, userIds, summary);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已发送入群邀请')),
        );
        _loadData(); // refresh member list
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('邀请失败: $e')),
        );
      }
    }
  }

  void _searchHistory([int initialIndex = 0]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageSearchPage(
          groupId: widget.groupId,
          initialTabIndex: initialIndex,
        ),
      ),
    );
  }

  Future<String?> _showEditSheet(String title, String initialValue, int maxLength, bool multiline) {
    final controller = TextEditingController(text: initialValue);
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111111))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF999999)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLength: maxLength,
                maxLines: multiline ? 5 : 1,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '请输入...',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0052D9),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('保存', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editField(String field, String currentValue) async {
    final labels = {
      'name': '群名称',
      'notice': '群公告',
      'description': '群描述',
      'alias': '群备注',
      'nickname': '我在本群的昵称',
    };
    final maxLengths = {
      'name': 20,
      'notice': 500,
      'description': 128,
      'alias': 32,
      'nickname': 32,
    };
    final title = '编辑${labels[field]}';
    final multiline = field == 'notice' || field == 'description';

    final result = await _showEditSheet(title, currentValue, maxLengths[field]!, multiline);
    if (result == null || !mounted) return;

    try {
      final api = ref.read(groupApiServiceProvider);
      if (field == 'alias') {
        await api.setAlias(widget.groupId, result);
      } else if (field == 'nickname') {
        await api.setNickName(widget.groupId, result);
      } else {
        await api.updateGroup(widget.groupId, {field: result});
        // Broadcast public group info changes
        final sm = ref.read(signalRConnectionProvider);
        if (sm.isConnected && (field == 'name' || field == 'notice' || field == 'description')) {
          final summary = field == 'name' ? '$_currentUserName 修改群名称为「$result」' 
                        : field == 'notice' ? '$_currentUserName 发布了新公告' 
                        : '$_currentUserName 修改了群描述';
          await sm.notifyGroupUpdated(widget.groupId, field, summary);
        }
      }
      _didChange = true;
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${labels[field]}已更新')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败: $e')),
      );
    }
  }

  Future<void> _leaveGroup() async {
    final action = _isOwner ? '解散' : '退出';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action群聊'),
        content: Text('确定要$action该群聊吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final api = ref.read(groupApiServiceProvider);
      if (_isOwner) {
        await api.dissolveGroup(widget.groupId);
      } else {
        await api.leaveGroup(widget.groupId);
      }
      if (!mounted) return;
      // Pop back to conversation list.
      Navigator.of(context)
        ..pop() // group settings
        ..pop(); // chat detail
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$action失败: $e')),
      );
    }
  }
}

// ── All Members Page ────────────────────────────────────────────────────

class _AllMembersPage extends ConsumerStatefulWidget {
  final List<ImGroupMember> members;
  final String groupId;
  final bool isOwner;
  final bool isAdmin;
  final String currentUserId;
  final Future<void> Function() onRefresh;

  const _AllMembersPage({
    required this.members,
    required this.groupId,
    required this.isOwner,
    required this.isAdmin,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  ConsumerState<_AllMembersPage> createState() => _AllMembersPageState();
}

class _AllMembersPageState extends ConsumerState<_AllMembersPage> {
  late List<ImGroupMember> _localMembers;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _localMembers = List.from(widget.members);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _confirmRemove(ImGroupMember member) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('移除成员'),
            content: Text('确定要将 ${member.displayName} 移出群聊吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('移除'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _removeMember(ImGroupMember member) async {
    try {
      final api = ref.read(groupApiServiceProvider);
      await api.removeUser(widget.groupId, member.userId);
      
      // Broadcast user removed
      final sm = ref.read(signalRConnectionProvider);
      if (sm.isConnected) {
        await sm.notifyMemberRemoved(widget.groupId, member.userId, '将 ${member.displayName} 移出群聊');
      }

      setState(() {
        _localMembers.removeWhere((m) => m.userId == member.userId);
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将 ${member.displayName} 移出群聊')),
      );
      
      widget.onRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移除失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter by search
    final filtered = _localMembers.where((m) {
      if (_searchQuery.isEmpty) return true;
      final matchName = m.displayName.toLowerCase().contains(_searchQuery) ||
                        m.userName.toLowerCase().contains(_searchQuery);
      return matchName;
    }).toList();

    // Sort: owner first, then admins, then regular members.
    final sorted = List<ImGroupMember>.from(filtered)
      ..sort((a, b) {
        if (a.isSuperAdmin && !b.isSuperAdmin) return -1;
        if (!a.isSuperAdmin && b.isSuperAdmin) return 1;
        if (a.isAdmin && !b.isAdmin) return -1;
        if (!a.isAdmin && b.isAdmin) return 1;
        return a.displayName.compareTo(b.displayName);
      });

    // Simple grouping by first letter (Pinyin conversion omitted for simplicity right now, using English characters or #)
    final Map<String, List<ImGroupMember>> grouped = {};
    for (final m in sorted) {
      final firstChar = m.displayName.isNotEmpty ? m.displayName[0].toUpperCase() : '#';
      final isLetter = RegExp(r'[A-Z]').hasMatch(firstChar);
      final key = isLetter ? firstChar : '#';
      grouped.putIfAbsent(key, () => []).add(m);
    }
    
    // Create flattened list with headers
    final flattened = <dynamic>[];
    final letters = grouped.keys.toList()..sort();
    // Force # to bottom
    if (letters.contains('#')) {
      letters.remove('#');
      letters.add('#');
    }

    for (final l in letters) {
      flattened.add(l); // Header
      flattened.addAll(grouped[l]!); // Members
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('群成员', style: TextStyle(fontSize: 18, color: Color(0xFF111111), fontWeight: FontWeight.normal)),
            Text('群成员${_localMembers.length}人，最多可添加1000人', style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () async {
              final selected = await Navigator.of(context).push<List<Map<String, dynamic>>>(
                MaterialPageRoute(
                  builder: (_) => UserSelectionPage(
                    title: '邀请群成员',
                    confirmButtonText: '确定',
                    disabledIds: _localMembers.map((m) => m.userId.toLowerCase()).toSet(),
                  ),
                ),
              );

              if (selected != null && selected.isNotEmpty) {
                try {
                  final api = ref.read(groupApiServiceProvider);
                  final userIds = selected.map((u) => u['id'] as String).toList();
                  await api.inviteUsers(widget.groupId, userIds);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已发送邀请')),
                  );
                  widget.onRefresh();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('邀请失败: $e')),
                  );
                }
              }
            },
          )
        ],
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F6),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: Color(0xFF999999)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: '搜索',
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                            hintStyle: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                          ),
                          style: const TextStyle(fontSize: 14, color: Color(0xFF111111)),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          child: const Icon(Icons.cancel, size: 16, color: Color(0xFFBDBDBD)),
                        ),
                    ],
                  ),
                ),
              ),
              // What is identity info
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFF0052D9)),
                    SizedBox(width: 8),
                    Text('什么是群身份', style: TextStyle(color: Color(0xFF0052D9), fontSize: 13)),
                    Spacer(),
                    Icon(Icons.chevron_right, size: 16, color: Color(0xFF0052D9)),
                  ],
                ),
              ),
              // List
              Expanded(
                child: ListView.builder(
                  itemCount: flattened.length,
                  itemBuilder: (ctx, index) {
                    final item = flattened[index];
                    if (item is String) {
                      // Header
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(item, style: const TextStyle(fontSize: 14, color: Color(0xFF999999))),
                      );
                    }

                    final member = item as ImGroupMember;
                    final isCurrentUser = member.userId.toLowerCase() == widget.currentUserId;
                    
                    final canRemove = !isCurrentUser &&
                        (widget.isOwner || (widget.isAdmin && !member.isAdmin && !member.isSuperAdmin));

                    Widget tile = _MemberTile(
                      member: member,
                      isCurrentUser: isCurrentUser,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserProfilePage(userId: member.userId),
                          ),
                        );
                      },
                    );

                    if (canRemove) {
                      tile = Dismissible(
                        key: ValueKey(member.userId),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _confirmRemove(member),
                        onDismissed: (_) => _removeMember(member),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: tile,
                      );
                    }

                    return tile;
                  },
                ),
              ),
            ],
          ),
          // Alphabet Scroller
          Positioned(
            right: 4,
            top: 200,
            bottom: 60,
            width: 20,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: letters.map((l) {
                return Expanded(
                  child: Text(
                    l,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final ImGroupMember member;
  final bool isCurrentUser;
  final VoidCallback onTap;

  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4FD),
                borderRadius: BorderRadius.circular(10), // Squircle
                image: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(member.avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: (member.avatarUrl == null || member.avatarUrl!.isEmpty)
                  ? Text(
                      member.displayName.isNotEmpty ? member.displayName.characters.first : 'U',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0052D9),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Name and tags
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      member.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
                    ),
                  ),
                  if (member.isSuperAdmin || member.isAdmin || isCurrentUser) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCurrentUser || member.isSuperAdmin 
                            ? const Color(0xFFFFF2E8) 
                            : const Color(0xFFE8F4FD),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        member.isSuperAdmin ? '群主' : (member.isAdmin ? '管理员' : '我'),
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrentUser || member.isSuperAdmin 
                              ? const Color(0xFFFA8C16) 
                              : const Color(0xFF0052D9),
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            // Set Role action
            if (isCurrentUser) // In reality this would be checked against permissions
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: const Text('设置身份', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
              ),
          ],
        ),
      ),
    );
  }
}
