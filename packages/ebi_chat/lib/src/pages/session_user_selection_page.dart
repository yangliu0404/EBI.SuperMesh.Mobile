import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';
import 'package:ebi_chat/src/chat_room.dart';

class SessionUserSelectionPage extends ConsumerStatefulWidget {
  final bool multiSelect;
  final List<String>? initialSelectedIds;
  final List<String>? disabledIds;
  final String? title;

  const SessionUserSelectionPage({
    super.key,
    this.multiSelect = true,
    this.initialSelectedIds,
    this.disabledIds,
    this.title,
  });

  @override
  ConsumerState<SessionUserSelectionPage> createState() => _SessionUserSelectionPageState();
}

class _SessionUserSelectionPageState extends ConsumerState<SessionUserSelectionPage> {
  final Map<String, Map<String, dynamic>> _selectedUsers = {};
  late List<String> _disabledIds;

  @override
  void initState() {
    super.initState();
    _disabledIds = widget.disabledIds ?? [];
    // We don't necessarily load all initialSelectedIds because we don't have all their info here,
    // but the user will see selection when they merge back in the parent page.
  }

  void _toggleSelection(ChatRoom room) {
    if (_disabledIds.contains(room.id)) return;

    setState(() {
      if (!widget.multiSelect) {
        _selectedUsers.clear();
        _selectedUsers[room.id] = {
          'id': room.id,
          'name': room.name,
          'userName': room.name,
          'avatarUrl': room.avatar,
        };
      } else {
        if (_selectedUsers.containsKey(room.id)) {
          _selectedUsers.remove(room.id);
        } else {
          _selectedUsers[room.id] = {
            'id': room.id,
            'name': room.name,
            'userName': room.name,
            'avatarUrl': room.avatar,
          };
        }
      }
    });
  }

  void _confirmSelection() {
    Navigator.of(context).pop(_selectedUsers.values.toList());
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? context.L('ByConversation'), style: const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: roomsAsync.when(
              data: (rooms) {
                final directRooms = rooms.where((r) => r.type == ChatRoomType.direct).toList();
                if (directRooms.isEmpty) {
                  return Center(child: Text(context.L('NoPrivateConversations'), style: const TextStyle(color: Color(0xFF999999))));
                }

                return ListView.builder(
                  itemCount: directRooms.length,
                  itemBuilder: (context, index) {
                    final room = directRooms[index];
                    final isSelected = _selectedUsers.containsKey(room.id) || _disabledIds.contains(room.id);
                    final isDisabled = _disabledIds.contains(room.id);

                    return GestureDetector(
                      onTap: () => _toggleSelection(room),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: Colors.white,
                        child: Opacity(
                          opacity: isDisabled ? 0.5 : 1.0,
                          child: Row(
                            children: [
                              if (widget.multiSelect) ...[
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDisabled
                                        ? Colors.grey.shade300
                                        : (isSelected ? const Color(0xFFE2EFFF) : Colors.transparent),
                                    border: isSelected || isDisabled
                                        ? null
                                        : Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
                                  ),
                                  alignment: Alignment.center,
                                  child: isSelected || isDisabled
                                      ? const Icon(Icons.check, size: 14, color: Color(0xFF0052D9))
                                      : null,
                                ),
                                const SizedBox(width: 16),
                              ],
                              // Avatar Squircle
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F4FD),
                                  borderRadius: BorderRadius.circular(10), // Squircle
                                  image: room.avatar != null && room.avatar!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(room.avatar!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: (room.avatar == null || room.avatar!.isEmpty)
                                    ? Text(
                                        room.name.isNotEmpty ? room.name.characters.first : 'U',
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
                                child: Text(
                                  room.name,
                                  style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isDisabled)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Text(
                                    context.L('AlreadyInGroup'),
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('加载失败')),
            ),
          ),
          if (widget.multiSelect && _selectedUsers.isNotEmpty)
            _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final selectedList = _selectedUsers.values.toList();
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: selectedList.map((user) {
                  final avatarUrl = user['avatarUrl'] as String?;
                  final name = (user['name'] ?? user['userName'] ?? '') as String;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: Stack(
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
                        Positioned(
                          top: -2,
                          right: -2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedUsers.remove(user['id']);
                              });
                            },
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: selectedList.isEmpty ? null : _confirmSelection,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052D9),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCCCCCC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: Text('确定(${selectedList.length})'),
          ),
        ],
      ),
    );
  }
}
