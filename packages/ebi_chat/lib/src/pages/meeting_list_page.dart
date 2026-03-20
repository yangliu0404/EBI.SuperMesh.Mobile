import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/models/meeting_models.dart';
import 'package:ebi_chat/src/providers/meeting_providers.dart';
import 'package:ebi_chat/src/pages/schedule_meeting_page.dart';
import 'package:ebi_chat/src/pages/meeting_search_page.dart';
import 'package:ebi_chat/src/pages/meeting_room_page.dart';

/// Meeting list page with quick actions, status filters, date grouping, and search.
class MeetingListPage extends ConsumerStatefulWidget {
  final VoidCallback? onJoinMeeting;
  final VoidCallback? onScheduleMeeting;
  final ValueChanged<MeetingDto>? onMeetingTap;

  const MeetingListPage({
    super.key,
    this.onJoinMeeting,
    this.onScheduleMeeting,
    this.onMeetingTap,
  });

  @override
  ConsumerState<MeetingListPage> createState() => _MeetingListPageState();
}

class _MeetingListPageState extends ConsumerState<MeetingListPage> {
  int _filterIndex = 0; // 0=All, 1=InProgress, 2=Waiting, 3=Ended
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateRange;

  static const _filters = [
    _FilterTab('全部', null),
    _FilterTab('进行中', MeetingStatus.inProgress),
    _FilterTab('待开始', MeetingStatus.waiting),
    _FilterTab('已结束', MeetingStatus.ended),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(meetingListProvider.notifier).loadMeetings();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MeetingDto> get _filteredMeetings {
    var list = ref.read(meetingListProvider).meetings;

    // Status filter
    final statusFilter = _filters[_filterIndex].status;
    if (statusFilter != null) {
      list = list.where((m) => m.status == statusFilter).toList();
    }

    // Date range filter
    if (_dateRange != null) {
      list = list.where((m) {
        final t = m.actualStartTime ?? m.scheduledStartTime ?? m.creationTime;
        final dt = DateTime.tryParse(t);
        if (dt == null) return false;
        final local = dt.toLocal();
        return !local.isBefore(_dateRange!.start) &&
            !local.isAfter(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Text search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((m) {
        return m.title.toLowerCase().contains(q) ||
            m.meetingNo.contains(q) ||
            (m.description ?? '').toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  /// Group meetings by date (today, yesterday, or date string).
  Map<String, List<MeetingDto>> _groupByDate(List<MeetingDto> meetings) {
    final groups = <String, List<MeetingDto>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final m in meetings) {
      final raw = m.actualStartTime ?? m.scheduledStartTime ?? m.creationTime;
      final dt = DateTime.tryParse(raw)?.toLocal();
      String key;
      if (dt == null) {
        key = '未知日期';
      } else {
        final d = DateTime(dt.year, dt.month, dt.day);
        if (d == today) {
          key = '今天';
        } else if (d == yesterday) {
          key = '昨天';
        } else if (d.year == now.year) {
          key = '${dt.month}月${dt.day}日';
        } else {
          key = '${dt.year}年${dt.month}月${dt.day}日';
        }
      }
      groups.putIfAbsent(key, () => []).add(m);
    }
    return groups;
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

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(meetingListProvider);
    final filtered = _filteredMeetings;
    final grouped = _groupByDate(filtered);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: EbiColors.primaryBlue,
        foregroundColor: EbiColors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('会议',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MeetingSearchPage(),
              ));
            },
          ),
          // Date range filter
          IconButton(
            icon: Icon(
              Icons.date_range,
              color: _dateRange != null
                  ? Colors.yellowAccent
                  : EbiColors.white,
            ),
            onPressed: () async {
              if (_dateRange != null) {
                // Clear date filter
                setState(() => _dateRange = null);
              } else {
                await _pickDateRange();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick actions
          _QuickActions(
            onStartMeeting: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const ScheduleMeetingPage(isInstant: true)),
            ),
            onJoinMeeting: widget.onJoinMeeting,
            onScheduleMeeting: widget.onScheduleMeeting,
          ),

          // Rejoin banner
          _RejoinBanner(
            onRejoin: (info) async {
              ref.read(leftMeetingProvider.notifier).clear();
              final api = ref.read(meetingApiServiceProvider);
              try {
                final result = await api.joinMeeting(info.meetingId);
                if (!mounted) return;
                if (result.token != null && result.token!.isNotEmpty) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MeetingRoomPage(
                      meeting: result.meeting,
                      token: result.token!,
                      liveKitServerUrl: result.liveKitServerUrl,
                      roomName: result.roomName,
                    ),
                  ));
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重新加入失败: $e')));
              }
            },
          ),

          // Status filter tabs
          _StatusFilterBar(
            currentIndex: _filterIndex,
            filters: _filters,
            onChanged: (i) => setState(() => _filterIndex = i),
          ),

          // Date range indicator
          if (_dateRange != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: EbiColors.primaryBlue.withValues(alpha: 0.05),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 14, color: EbiColors.primaryBlue),
                  const SizedBox(width: 6),
                  Text(
                    '${_dateRange!.start.month}/${_dateRange!.start.day} - ${_dateRange!.end.month}/${_dateRange!.end.day}',
                    style: const TextStyle(fontSize: 12, color: EbiColors.primaryBlue),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _dateRange = null),
                    child: const Icon(Icons.close, size: 16, color: EbiColors.primaryBlue),
                  ),
                ],
              ),
            ),

