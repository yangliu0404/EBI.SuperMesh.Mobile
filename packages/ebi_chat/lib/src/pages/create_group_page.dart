import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_chat/src/pages/group_settings_page.dart';
import 'package:ebi_chat/src/pages/chat_detail_page.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> selectedUsers;

  const CreateGroupPage({super.key, required this.selectedUsers});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入群聊名称')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final userIds = widget.selectedUsers
          .map((u) => (u['id'] as String).toLowerCase())
          .toList();

      final api = ref.read(groupApiServiceProvider);
      final group = await api.createGroup(
        name: name,
        userIds: userIds,
      );

      if (!mounted) return;

      // Pop the create page
      Navigator.of(context).pop();
      // Also pop the Selection page that spawned this one
      Navigator.of(context).pop(true);

      // Navigate to the newly created group's detail page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(
            roomId: 'group:${group.id}',
            roomName: group.name,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建群组失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创建群聊', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createGroup,
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '完成',
                    style: TextStyle(
                      color: Color(0xFF0052D9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF2F2F6),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _nameController,
                autofocus: true,
                maxLength: 20,
                decoration: const InputDecoration(
                  hintText: '起一个群名称...',
                  border: InputBorder.none,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '已选择: ${widget.selectedUsers.length} 人',
              style: const TextStyle(fontSize: 14, color: Color(0xFF111111), fontWeight: FontWeight.normal),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: widget.selectedUsers.length,
                itemBuilder: (context, index) {
                  final user = widget.selectedUsers[index];
                  final name = (user['name'] ?? user['userName'] ?? '') as String;
                  final avatarUrl = user['avatarUrl'] as String?;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F4FD),
                            borderRadius: BorderRadius.circular(10), // Squircle
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
                                  name.isNotEmpty ? name.characters.first : 'U',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0052D9),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
