import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/pages/session_user_selection_page.dart';

/// A generic user selection page for picking one or multiple users.
///
/// Returns a `List<Map<String, dynamic>>` of selected users when confirmed.
class UserSelectionPage extends ConsumerStatefulWidget {
  final String? title;
  final bool multiSelect;
  final Set<String>? initialSelectedIds;
  final Set<String>? disabledIds; // Uids that cannot be deselected or selected
  final String? confirmButtonText;

  const UserSelectionPage({
    super.key,
    this.title,
    this.multiSelect = true,
    this.initialSelectedIds,
    this.disabledIds,
    this.confirmButtonText,
  });

  @override
  ConsumerState<UserSelectionPage> createState() => _UserSelectionPageState();
}

class _UserSelectionPageState extends ConsumerState<UserSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchTimer;

  List<Map<String, dynamic>> _userResults = [];
  bool _isLoading = false;

  // Selected state: userId -> user map
  final Map<String, Map<String, dynamic>> _selectedUsers = {};
  
  // Disabled ids
  late final Set<String> _disabledIds;

  @override
  void initState() {
    super.initState();
    _disabledIds = widget.disabledIds ?? {};
    
    // We don't pre-populate full objects for initials, just the logic checks selection
    _searchController.addListener(_onSearchChanged);
    _doUserSearch(''); // Fetch all users initially
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _searchQuery) return;
    
    setState(() => _searchQuery = query);
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () => _doUserSearch(query));
  }

  Future<void> _doUserSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        '/api/identity/users',
        queryParameters: {
          'filter': query.isEmpty ? null : query,
          'maxResultCount': 50,
          'sorting': 'userName asc',
        },
      );
      
      final data = response.data;
      List<dynamic> items = [];
      if (data is Map<String, dynamic>) {
        if (data.containsKey('result') && data['result'] is Map) {
          items = (data['result']['items'] as List?) ?? [];
        } else {
          items = (data['items'] as List?) ?? [];
        }
      }

      if (mounted) {
        setState(() {
          _userResults = items.cast<Map<String, dynamic>>();
          
          // Auto-check initially selected ones from initialSelectedIds if they appear in results
          if (widget.initialSelectedIds != null) {
            for (final u in _userResults) {
              final id = (u['id'] as String?)?.toLowerCase() ?? '';
              if (widget.initialSelectedIds!.contains(id) && !_selectedUsers.containsKey(id)) {
                 _selectedUsers[id] = u;
              }
            }
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(Map<String, dynamic> user, String userId) {
    if (_disabledIds.contains(userId)) return;

    setState(() {
      if (!widget.multiSelect) {
        _selectedUsers.clear();
        _selectedUsers[userId] = user;
        // In single-select mode, there is no confirm bottom bar, so we return immediately.
        Navigator.of(context).pop([user]);
      } else {
        if (_selectedUsers.containsKey(userId)) {
          // Can't unselect if it was originally selected and is marked disabled
          _selectedUsers.remove(userId);
        } else {
          _selectedUsers[userId] = user;
        }
      }
    });
  }

  void _confirmSelection() {
    Navigator.of(context).pop(_selectedUsers.values.toList());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? context.L('SelectContacts'), style: const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.w500)),
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
          _buildTopSection(),
          Expanded(
            child: _isLoading && _userResults.isEmpty
                ? Center(child: EbiLoading(message: context.L('Loading')))
                : _buildUserList(),
          ),
          if (widget.multiSelect) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final selectedCount = _selectedUsers.length;
    final selectedList = _selectedUsers.values.toList();
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('勾选群成员后，为你自动匹配群归属', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
              Row(
                children: const [
                  Text('修改群聊', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                  Icon(Icons.chevron_right, size: 14, color: Color(0xFF999999)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('${context.L('Selected')} ($selectedCount)', style: const TextStyle(fontSize: 16, color: Color(0xFF111111))),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedList.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final u = selectedList[index];
                      final name = (u['name'] ?? u['userName'] ?? '') as String;
                      final avatarUrl = u['avatarUrl'] as String?;
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F4FD),
                          borderRadius: BorderRadius.circular(8),
                          image: avatarUrl != null && avatarUrl.isNotEmpty
                              ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: (avatarUrl == null || avatarUrl.isEmpty)
                            ? Text(
                                name.isNotEmpty ? name.characters.first : 'U',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0052D9)),
                              )
                            : null,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: selectedCount > 0 ? const Color(0xFF4C8DF5) : const Color(0xFF99C2FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  minimumSize: Size.zero,
                ),
                onPressed: selectedCount > 0 ? _confirmSelection : null,
                child: Text(widget.confirmButtonText ?? context.L('CreateGroupChat'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          // Search Bar
          Container(
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
                    decoration: InputDecoration(
                      hintText: context.L('Search'),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
                    ),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF111111)),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                    },
                    child: const Icon(Icons.cancel, size: 16, color: Color(0xFFBDBDBD)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Category Icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCategoryIcon(Icons.chat_bubble_outline, context.L('ByConversation'), onTap: () async {
                final selected = await Navigator.of(context).push<List<Map<String, dynamic>>>(
                  MaterialPageRoute(
                    builder: (_) => SessionUserSelectionPage(
                      multiSelect: widget.multiSelect,
                      disabledIds: widget.disabledIds?.toList(),
                    ),
                  ),
                );
                if (selected != null && selected.isNotEmpty) {
                  setState(() {
                    for (var u in selected) {
                      final id = (u['id'] as String?)?.toLowerCase() ?? '';
                      _selectedUsers[id] = u;
                    }
                  });
                }
              }),
              _buildCategoryIcon(Icons.account_tree_outlined, context.L('ByOrganization')),
              _buildCategoryIcon(Icons.cell_wifi, context.L('FaceToFaceGroup')),
              _buildCategoryIcon(Icons.people_outline, context.L('ByGroup')),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F9), // Very light purple/grey
              borderRadius: BorderRadius.circular(16), // Squircle
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 28, color: const Color(0xFF333333)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (!_isLoading && _userResults.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty ? context.L('NoMatchingContacts') : context.L('NoContacts'),
          style: const TextStyle(color: Color(0xFF999999)),
        ),
      );
    }

    return ListView.builder(
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
        final id = (user['id'] as String?)?.toLowerCase() ?? '';
        final name = (user['name'] ?? user['userName'] ?? '') as String;
        final userName = (user['userName'] ?? '') as String;
        final avatarUrl = user['avatarUrl'] as String?;
        
        final isSelected = _selectedUsers.containsKey(id) || _disabledIds.contains(id);
        final isDisabled = _disabledIds.contains(id);

        return GestureDetector(
          onTap: () => _toggleSelection(user, id),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isNotEmpty ? name : userName,
                          style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (name.isNotEmpty && name != userName)
                          Text(
                            userName,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
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
  }
}
