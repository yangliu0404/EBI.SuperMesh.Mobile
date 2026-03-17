import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/im_models.dart';
import 'package:ebi_chat/src/pages/group_settings_page.dart';
import 'package:ebi_chat/src/providers/chat_providers.dart';
import 'package:ebi_chat/src/chat_message.dart';
import 'package:ebi_chat/src/pages/file_preview_page.dart';
import 'package:ebi_chat/src/pages/media_gallery_page.dart';
import 'package:ebi_chat/src/services/oss_url_service.dart';
import 'package:ebi_chat/src/widgets/file_message_widget.dart';
import 'package:ebi_chat/src/pages/user_selection_page.dart';

class MessageSearchPage extends ConsumerStatefulWidget {
  final String? groupId;
  final String? userId; // For private chats
  final int initialTabIndex; // 0: History, 1: Files, 2: Links

  const MessageSearchPage({
    super.key,
    this.groupId,
    this.userId,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<MessageSearchPage> createState() => _MessageSearchPageState();
}

class _MessageSearchPageState extends ConsumerState<MessageSearchPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  Timer? _debounceTimer;
  
  bool _isLoading = false;
  List<ImChatMessage> _results = [];
  String? _errorMsg;

  String? _selectedSenderId;
  String? _selectedSenderName;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _doSearch(_searchQuery);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _doSearch(_searchQuery); // Refresh search based on new tab
  }

