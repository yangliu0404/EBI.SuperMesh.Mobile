import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/src/models/meeting_models.dart';
import 'package:ebi_chat/src/providers/meeting_providers.dart';
import 'package:ebi_chat/src/pages/meeting_room_page.dart';
import 'package:ebi_chat/src/pages/user_selection_page.dart';
import 'package:ebi_chat/src/services/meeting_invite_service.dart';

/// Schedule / create instant / view meeting detail page.
///
/// - `meeting == null && !isInstant` → Schedule new meeting
/// - `meeting == null && isInstant`  → Create instant meeting with settings
/// - `meeting != null`               → View existing meeting detail with participants
class ScheduleMeetingPage extends ConsumerStatefulWidget {
  final MeetingDto? meeting;
  final bool isInstant;

  const ScheduleMeetingPage({super.key, this.meeting, this.isInstant = false});

  bool get isNew => meeting == null;

  @override
  ConsumerState<ScheduleMeetingPage> createState() =>
      _ScheduleMeetingPageState();
}

class _ScheduleMeetingPageState extends ConsumerState<ScheduleMeetingPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _passwordController = TextEditingController();
  late DateTime _startTime;
  late DateTime _endTime;
  bool _requiresAdmission = false;
  bool _muteOnJoin = false;
  bool _disableCameraOnJoin = false;
  bool _hasPassword = false;
  bool _isSaving = false;
  bool _isJoining = false;

  // Selected participants (for new meetings)
  final List<Map<String, String>> _selectedParticipants = []; // [{id, name}]

  // For existing meetings: loaded data
  MeetingStatisticsDto? _statistics;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    if (widget.meeting != null) {
      final m = widget.meeting!;
      _titleController.text = m.title;
      _descController.text = m.description ?? '';
      final st = m.scheduledStartTime ?? m.actualStartTime;
      _startTime = st != null
          ? (DateTime.tryParse(st)?.toLocal() ?? _defaultStart())
          : _defaultStart();
      final et = m.actualEndTime;
      _endTime = et != null
          ? (DateTime.tryParse(et)?.toLocal() ?? _startTime.add(const Duration(hours: 1)))
          : _startTime.add(const Duration(hours: 1));
      _requiresAdmission = m.requiresAdmission;
      _muteOnJoin = m.settings?.muteOnJoin ?? false;
      _disableCameraOnJoin = m.settings?.disableCameraOnJoin ?? false;
      _hasPassword = m.hasPassword;
      _loadStatistics();
    } else {
      _startTime = _defaultStart();
      _endTime = _startTime.add(const Duration(hours: 1));
    }
  }

  DateTime _defaultStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, now.hour + 1);
  }

  Future<void> _loadStatistics() async {
    if (widget.meeting == null) return;
    setState(() => _isLoadingStats = true);
    try {
      final api = ref.read(meetingApiServiceProvider);
      final stats = await api.getStatistics(widget.meeting!.id);
      if (mounted) setState(() => _statistics = stats);
    } catch (e) {
      debugPrint('[MeetingDetail] loadStatistics error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Create / Save ──

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入会议标题')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final api = ref.read(meetingApiServiceProvider);

    try {
      final isInstant = widget.isInstant;
      final dto = CreateMeetingDto(
        title: title,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        type: isInstant ? MeetingType.instant : MeetingType.scheduled,
        scheduledStartTime:
            isInstant ? null : _startTime.toUtc().toIso8601String(),
        durationMinutes:
            isInstant ? null : _endTime.difference(_startTime).inMinutes,
        requiresAdmission: _requiresAdmission,
        muteOnJoin: _muteOnJoin,
        disableCameraOnJoin: _disableCameraOnJoin,
        password:
            _hasPassword ? _passwordController.text.trim() : null,
      );
      final meeting = await api.createMeeting(dto);

      // Invite selected participants
      for (final p in _selectedParticipants) {
        try {
          await inviteUserToMeeting(
            ref: ref,
            meeting: meeting,
            userId: p['id']!,
            userName: p['name'],
          );
        } catch (_) {}
      }
      if (!mounted) return;
      ref.read(meetingListProvider.notifier).refresh();

      if (isInstant) {
        final result = await api.joinMeeting(meeting.id);
        if (!mounted) return;
        if (result.token != null && result.token!.isNotEmpty) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => MeetingRoomPage(
              meeting: meeting,
              token: result.token!,
              liveKitServerUrl: result.liveKitServerUrl,
              roomName: result.roomName,
              initialMicMuted: _muteOnJoin,
              initialCameraOff: _disableCameraOnJoin,
            ),
          ));
        }
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('会议已预约')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _joinExistingMeeting() async {
    if (widget.meeting == null) return;
    setState(() => _isJoining = true);
    final api = ref.read(meetingApiServiceProvider);
    try {
      final result = await api.joinMeeting(widget.meeting!.id);
      if (!mounted) return;
      if (result.isWaiting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在等待主持人准入...')),
        );
        return;
      }
      if (result.token != null && result.token!.isNotEmpty) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入会议失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _inviteParticipants() async {
    if (widget.meeting == null) return;
    final result = await Navigator.of(context).push<List<Map<String, dynamic>>>(
      MaterialPageRoute(
        builder: (_) => UserSelectionPage(
          title: '邀请参会人员',
          multiSelect: true,
          disabledIds: _statistics?.participants.map((p) => p.userId).toSet(),
          confirmButtonText: '邀请',
        ),
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;

    int successCount = 0;
    for (final u in result) {
      final uid = (u['id'] ?? '').toString();
      final uname = (u['userName'] ?? u['name'] ?? '').toString();
      try {
        await inviteUserToMeeting(ref: ref, meeting: widget.meeting!, userId: uid, userName: uname);
        successCount++;
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已邀请 $successCount 人')));
      _loadStatistics(); // Refresh participant list
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _startTime : _endTime;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startTime = picked;
        if (_endTime.isBefore(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = picked;
      }
    });
  }

  String _fmtDt(DateTime dt) {
    final wd = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][dt.weekday - 1];
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}\n${dt.month}月${dt.day}日 $wd';
  }

  String _fmtIso(String? iso) {
    if (iso == null) return '-';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isNew = widget.isNew;
    final meeting = widget.meeting;

    return Scaffold(
      backgroundColor: EbiColors.bgMeshWork,
      appBar: AppBar(
        backgroundColor: EbiColors.white,
        foregroundColor: EbiColors.textPrimary,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isNew ? (widget.isInstant ? '发起会议' : '预约会议') : '会议详情',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (isNew)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EbiColors.primaryBlue,
                  foregroundColor: EbiColors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: EbiColors.white))
                    : Text(widget.isInstant ? '开始会议' : '完成'),
              ),
            ),
          if (!isNew && meeting != null)
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 22),
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: '会议号: ${meeting.meetingNo}'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('会议号已复制')),
                );
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          // ── Title ──
          _section(
            child: TextField(
              controller: _titleController,
              enabled: isNew,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: '添加标题',
                hintStyle:
                    TextStyle(color: EbiColors.textHint, fontSize: 18),
                border: InputBorder.none,
              ),
            ),
          ),

          // ── Meeting Info (existing) ──
          if (!isNew && meeting != null) ...[
            const SizedBox(height: 8),
            _section(
              child: Column(
                children: [
                  _infoTile(Icons.tag, '会议号', meeting.meetingNo),
                  const Divider(height: 1, indent: 40),
                  _infoTile(Icons.access_time, '时间', meeting.timeRange.isNotEmpty ? meeting.timeRange : _fmtIso(meeting.scheduledStartTime)),
                  const Divider(height: 1, indent: 40),
                  _infoTile(Icons.info_outline, '状态', _statusText(meeting.status)),
                  if (meeting.hasPassword) ...[
                    const Divider(height: 1, indent: 40),
                    _infoTile(Icons.lock_outline, '密码', '已设置'),
                  ],
                ],
              ),
            ),
          ],

          // ── Time Picker (new scheduled) ──
          if (isNew && !widget.isInstant) ...[
            const SizedBox(height: 8),
            _section(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 20, color: EbiColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDateTime(isStart: true),
                        child: Text(_fmtDt(_startTime),
                            style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                    const Icon(Icons.arrow_forward,
                        size: 16, color: EbiColors.textHint),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDateTime(isStart: false),
                        child: Text(_fmtDt(_endTime),
                            style: const TextStyle(fontSize: 15),
                            textAlign: TextAlign.end),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Participants (for new meetings) ──
          if (isNew) ...[
            const SizedBox(height: 8),
            _sectionTitle('参会人员'),
            _section(
              child: Column(
                children: [
                  ..._selectedParticipants.map((p) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: EbiColors.primaryBlue.withValues(alpha: 0.1),
                      child: Text((p['name'] ?? '?')[0].toUpperCase(), style: TextStyle(color: EbiColors.primaryBlue, fontSize: 12)),
                    ),
                    title: Text(p['name'] ?? '', style: const TextStyle(fontSize: 14)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16, color: EbiColors.textHint),
                      onPressed: () => setState(() => _selectedParticipants.remove(p)),
                    ),
                  )),
                  ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFF0F0F0),
                      child: Icon(Icons.add, size: 18, color: EbiColors.textSecondary),
                    ),
                    title: const Text('添加参会人员', style: TextStyle(fontSize: 14, color: EbiColors.primaryBlue)),
                    onTap: () async {
                      final result = await Navigator.of(context).push<List<Map<String, dynamic>>>(
                        MaterialPageRoute(
                          builder: (_) => UserSelectionPage(
                            title: '选择参会人员',
                            multiSelect: true,
                            initialSelectedIds: _selectedParticipants.map((p) => p['id']!).toSet(),
                            confirmButtonText: '确定',
                          ),
                        ),
                      );
                      if (result != null) {
                        setState(() {
                          _selectedParticipants.clear();
                          for (final u in result) {
                            _selectedParticipants.add({
                              'id': (u['id'] ?? '').toString(),
                              'name': (u['userName'] ?? u['name'] ?? '').toString(),
                            });
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ],

          // ── Settings ──
          const SizedBox(height: 8),
          _section(
            child: Column(
              children: [
                SwitchListTile(
                  secondary:
                      const Icon(Icons.lock_outline, size: 20),
                  title: const Text('入会需准入',
                      style: TextStyle(fontSize: 15)),
                  dense: true,
                  value: _requiresAdmission,
                  onChanged: isNew
                      ? (v) => setState(() => _requiresAdmission = v)
                      : null,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary:
                      const Icon(Icons.mic_off_outlined, size: 20),
                  title: const Text('入会时静音',
                      style: TextStyle(fontSize: 15)),
                  dense: true,
                  value: _muteOnJoin,
                  onChanged: isNew
                      ? (v) => setState(() => _muteOnJoin = v)
                      : null,
                ),
                const Divider(height: 1, indent: 56),
                SwitchListTile(
                  secondary:
                      const Icon(Icons.videocam_off_outlined, size: 20),
                  title: const Text('入会时关闭摄像头',
                      style: TextStyle(fontSize: 15)),
                  dense: true,
                  value: _disableCameraOnJoin,
                  onChanged: isNew
                      ? (v) => setState(() => _disableCameraOnJoin = v)
                      : null,
                ),
                if (isNew) ...[
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary:
                        const Icon(Icons.password_outlined, size: 20),
                    title: const Text('会议密码',
                        style: TextStyle(fontSize: 15)),
                    dense: true,
                    value: _hasPassword,
                    onChanged: (v) => setState(() => _hasPassword = v),
                  ),
                  if (_hasPassword)
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(56, 0, 16, 12),
                      child: TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          hintText: '输入会议密码',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),

          // ── Description ──
          const SizedBox(height: 8),
          _section(
            child: ListTile(
              leading: const Icon(Icons.description_outlined, size: 20),
              title: isNew
                  ? TextField(
                      controller: _descController,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: '添加描述',
                        hintStyle: TextStyle(color: EbiColors.textHint),
                        border: InputBorder.none,
                      ),
                    )
                  : Text(
                      meeting?.description ?? '无描述',
                      style: TextStyle(
                        color: meeting?.description != null
                            ? EbiColors.textPrimary
                            : EbiColors.textHint,
                      ),
                    ),
            ),
          ),

          // ── Participants (existing meeting) ──
          if (!isNew && _statistics != null) ...[
            const SizedBox(height: 8),
            _sectionTitle('参会人员 (${_statistics!.totalParticipants}人)'),
            _section(
              child: Column(
                children: [
                  ..._statistics!.participants.map((p) {
                    final isHost = p.role == 'Host';
                    final isCoHost = p.role == 'CoHost';
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: EbiColors.primaryBlue.withValues(alpha: 0.1),
                        child: Text(
                          (p.userName ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                              color: EbiColors.primaryBlue, fontSize: 14),
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(p.userName ?? p.userId,
                              style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                          if (isHost)
                            _roleBadge('主持人', EbiColors.primaryBlue),
                          if (isCoHost)
                            _roleBadge('联合主持人', EbiColors.secondaryCyan),
                        ],
                      ),
                      subtitle: Text(
                        '参会 ${p.formattedDuration}',
                        style: const TextStyle(
                            fontSize: 12, color: EbiColors.textHint),
                      ),
                      trailing: Text(
                        p.joinTime != null ? _fmtIso(p.joinTime) : '',
                        style: const TextStyle(
                            fontSize: 11, color: EbiColors.textHint),
                      ),
                    );
                  }),
                  // Invite button (for joinable meetings)
                  if (meeting!.isJoinable)
                    ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFFF0F0F0),
                        child: Icon(Icons.person_add, size: 18, color: EbiColors.primaryBlue),
                      ),
                      title: const Text('邀请更多人', style: TextStyle(fontSize: 14, color: EbiColors.primaryBlue)),
                      onTap: () => _inviteParticipants(),
                    ),
                ],
              ),
            ),
          ],

          if (!isNew && _isLoadingStats)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),

          // ── Meeting duration summary (ended) ──
          if (!isNew &&
              meeting != null &&
              meeting.status == MeetingStatus.ended &&
              _statistics != null) ...[
            const SizedBox(height: 8),
            _sectionTitle('会议统计'),
            _section(
              child: Column(
                children: [
                  _infoTile(Icons.timer_outlined, '总时长',
                      '${_statistics!.totalDurationMinutes} 分钟'),
                  const Divider(height: 1, indent: 40),
                  _infoTile(Icons.people_outline, '参会人数',
                      '${_statistics!.totalParticipants} 人'),
                  const Divider(height: 1, indent: 40),
                  _infoTile(Icons.play_arrow_outlined, '开始时间',
                      _fmtIso(_statistics!.startTime)),
                  const Divider(height: 1, indent: 40),
                  _infoTile(Icons.stop_outlined, '结束时间',
                      _fmtIso(_statistics!.endTime)),
                ],
              ),
            ),
          ],

          // ── Join Button ──
          if (!isNew && meeting != null && meeting.isJoinable)
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _joinExistingMeeting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EbiColors.primaryBlue,
                    foregroundColor: EbiColors.white,
                    disabledBackgroundColor:
                        EbiColors.primaryBlue.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: EbiColors.white))
                      : const Text('加入会议',
                          style: TextStyle(fontSize: 17)),
                ),
              ),
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _section({required Widget child}) {
    return Container(
      color: EbiColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: EbiColors.textSecondary)),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: EbiColors.textSecondary),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: EbiColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _roleBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, color: color)),
    );
  }

  String _statusText(MeetingStatus status) {
    return switch (status) {
      MeetingStatus.waiting => '待开始',
      MeetingStatus.inProgress => '进行中',
      MeetingStatus.ended => '已结束',
      MeetingStatus.cancelled => '已取消',
    };
  }
}
