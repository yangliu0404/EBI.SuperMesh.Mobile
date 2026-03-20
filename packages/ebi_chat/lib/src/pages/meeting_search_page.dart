import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/models/meeting_models.dart';
import 'package:ebi_chat/src/providers/meeting_providers.dart';
import 'package:ebi_chat/src/pages/schedule_meeting_page.dart';

/// Full-featured meeting search page with multiple filter criteria.
class MeetingSearchPage extends ConsumerStatefulWidget {
  const MeetingSearchPage({super.key});

  @override
  ConsumerState<MeetingSearchPage> createState() => _MeetingSearchPageState();
}

class _MeetingSearchPageState extends ConsumerState<MeetingSearchPage> {
  final _keywordController = TextEditingController();
  String _keyword = '';
  MeetingStatus? _statusFilter;
  MeetingType? _typeFilter;
  DateTimeRange? _dateRange;
  bool _isLoading = false;
  List<MeetingDto> _results = [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final api = ref.read(meetingApiServiceProvider);
      final all = await api.getMyMeetings(
        status: _statusFilter?.index,
        fromDate: _dateRange?.start.toUtc().toIso8601String(),
        toDate: _dateRange?.end.toUtc().toIso8601String(),
        maxResultCount: 100,
      );

      var filtered = all;

      // Client-side keyword filter
      if (_keyword.isNotEmpty) {
        final q = _keyword.toLowerCase();
        filtered = filtered.where((m) {
          return m.title.toLowerCase().contains(q) ||
              m.meetingNo.contains(q) ||
              (m.description ?? '').toLowerCase().contains(q);
        }).toList();
      }

      // Client-side type filter
      if (_typeFilter != null) {
        filtered = filtered.where((m) => m.type == _typeFilter).toList();
      }

      setState(() => _results = filtered);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  void _clearAll() {
    setState(() {
      _keywordController.clear();
      _keyword = '';
      _statusFilter = null;
      _typeFilter = null;
      _dateRange = null;
      _results = [];
      _hasSearched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EbiColors.bgMeshWork,
      appBar: AppBar(
        backgroundColor: EbiColors.white,
        foregroundColor: EbiColors.textPrimary,
        elevation: 0.5,
        title: const Text('搜索会议',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          if (_hasSearched)
            TextButton(
              onPressed: _clearAll,
              child: const Text('重置',
                  style: TextStyle(color: EbiColors.primaryBlue)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: EbiColors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _keywordController,
              onChanged: (v) => _keyword = v.trim(),
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '搜索会议标题、会议号、描述...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _keywordController.clear();
                          setState(() => _keyword = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: EbiColors.bgMeshWork,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),

          // Filter chips
          Container(
            color: EbiColors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('全部状态', _statusFilter == null, () {
                        setState(() => _statusFilter = null);
                      }),
                      _filterChip('进行中', _statusFilter == MeetingStatus.inProgress, () {
                        setState(() => _statusFilter = MeetingStatus.inProgress);
                      }),
                      _filterChip('待开始', _statusFilter == MeetingStatus.waiting, () {
                        setState(() => _statusFilter = MeetingStatus.waiting);
                      }),
                      _filterChip('已结束', _statusFilter == MeetingStatus.ended, () {
                        setState(() => _statusFilter = MeetingStatus.ended);
                      }),
                      _filterChip('已取消', _statusFilter == MeetingStatus.cancelled, () {
                        setState(() => _statusFilter = MeetingStatus.cancelled);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Type filter + date range
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('全部类型', _typeFilter == null, () {
                        setState(() => _typeFilter = null);
                      }),
                      _filterChip('即时会议', _typeFilter == MeetingType.instant, () {
                        setState(() => _typeFilter = MeetingType.instant);
                      }),
                      _filterChip('预约会议', _typeFilter == MeetingType.scheduled, () {
                        setState(() => _typeFilter = MeetingType.scheduled);
                      }),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: Icon(
                          Icons.date_range,
                          size: 16,
                          color: _dateRange != null
                              ? EbiColors.primaryBlue
                              : EbiColors.textSecondary,
                        ),
                        label: Text(
                          _dateRange != null
                              ? '${_dateRange!.start.month}/${_dateRange!.start.day} - ${_dateRange!.end.month}/${_dateRange!.end.day}'
                              : '选择日期',
                          style: TextStyle(
                            fontSize: 12,
                            color: _dateRange != null
                                ? EbiColors.primaryBlue
                                : EbiColors.textSecondary,
                          ),
                        ),
                        onPressed: _pickDateRange,
                        side: BorderSide(
                          color: _dateRange != null
                              ? EbiColors.primaryBlue
                              : EbiColors.border,
                        ),
                      ),
                      if (_dateRange != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _dateRange = null),
                          child: const Icon(Icons.close,
                              size: 16, color: EbiColors.textHint),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search button
          Container(
            color: EbiColors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _search,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: EbiColors.white))
                    : const Icon(Icons.search, size: 18),
                label: const Text('搜索'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EbiColors.primaryBlue,
                  foregroundColor: EbiColors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),

          const Divider(height: 1),

          // Results
          Expanded(
            child: !_hasSearched
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 48, color: EbiColors.textHint),
                        SizedBox(height: 12),
                        Text('设置条件后点击搜索',
                            style: TextStyle(
                                color: EbiColors.textHint, fontSize: 14)),
                      ],
                    ),
                  )
                : _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? const Center(
                            child: EbiEmptyState(
                              icon: Icons.search_off,
                              title: '未找到匹配的会议',
                              subtitle: '请尝试修改搜索条件',
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (_, i) {
                              final m = _results[i];
                              return _SearchResultTile(
                                meeting: m,
                                keyword: _keyword,
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) =>
                                        ScheduleMeetingPage(meeting: m),
                                  ));
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? EbiColors.primaryBlue : EbiColors.bgMeshWork,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? EbiColors.white : EbiColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final MeetingDto meeting;
  final String keyword;
  final VoidCallback? onTap;

  const _SearchResultTile({
    required this.meeting,
    required this.keyword,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (meeting.status) {
      MeetingStatus.inProgress => EbiColors.success,
      MeetingStatus.waiting => EbiColors.warning,
      MeetingStatus.ended => EbiColors.textHint,
      MeetingStatus.cancelled => EbiColors.error,
    };
    final statusText = switch (meeting.status) {
      MeetingStatus.inProgress => '进行中',
      MeetingStatus.waiting => '待开始',
      MeetingStatus.ended => '已结束',
      MeetingStatus.cancelled => '已取消',
    };

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          meeting.type == MeetingType.scheduled
              ? Icons.calendar_today
              : Icons.videocam_outlined,
          color: statusColor,
          size: 18,
        ),
      ),
      title: Text(
        meeting.title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${meeting.meetingNo}  ·  ${meeting.timeRange.isNotEmpty ? meeting.timeRange : meeting.creationTime}',
            style:
                const TextStyle(fontSize: 11, color: EbiColors.textSecondary),
          ),
          if (meeting.description != null && meeting.description!.isNotEmpty)
            Text(
              meeting.description!,
              style: const TextStyle(fontSize: 11, color: EbiColors.textHint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(statusText,
            style: TextStyle(fontSize: 10, color: statusColor)),
      ),
    );
  }
}