  void _onSearchInput(String val) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final query = val.trim();
      if (_searchQuery != query) {
        setState(() => _searchQuery = query);
        _doSearch(query);
      }
    });
  }

  Future<void> _doSearch(String query) async {

    try {
      int? messageType;
      bool isMediaTab = false;
      if (_tabController.index == 1) {
        isMediaTab = true;
      } else if (_tabController.index == 2) {
        messageType = ImMessageType.file.value;
      } else if (_tabController.index == 3) {
        messageType = ImMessageType.link.value;
      }
      
      List<ImChatMessage> resultItems = [];

      if (query.isEmpty) {
        // Fallback: load recent messages from history API.
        final chatRepo = ref.read(chatRepositoryProvider);
        List<ChatMessage> history = [];

        if (isMediaTab) {
          // Fetch images and videos and combine
          if (widget.groupId != null) {
            history = await chatRepo.getMediaMessages(groupId: widget.groupId!, maxResultCount: 100);
          } else if (widget.userId != null) {
            history = await chatRepo.getMediaMessages(receiveUserId: widget.userId!, maxResultCount: 100);
          }
        } else {
          // Fetch specific type or all
          if (widget.groupId != null) {
            history = await chatRepo.getGroupMessages(widget.groupId!, maxResultCount: 50, messageType: messageType);
          } else if (widget.userId != null) {
            history = await chatRepo.getUserMessages(widget.userId!, maxResultCount: 50, messageType: messageType);
          }
        }
        
        // Filter locally by type if necessary
        resultItems = history.map((e) => ImChatMessage(
          messageId: e.id,
          groupId: widget.groupId ?? '',
          formUserId: e.senderId,
          content: e.content,
          messageType: _mapUiTypeToIm(e.type),
          sendTime: e.createdAt.toIso8601String(),
          formUserName: e.senderName,
          extraProperties: {
            'fileName': e.fileName,
            'fileSize': e.fileSize,
            'fileExt': e.fileExt,
            'mimeType': e.mimeType,
          },
        )).toList();
        
        // Ensure sorting descending by time for combined lists (or general fallback)
        resultItems.sort((a, b) => b.sendTime.compareTo(a.sendTime));
        
        // Apply manual filters
        if (_selectedSenderId != null) {
          resultItems = resultItems.where((e) => e.formUserId == _selectedSenderId).toList();
        }
        if (_selectedDateRange != null) {
          final start = _selectedDateRange!.start;
          final end = _selectedDateRange!.end.add(const Duration(days: 1));
          resultItems = resultItems.where((e) {
            final dt = DateTime.tryParse(e.sendTime)?.toLocal();
            if (dt == null) return false;
            return dt.isAfter(start) && dt.isBefore(end);
          }).toList();
        }

      } else {
        // Normal search API
        String? startTime;
        String? endTime;
        if (_selectedDateRange != null) {
          final start = _selectedDateRange!.start;
          final end = _selectedDateRange!.end.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
          startTime = start.toUtc().toIso8601String();
          endTime = end.toUtc().toIso8601String();
        }

        final api = ref.read(groupApiServiceProvider);
        final res = await api.searchMessages(
          filter: query,
          groupId: widget.groupId,
          receiveUserId: widget.userId,
          messageType: messageType,
          formUserId: _selectedSenderId,
          startTime: startTime,
          endTime: endTime,
          maxResultCount: 50,
        );
        final itemsList = res['items'] as List<dynamic>? ?? [];
        resultItems = itemsList.map((e) => ImChatMessage.fromJson(e as Map<String, dynamic>)).toList();
      }
      
      if (mounted) {
        setState(() {
          _results = resultItems;
          _isLoading = false;
          _errorMsg = null;
        });
      }
    } catch (e) {
      AppLogger.error('[MessageSearch] Failed to search messages', e);
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
          _errorMsg = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6),
      appBar: _buildSearchBar(),
      body: Column(
        children: [
          _buildTabBar(),
          _buildFilters(),
          Expanded(
            child: _buildResultView(),
          ),
        ],
      ),
    );
  }
  
  PreferredSizeWidget _buildSearchBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF2F2F6),
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20, color: Color(0xFF111111)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Container(
        height: 36,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '搜索',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF999999)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel, size: 16, color: Color(0xFFCCCCCC)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchInput('');
                  },
                )
              : null,
          ),
          onChanged: _onSearchInput,
          textInputAction: TextInputAction.search,
          onSubmitted: _doSearch,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFFF2F2F6),
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF111111),
        unselectedLabelColor: const Color(0xFF999999),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        indicatorColor: const Color(0xFF111111),
        indicatorSize: TabBarIndicatorSize.label,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        tabs: const [
          Tab(text: '聊天记录'),
          Tab(text: '图片/视频'),
          Tab(text: '文件'),
          Tab(text: '链接'),
        ],
      ),
    );
  }
  
  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      color: const Color(0xFFF2F2F6),
      child: Wrap(
        spacing: 8,
        children: [
          _buildFilterChip(
            _selectedSenderName ?? '发送人', 
            Icons.arrow_drop_down,
            isActive: _selectedSenderId != null,
            onTap: _selectSender,
            onClear: () {
              setState(() {
                _selectedSenderId = null;
                _selectedSenderName = null;
              });
              _doSearch(_searchQuery);
            },
          ),
          _buildFilterChip(
            _selectedDateRange != null 
                ? '${_selectedDateRange!.start.year}-${_selectedDateRange!.start.month.toString().padLeft(2, '0')}-${_selectedDateRange!.start.day.toString().padLeft(2, '0')} 至 ${_selectedDateRange!.end.year}-${_selectedDateRange!.end.month.toString().padLeft(2, '0')}-${_selectedDateRange!.end.day.toString().padLeft(2, '0')}'
                : '时间', 
            Icons.arrow_drop_down,
            isActive: _selectedDateRange != null,
            onTap: _selectDateRange,
            onClear: () {
              setState(() {
                _selectedDateRange = null;
              });
              _doSearch(_searchQuery);
            },
          ),
          if (_tabController.index == 0) _buildFilterChip('@用户', Icons.arrow_drop_down),
          if (_tabController.index == 2) _buildFilterChip('钉盘上传', Icons.arrow_drop_down),
        ],
      ),
    );
  }

  Future<void> _selectSender() async {
    final results = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(
        builder: (_) => const UserSelectionPage(
          title: '选择发送人',
          multiSelect: false,
          confirmButtonText: '确定',
        ),
      ),
    );

    if (results != null && results.isNotEmpty) {
      final selected = results.first;
      setState(() {
        _selectedSenderId = selected['id']?.toString();
        _selectedSenderName = selected['name']?.toString() ?? selected['userName']?.toString();
      });
      _doSearch(_searchQuery); // Re-trigger search
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _selectedDateRange,
    );
    if (result != null) {
      setState(() {
        _selectedDateRange = result;
      });
      _doSearch(_searchQuery); // Re-trigger search
    }
  }

  Widget _buildFilterChip(String label, IconData icon, {bool isActive = false, VoidCallback? onTap, VoidCallback? onClear}) {
    return GestureDetector(
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label筛选功能开发中')));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE2EFFF) : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: const Color(0xFF0052D9)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: isActive ? const Color(0xFF0052D9) : const Color(0xFF666666))),
            const SizedBox(width: 4),
            if (isActive && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 14, color: Color(0xFF0052D9)),
              )
            else
              Icon(icon, size: 14, color: isActive ? const Color(0xFF0052D9) : const Color(0xFF999999)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaGrid() {
    // Group items by YYYY-MM
    Map<String, List<ImChatMessage>> grouped = {};
    for (var item in _results) {
      DateTime dt = DateTime.tryParse(item.sendTime) ?? DateTime.now();
      String key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    List<String> sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        String key = sortedKeys[index];
        List<ImChatMessage> groupItems = grouped[key] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                key, // e.g. "2024-05"
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: groupItems.length,
              itemBuilder: (ctx, idx) {
                return _MediaGridItem(
                  itemIndex: idx, 
                  mediaMessages: groupItems,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultView() {
    if (_isLoading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    
    if (_results.isEmpty) {
      if (_errorMsg != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error: $_errorMsg\n(Query length: ${_searchQuery.length})',
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      if (_searchQuery.isEmpty) {
        String typeLabel = "聊天记录";
        if (_tabController.index == 1) typeLabel = "图片/视频记录";
        if (_tabController.index == 2) typeLabel = "文件记录";
        if (_tabController.index == 3) typeLabel = "链接记录";

        return Center(
          child: Text(
            '最近暂无$typeLabel',
            style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
          ),
        );
      } else {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Color(0xFFCCCCCC)),
              SizedBox(height: 16),
              Text('没有搜索到相关内容', style: TextStyle(color: Color(0xFF999999), fontSize: 14)),
            ],
          ),
        );
      }
    }
    
    if (_tabController.index == 1) {
      return _buildMediaGrid();
    }

    final showAiAction = _searchQuery.isNotEmpty;
    final itemCount = showAiAction ? _results.length + 1 : _results.length;

    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        if (showAiAction && index == 0) {
          return _buildAiSearchAction();
        }
        
        final msg = showAiAction ? _results[index - 1] : _results[index];
        return _buildResultItem(msg);
      },
    );
  }

  Widget _buildAiSearchAction() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFFFF9500)],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('试试 AI 搜问 · 一键直达结果', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111111))),
            ],
          ),
          const SizedBox(height: 12),
          _buildAiPrompt('总结今天的讨论重点'),
          _buildAiPrompt('今天有哪些需要我跟进的事项'),
          _buildAiPrompt('把我分享的文件整理出来'),
        ],
      ),
    );
  }
  
  Widget _buildAiPrompt(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.search, size: 14, color: Color(0xFFCCCCCC)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
        ],
      ),
    );
  }

  Widget _buildResultItem(ImChatMessage msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              msg.formUserName.isNotEmpty ? msg.formUserName.characters.first : '?',
              style: const TextStyle(color: Color(0xFF0052D9), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Name > Group/Context + Time)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${msg.formUserName} ${widget.groupId != null ? ' > 群聊' : ''}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatTime(msg.sendTime),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Content Switcher based on tab
                _buildContentPreview(msg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPreview(ImChatMessage msg) {
    if (_tabController.index == 2) {
      // File
      String fileName = '未知文件';
      String fileSizeStr = '';
      String ext = '';
      if (msg.extraProperties != null) {
        fileName = msg.extraProperties!['fileName']?.toString() 
            ?? msg.extraProperties!['FileName']?.toString() 
            ?? msg.extraProperties!['name']?.toString() 
            ?? msg.extraProperties!['Name']?.toString() 
            ?? '未知文件';
        
        ext = msg.extraProperties!['fileExt']?.toString() 
            ?? msg.extraProperties!['FileExt']?.toString() 
            ?? _extFromName(fileName) ?? '';
        
        final sizeRaw = msg.extraProperties!['fileSize'] 
            ?? msg.extraProperties!['FileSize'] 
            ?? msg.extraProperties!['size']
            ?? msg.extraProperties!['Size'];
        if (sizeRaw != null) {
          final fs = double.tryParse(sizeRaw.toString()) ?? 0;
          if (fs > 1024 * 1024) {
            fileSizeStr = '${(fs / (1024 * 1024)).toStringAsFixed(1)} MB';
          } else if (fs > 1024) {
            fileSizeStr = '${(fs / 1024).toStringAsFixed(1)} KB';
          } else {
            fileSizeStr = '${fs.toInt()} B';
          }
        }
      }
      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FilePreviewPage(
                ossPath: msg.content,
                fileName: fileName,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: getFileIconColor(ext).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(getFileIcon(ext), color: getFileIconColor(ext), size: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fileName, style: const TextStyle(fontSize: 14, color: Color(0xFF111111)), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (fileSizeStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(fileSizeStr, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_tabController.index == 3) {
      // Link
      String title = '网页链接';
      String desc = msg.content;
      if (msg.extraProperties != null) {
        title = msg.extraProperties!['title']?.toString() ?? title;
        desc = msg.extraProperties!['description']?.toString() ?? desc;
      }
      return GestureDetector(
        onTap: () {
          // Could open the link using url_launcher
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FD),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.link, size: 16, color: Color(0xFF007AFF)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, color: Color(0xFF111111)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF999999)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // History (Text/Mixed)
      String displayText = msg.content;
      if (msg.messageType == ImMessageType.voice.value) {
        displayText = '[语音消息]';
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FilePreviewPage(ossPath: msg.content, fileName: '语音.mp3')),
            );
          },
          child: Row(
            children: [
              const Icon(Icons.audiotrack, size: 16, color: Color(0xFF999999)),
              const SizedBox(width: 4),
              Text(displayText, style: const TextStyle(fontSize: 14, color: Color(0xFF999999))),
            ],
          ),
        );
      } else if (msg.messageType == ImMessageType.image.value) {
        displayText = '[图片]';
      } else if (msg.messageType == ImMessageType.video.value) {
        displayText = '[视频]';
      } else if (msg.messageType == ImMessageType.file.value) {
        String fn = msg.extraProperties?['fileName'] as String? 
            ?? msg.extraProperties?['FileName'] as String? 
            ?? msg.extraProperties?['name'] as String? 
            ?? msg.extraProperties?['Name'] as String? 
            ?? '文件';
        displayText = '[文件] $fn';
      }

      return Text(
        displayText,
        style: const TextStyle(fontSize: 14, color: Color(0xFF111111)),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  static String? _extFromName(String? name) {
    if (name == null) return null;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1);
  }

  String _formatTime(String sendTimeStr) {
    if (sendTimeStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(sendTimeStr).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.month}月${dt.day}日';
    } catch (_) {
      return '';
    }
  }

  int _mapUiTypeToIm(MessageType uiType) {
    switch (uiType) {
      case MessageType.text: return ImMessageType.text.value;
      case MessageType.image: return ImMessageType.image.value;
      case MessageType.file: return ImMessageType.file.value;
      case MessageType.video: return ImMessageType.video.value;
      default: return ImMessageType.text.value;
    }
  }
}

class _MediaGridItem extends ConsumerStatefulWidget {
  final int itemIndex;
  final List<ImChatMessage> mediaMessages;

  const _MediaGridItem({required this.itemIndex, required this.mediaMessages});

  @override
  ConsumerState<_MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends ConsumerState<_MediaGridItem> {
  late Future<String> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _resolveThumbnail();
  }

  Future<String> _resolveThumbnail() async {
    final msg = widget.mediaMessages[widget.itemIndex];
    final ossPath = msg.content;
    if (ossPath.isEmpty) return '';
    final ossService = ref.read(ossUrlServiceProvider);
    
    if (msg.messageType == ImMessageType.video.value) {
      return await ossService.getFileUrl(ossPath);
    } else {
      return await ossService.getImageThumbnailUrl(ossPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.mediaMessages[widget.itemIndex];
    bool isVideo = msg.messageType == ImMessageType.video.value;
    
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          FadePageRoute(
            page: MediaGalleryPage(
              mediaMessages: widget.mediaMessages,
              initialIndex: widget.itemIndex,
              groupId: msg.groupId.isNotEmpty ? msg.groupId : null,
              isFromSearchPage: true,
            ),
          ),
        );
      },
      child: Container(
        color: Colors.grey[200],
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!isVideo)
              FutureBuilder<String>(
                future: _thumbnailFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return Icon(Icons.broken_image, color: Colors.grey[400], size: 30);
                  }
                  return Image.network(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey[400], size: 30),
                  );
                },
              )
            else
              Container(color: Colors.black87),
              
            if (isVideo)
              const Center(
                child: Icon(Icons.play_circle_outline, color: Colors.white, size: 30),
              ),
          ],
        ),
      ),
    );
  }
}
