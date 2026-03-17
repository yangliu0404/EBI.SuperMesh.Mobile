import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/models/im_group_models.dart';
import 'package:ebi_chat/src/pages/group_settings_page.dart';
import 'package:ebi_chat/src/pages/user_profile_page.dart';

/// Chat settings page for 1-to-1 private chats (DingDing-style).
///
/// Shows: user card + "发起群聊", search with category icons,
/// mute/pin toggles, chat background, clear history.
class ChatSettingsPage extends ConsumerStatefulWidget {
  final String otherUserId;
  final String? otherUserName;

  const ChatSettingsPage({
    super.key,
    required this.otherUserId,
    this.otherUserName,
  });

  @override
  ConsumerState<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends ConsumerState<ChatSettingsPage> {
  ImUserCard? _otherUser;
  bool _loading = true;
  bool _isMuted = false;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final api = ref.read(groupApiServiceProvider);
      final card = await api.getUserCard(widget.otherUserId);
      if (!mounted) return;
      setState(() {
        _otherUser = card;
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('[ChatSettings] load user failed', e);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天设置', style: TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFFF2F2F6),
        foregroundColor: const Color(0xFF111111),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      backgroundColor: const Color(0xFFF2F2F6),
      body: _loading
          ? const EbiLoading(message: '加载中...')
          : ListView(
              children: [
                const SizedBox(height: 8),
                _buildUserSection(),
                _buildSearchSection(),
                _buildToggleSection(),
                _buildShortcutSection(),
                _buildBackgroundSiriSection(),
                _buildClearHistorySection(),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  // Helper for white rounded cards
  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  // ── User Card Section ─────────────────────────────────────────────

  Widget _buildUserSection() {
    final displayName = _otherUser?.displayName ?? widget.otherUserName ?? '?';
    final initial = displayName.isNotEmpty ? displayName.characters.first : '?';

    return _buildCard(
      child: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _UserProfileRedirect(userId: widget.otherUserId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F4FD),
                      borderRadius: BorderRadius.circular(14), // Squircle
                      image: _otherUser?.avatarUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_otherUser!.avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: _otherUser?.avatarUrl == null
                        ? Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0052D9),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111111),
                          ),
                        ),
                        if (_otherUser?.department != null && _otherUser!.department!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _otherUser!.department!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 76, color: Color(0xFFF0F0F0)),
          InkWell(
            onTap: _createGroupChat,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.add, color: Color(0xFF999999), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '发起群聊',
                    style: TextStyle(fontSize: 16, color: Color(0xFF111111)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search + Category Icons ───────────────────────────────────────

  Widget _buildSearchSection() {
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          children: [
            // Search bar
            GestureDetector(
              onTap: _searchHistory,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 20),
            // Category icons Wrap
            LayoutBuilder(builder: (context, constraints) {
              // Calculate width for 4 items per row for more breathing room for text
              final itemWidth = constraints.maxWidth / 4;
              return Wrap(
                spacing: 0,
                runSpacing: 20,
                children: [
                  _categoryIcon(Icons.chat_bubble_outline, '聊天记录', width: itemWidth, onTap: _searchHistory),
                  _categoryIcon(Icons.image_outlined, '图片及视频', width: itemWidth, onTap: () => _showComingSoon('图片及视频')),
                  _categoryIcon(Icons.folder_outlined, '文件', width: itemWidth, onTap: () => _showComingSoon('文件')),
                  _categoryIcon(Icons.link, '链接', width: itemWidth, onTap: () => _showComingSoon('链接')),
                  
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
            Icon(icon, size: 24, color: const Color(0xFF333333)), // Darker icons
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

  // ── Toggle Settings ────────────────────────────────────────────────

  Widget _buildToggleSection() {
    return _buildCard(
      child: Column(
        children: [
          _toggleRow('置顶会话', _isPinned, (v) => setState(() => _isPinned = v)),
          const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          _toggleRow('消息免打扰', _isMuted, (v) => setState(() => _isMuted = v)),
        ],
      ),
    );
  }

  Widget _toggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF007AFF), // iOS Blue
          ),
        ],
      ),
    );
  }

  // ── Shortcut Section ───────────────────────────────────────────────

  bool _isShortcutEnabled = true; // State for shortcut toggle

  Widget _buildShortcutSection() {
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('快捷栏', style: TextStyle(fontSize: 16, color: Color(0xFF111111))),
                  SizedBox(height: 4),
                  Text('关闭后，所有单聊不再展示快捷栏', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                ],
              ),
            ),
            Switch.adaptive(
              value: _isShortcutEnabled,
              onChanged: (v) => setState(() => _isShortcutEnabled = v),
              activeColor: const Color(0xFF007AFF),
            ),
          ],
        ),
      ),
    );
  }

  // ── Other Settings (Background, AI, Siri) ──────────────────────────

  Widget _buildBackgroundSiriSection() {
    return _buildCard(
      child: Column(
        children: [
          _settingTile('设置聊天背景', onTap: () => _showComingSoon('聊天背景')),
          const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          _settingTile('AI实时翻译', onTap: () => _showComingSoon('AI实时翻译')),
          const Divider(height: 1, indent: 16, color: Color(0xFFF0F0F0)),
          _settingTile('添加当前联系人到 Siri', onTap: () => _showComingSoon('Siri联系人添加')),
        ],
      ),
    );
  }

  // ── Clear History ──────────────────────────────────────────────────

  Widget _buildClearHistorySection() {
    return _buildCard(
      child: InkWell(
        onTap: _clearHistory,
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
    );
  }

  Widget _settingTile(String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────

  void _createGroupChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('创建群聊功能开发中')),
    );
  }

  void _searchHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('搜索聊天记录功能开发中')),
    );
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空聊天记录'),
        content: const Text('确定要清空与此联系人的所有聊天记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('聊天记录清空功能开发中')),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature功能即将上线')),
    );
  }
}

/// Internal redirect widget to avoid circular import.
class _UserProfileRedirect extends ConsumerWidget {
  final String userId;
  const _UserProfileRedirect({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Because we import 'group_settings_page.dart' which internally exports
    // 'user_profile_page.dart', we can directly use UserProfilePage here
    // without causing a circular import on 'chat_settings_page.dart' <-> 'user_profile_page.dart'
    return UserProfilePage(userId: userId);
  }
}
