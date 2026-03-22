import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/widgets/forward_sheet.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';
import 'package:ebi_chat/src/models/im_models.dart';

/// User settings page — accessed from UserProfilePage AppBar ⋮.
///
/// Contains: edit remark, permissions (placeholder), recommend to colleague,
/// blacklist (placeholder), report (placeholder).
class UserSettingsPage extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final String? avatarUrl;

  const UserSettingsPage({
    super.key,
    required this.userId,
    required this.userName,
    this.avatarUrl,
  });

  @override
  ConsumerState<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends ConsumerState<UserSettingsPage> {
  String _remarkName = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.L('UserSettings')),
        backgroundColor: EbiColors.primaryBlue,
        foregroundColor: EbiColors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // ── Remark & Share ──────────────────────────────────────
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildSettingTile(
                  icon: Icons.edit_outlined,
                  label: context.L('SetRemark'),
                  value: _remarkName.isNotEmpty ? _remarkName : context.L('NotSet'),
                  onTap: _editRemark,
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingTile(
                  icon: Icons.share_outlined,
                  label: context.L('RecommendToColleagues'),
                  onTap: _shareUser,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── Reserved Settings ───────────────────────────────────
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildSettingTile(
                  icon: Icons.security_outlined,
                  label: context.L('PermissionSettings'),
                  onTap: () => _showComingSoon('权限设置'),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingTile(
                  icon: Icons.block_outlined,
                  label: context.L('AddToBlacklist'),
                  textColor: const Color(0xFFFF4D4F),
                  onTap: () => _showComingSoon('黑名单'),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingTile(
                  icon: Icons.flag_outlined,
                  label: context.L('Report'),
                  textColor: const Color(0xFFFF4D4F),
                  onTap: () => _showComingSoon('举报'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String label,
    String? value,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: textColor ?? const Color(0xFF666666)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor ?? const Color(0xFF333333),
                ),
              ),
            ),
            if (value != null)
              Text(
                value,
                style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  Future<void> _editRemark() async {
    final controller = TextEditingController(text: _remarkName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.L('SetRemark')),
        content: TextField(
          controller: controller,
          maxLength: 32,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '给 ${widget.userName} 设置备注',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.L('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(context.L('Save')),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    setState(() => _remarkName = result);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.isEmpty ? '已清除备注' : '备注已设置为: $result')),
    );
  }

  Future<void> _shareUser() async {
    final target = await showForwardSheet(context, ref);
    if (target == null || !mounted) return;

    try {
      final repo = ref.read(chatRepositoryProvider);
      final currentUserId = ref.read(authProvider).user?.id ?? '';
      
      // We will use the target user's ID or name as the "content" of the contactCard. 
      // Ideally, the content should be a JSON containing user info if the backend prefers it,
      // but here we just use the name for the UI display format `[个人名片] xxx`.
      final cardContent = widget.userName;
      
      final extraProps = <String, dynamic>{
        'UserId': widget.userId,
        'UserName': widget.userName,
        if (widget.avatarUrl != null) 'AvatarUrl': widget.avatarUrl!,
      };

      final fwdMessage = ImChatMessage(
        messageId: '',
        formUserId: currentUserId,
        formUserName: '', // backend can fill
        toUserId: target.type == 'user' ? target.conversationKey : null,
        groupId: target.groupId ?? '',
        content: cardContent,
        sendTime: DateTime.now().toUtc().toIso8601String(),
        messageType: ImMessageType.contactCard.value,
        source: ImMessageSourceType.user.value,
        extraProperties: extraProps,
      );
      
      await repo.sendMessage(fwdMessage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('名片已发送给 ${target.displayName}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature功能即将上线')),
    );
  }
}
