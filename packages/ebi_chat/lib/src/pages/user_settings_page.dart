import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

/// User settings page — accessed from UserProfilePage AppBar ⋮.
///
/// Contains: edit remark, permissions (placeholder), recommend to colleague,
/// blacklist (placeholder), report (placeholder).
class UserSettingsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const UserSettingsPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  String _remarkName = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户设置', style: TextStyle(fontSize: 17)),
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
                  label: '设置备注',
                  value: _remarkName.isNotEmpty ? _remarkName : '未设置',
                  onTap: _editRemark,
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingTile(
                  icon: Icons.share_outlined,
                  label: '推荐给同事',
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
                  label: '权限设置',
                  onTap: () => _showComingSoon('权限设置'),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingTile(
                  icon: Icons.block_outlined,
                  label: '加入黑名单',
                  textColor: const Color(0xFFFF4D4F),
                  onTap: () => _showComingSoon('黑名单'),
                ),
                const Divider(height: 1, indent: 56),
                _buildSettingTile(
                  icon: Icons.flag_outlined,
                  label: '举报',
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
        title: const Text('设置备注'),
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
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
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

  void _shareUser() {
    // TODO: Open conversation picker to forward user card.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('推荐给同事功能开发中')),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature功能即将上线')),
    );
  }
}
