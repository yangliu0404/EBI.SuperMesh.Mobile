import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  late TabController _tabController;
  final List<String> _modules = [
    'All',
    'Projects',
    'RFQ',
    'Orders',
    'Shipment',
  ];

  // Mock search history
  List<String> _searchHistory = [
    'Electric Motor',
    'CNC Machining',
    'Test Project A',
  ];

  bool _isSearching = false;
  String _currentQuery = '';
  bool _isEditingHistory = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _modules.length, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _currentQuery = query.trim();
      _isSearching = true;
      if (!_searchHistory.contains(_currentQuery)) {
        _searchHistory.insert(0, _currentQuery);
      }
    });
    // Remove focus to hide keyboard
    _searchFocus.unfocus();
  }

  void _fillSearchAndSubmit(String text) {
    _searchController.text = text;
    // Set cursor to the end of the text
    _searchController.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
    _onSearchSubmitted(text);
  }

  void _clearHistory() {
    setState(() {
      _searchHistory.clear();
      _isEditingHistory = false;
    });
  }

  void _deleteHistoryItem(String item) {
    setState(() {
      _searchHistory.remove(item);
      if (_searchHistory.isEmpty) {
        _isEditingHistory = false;
      }
    });
  }

  void _toggleEditHistory() {
    setState(() {
      _isEditingHistory = !_isEditingHistory;
    });
  }

  void _cancelSearch() {
    if (_isSearching) {
      setState(() {
        _isSearching = false;
        _currentQuery = '';
        _searchController.clear();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EbiColors.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: _buildSearchBar(),
        actions: [
          TextButton(
            onPressed: _cancelSearch,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '取消', // Cancel
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
        ],
        bottom: _isSearching
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                dividerColor: Colors.transparent,
                tabs: _modules.map((m) => Tab(text: m)).toList(),
              )
            : null,
      ),
      body: _isSearching ? _buildSearchResults() : _buildDefaultState(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(left: 4, right: 4), // Balanced minimal margins
      decoration: BoxDecoration(
        color: Colors.white, // Solid white background
        borderRadius: BorderRadius.circular(19),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 12, right: 6),
            child: Icon(Icons.search, color: Colors.grey, size: 20),
          ),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                // Ensure no background or weird borders are inherited
                inputDecorationTheme: const InputDecorationTheme(
                  filled: false,
                  border: InputBorder.none,
                ),
                textSelectionTheme: const TextSelectionThemeData(
                  cursorColor: EbiColors.primaryBlue,
                  selectionColor: Colors.black12,
                  selectionHandleColor: EbiColors.primaryBlue,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                autofocus: true,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                cursorColor: EbiColors.primaryBlue,
                textAlignVertical: TextAlignVertical.center,
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearchSubmitted,
                onChanged: (val) {
                  setState(() {}); 
                  if (val.isEmpty && _isSearching) {
                    setState(() {
                      _isSearching = false;
                      _currentQuery = '';
                    });
                  }
                },
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '搜索项目、业务号或订单等',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  // Explicitly providing right padding so text never touches the container's right edge
                  contentPadding: EdgeInsets.only(top: 10, bottom: 10, right: 12), 
                ),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _isSearching = false;
                  _currentQuery = '';
                  _searchFocus.requestFocus();
                });
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 2, right: 12), // Reduced spacing specifically around the cancel button
                child: Icon(Icons.cancel, color: Colors.grey, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultState() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchHistory(),
          const SizedBox(height: 16),
          // We can also have placeholders for Hot Searches or Suggested Categories here
          _buildSuggestedCategories(),
        ],
      ),
    );
  }

  Widget _buildSearchHistory() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '历史搜索', // Search History
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_searchHistory.isNotEmpty)
                _isEditingHistory
                    ? Row(
                        children: [
                          TextButton(
                            onPressed: _clearHistory,
                            child: const Text('删除全部', style: TextStyle(color: Colors.red)),
                          ),
                          TextButton(
                            onPressed: _toggleEditHistory,
                            child: const Text('完成', style: TextStyle(color: EbiColors.primaryBlue)),
                          ),
                        ],
                      )
                    : IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.grey),
                        onPressed: _toggleEditHistory,
                        tooltip: 'Edit history',
                      ),
            ],
          ),
          const SizedBox(height: 8),
          if (_searchHistory.isEmpty)
            const Text('暂无搜索历史', style: TextStyle(color: Colors.grey))
          else
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _searchHistory.map((historyItem) {
                return _isEditingHistory
                    ? InputChip(
                        label: Text(historyItem),
                        backgroundColor: Colors.grey.withOpacity(0.1),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onDeleted: () => _deleteHistoryItem(historyItem),
                        deleteIcon: const Icon(Icons.close, size: 16, color: Colors.grey),
                      )
                    : ActionChip(
                        label: Text(historyItem),
                        backgroundColor: Colors.grey.withOpacity(0.1),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        // Adjust padding to make the chip slightly more compact
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: () => _fillSearchAndSubmit(historyItem),
                      );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestedCategories() {
    // Placeholder for Hot Searches or Categories
    final List<String> hots = ['PCB', 'Motor', 'Assembly', 'Plastics', 'Fasteners'];
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '热门搜索', // Hot Searches
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: hots.map((item) {
              return ActionChip(
                label: Text(item, style: TextStyle(color: EbiColors.primaryBlue)),
                backgroundColor: EbiColors.primaryBlue.withOpacity(0.05),
                side: BorderSide(color: EbiColors.primaryBlue.withOpacity(0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onPressed: () => _fillSearchAndSubmit(item),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return TabBarView(
      controller: _tabController,
      children: _modules.map((module) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 5,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: EbiColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_outlined, color: EbiColors.primaryBlue),
                ),
                title: Text('搜索结果 ${index + 1} - \'$_currentQuery\''),
                subtitle: Text('分类：$module • 描述或详情说明此项的内容'),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  // TODO: Navigate to details
                },
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