          // Meeting list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(meetingListProvider.notifier).refresh(),
              child: listState.isLoading && listState.meetings.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            EbiEmptyState(
                              icon: Icons.videocam_off_outlined,
                              title: '暂无会议',
                              subtitle: '点击上方按钮发起或加入会议',
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: grouped.length,
                          itemBuilder: (ctx, groupIdx) {
                            final dateKey = grouped.keys.elementAt(groupIdx);
                            final meetings = grouped[dateKey]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date group header
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                  child: Text(
                                    dateKey,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: EbiColors.textSecondary,
                                    ),
                                  ),
                                ),
                                ...meetings.map((m) => _MeetingTile(
                                      meeting: m,
                                      onTap: () => widget.onMeetingTap?.call(m),
                                    )),
                              ],
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Filter Bar ──

class _FilterTab {
  final String label;
  final MeetingStatus? status;
  const _FilterTab(this.label, this.status);
}

class _StatusFilterBar extends StatelessWidget {
  final int currentIndex;
  final List<_FilterTab> filters;
  final ValueChanged<int> onChanged;

  const _StatusFilterBar({
    required this.currentIndex,
    required this.filters,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(filters.length, (i) {
          final selected = i == currentIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? EbiColors.primaryBlue
                      : EbiColors.bgMeshWork,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  filters[i].label,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? EbiColors.white : EbiColors.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Quick Actions ──

class _QuickActions extends StatelessWidget {
  final VoidCallback? onStartMeeting;
  final VoidCallback? onJoinMeeting;
  final VoidCallback? onScheduleMeeting;

  const _QuickActions({
    this.onStartMeeting,
    this.onJoinMeeting,
    this.onScheduleMeeting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: Icons.videocam_rounded,
            label: '发起会议',
            color: EbiColors.primaryBlue,
            onTap: onStartMeeting,
          ),
          _ActionButton(
            icon: Icons.add_box_rounded,
            label: '加入会议',
            color: const Color(0xFF22C55E),
            onTap: onJoinMeeting,
          ),
          _ActionButton(
            icon: Icons.calendar_month_rounded,
            label: '预约会议',
            color: const Color(0xFF8B5CF6),
            onTap: onScheduleMeeting,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label,
                style:
                    const TextStyle(fontSize: 12, color: EbiColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

// ── Meeting Tile ──

class _MeetingTile extends StatelessWidget {
  final MeetingDto meeting;
  final VoidCallback? onTap;

  const _MeetingTile({required this.meeting, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          meeting.type == MeetingType.scheduled
              ? Icons.calendar_today_rounded
              : Icons.videocam_outlined,
          color: _statusColor,
          size: 20,
        ),
      ),
      title: Text(
        meeting.title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            meeting.timeRange.isNotEmpty ? meeting.timeRange : meeting.meetingNo,
            style: const TextStyle(fontSize: 12, color: EbiColors.textSecondary),
          ),
          if (meeting.hasPassword) ...[
            const SizedBox(width: 6),
            const Icon(Icons.lock, size: 12, color: EbiColors.textHint),
          ],
        ],
      ),
      trailing: _buildStatusBadge(),
    );
  }

  Color get _statusColor => switch (meeting.status) {
        MeetingStatus.inProgress => EbiColors.success,
        MeetingStatus.waiting => EbiColors.warning,
        MeetingStatus.ended => EbiColors.textHint,
        MeetingStatus.cancelled => EbiColors.error,
      };

  Widget _buildStatusBadge() {
    final color = _statusColor;
    final text = switch (meeting.status) {
      MeetingStatus.inProgress => '进行中',
      MeetingStatus.waiting => '待开始',
      MeetingStatus.ended => '已结束',
      MeetingStatus.cancelled => '已取消',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

// ── Rejoin Banner ──

class _RejoinBanner extends ConsumerWidget {
  final void Function(LeftMeetingInfo info) onRejoin;

  const _RejoinBanner({required this.onRejoin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leftMeeting = ref.watch(leftMeetingProvider);
    if (leftMeeting == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: EbiColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leftMeeting.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const Text('会议仍在进行中，要重新加入吗？', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onRejoin(leftMeeting),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: EbiColors.success, borderRadius: BorderRadius.circular(8)),
              child: const Text('重新加入', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => ref.read(leftMeetingProvider.notifier).clear(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Text('关闭', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
