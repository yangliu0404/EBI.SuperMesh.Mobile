import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/src/models/poll_models.dart';
import 'package:ebi_chat/src/services/poll_api_service.dart';

/// Full poll panel for creating, voting, and viewing poll results in meetings.
class MeetingPollPanel extends ConsumerStatefulWidget {
  final String meetingId;
  final bool isHost;
  final VoidCallback onClose;

  const MeetingPollPanel({
    super.key,
    required this.meetingId,
    required this.isHost,
    required this.onClose,
  });

  @override
  ConsumerState<MeetingPollPanel> createState() => _MeetingPollPanelState();
}

class _MeetingPollPanelState extends ConsumerState<MeetingPollPanel> {
  late final PollApiService _api;
  List<MeetingPollDto> _polls = [];
  bool _isLoading = true;
  bool _showCreateForm = false;

  // Create form state
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  PollType _pollType = PollType.singleChoice;
  bool _isAnonymous = false;
  bool _isCreating = false;

  // Vote state
  final Map<String, Set<String>> _selectedOptions = {};

  @override
  void initState() {
    super.initState();
    _api = PollApiService(apiClient: ref.read(apiClientProvider));
    _loadPolls();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPolls() async {
    setState(() => _isLoading = true);
    try {
      final polls = await _api.getPolls(widget.meetingId);
      if (mounted) setState(() => _polls = polls);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _createPoll() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty) return;
    final options = _optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('至少需要2个选项')));
      return;
    }

    setState(() => _isCreating = true);
    try {
      await _api.createPoll(
        widget.meetingId,
        CreatePollDto(question: question, pollType: _pollType, isAnonymous: _isAnonymous, options: options),
      );
      _questionCtrl.clear();
      for (final c in _optionCtrls) {
        c.clear();
      }
      setState(() => _showCreateForm = false);
      await _loadPolls();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
    }
    if (mounted) setState(() => _isCreating = false);
  }

  Future<void> _vote(MeetingPollDto poll) async {
    final selected = _selectedOptions[poll.id];
    if (selected == null || selected.isEmpty) return;
    try {
      await _api.vote(widget.meetingId, poll.id, selected.toList());
      await _loadPolls();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('投票失败: $e')));
    }
  }

  Future<void> _closePoll(String pollId) async {
    try {
      await _api.closePoll(widget.meetingId, pollId);
      await _loadPolls();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('关闭失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0, top: 0, bottom: 60, width: 300,
      child: Container(
        color: const Color(0xFF1A202C),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                const Text('投票', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (widget.isHost)
                  GestureDetector(
                    onTap: () => setState(() => _showCreateForm = !_showCreateForm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: EbiColors.primaryBlue, borderRadius: BorderRadius.circular(12)),
                      child: Text(_showCreateForm ? '取消' : '发起投票', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                const SizedBox(width: 8),
                GestureDetector(onTap: widget.onClose, child: const Icon(Icons.close, color: Colors.white54, size: 20)),
              ]),
            ),
            const Divider(height: 1, color: Colors.white12),

            // Content
            Expanded(
              child: _showCreateForm
                  ? _buildCreateForm()
                  : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _polls.isEmpty
                          ? const Center(child: Text('暂无投票', style: TextStyle(color: Colors.white38)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _polls.length,
                              itemBuilder: (_, i) => _buildPollCard(_polls[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Create Form ──

  Widget _buildCreateForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          TextField(
            controller: _questionCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _inputDeco('投票问题'),
          ),
          const SizedBox(height: 12),

          // Options
          ..._optionCtrls.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: TextField(controller: e.value, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: _inputDeco('选项 ${e.key + 1}'))),
                    if (_optionCtrls.length > 2)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                        onPressed: () => setState(() { _optionCtrls[e.key].dispose(); _optionCtrls.removeAt(e.key); }),
                      ),
                  ],
                ),
              )),

          if (_optionCtrls.length < 10)
            TextButton.icon(
              onPressed: () => setState(() => _optionCtrls.add(TextEditingController())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加选项', style: TextStyle(fontSize: 12)),
            ),

          const SizedBox(height: 12),

          // Settings
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _pollType = PollType.singleChoice),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _pollType == PollType.singleChoice ? EbiColors.primaryBlue : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('单选', textAlign: TextAlign.center, style: TextStyle(color: _pollType == PollType.singleChoice ? Colors.white : Colors.white54, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _pollType = PollType.multipleChoice),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _pollType == PollType.multipleChoice ? EbiColors.primaryBlue : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('多选', textAlign: TextAlign.center, style: TextStyle(color: _pollType == PollType.multipleChoice ? Colors.white : Colors.white54, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('匿名投票', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              Switch(
                value: _isAnonymous,
                onChanged: (v) => setState(() => _isAnonymous = v),
                activeColor: EbiColors.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createPoll,
              style: ElevatedButton.styleFrom(backgroundColor: EbiColors.primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: _isCreating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('发起投票'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  // ── Poll Card ──

  Widget _buildPollCard(MeetingPollDto poll) {
    final maxVotes = poll.options.fold<int>(0, (max, o) => o.voteCount > max ? o.voteCount : max);
    final hasVoted = poll.hasVoted;
    final isClosed = !poll.isActive;
    final showResults = hasVoted || isClosed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question
          Row(
            children: [
              Expanded(child: Text(poll.question, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isClosed ? Colors.red.withValues(alpha: 0.2) : EbiColors.success.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(isClosed ? '已结束' : '进行中', style: TextStyle(fontSize: 10, color: isClosed ? Colors.red : EbiColors.success)),
              ),
            ],
          ),
          Text(
            '${poll.pollType == PollType.singleChoice ? '单选' : '多选'}${poll.isAnonymous ? ' · 匿名' : ''} · ${poll.totalVotes}票',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 10),

          // Options
          ...poll.options.map((opt) {
            final isSelected = _selectedOptions[poll.id]?.contains(opt.id) ?? false;
            final wasVoted = poll.myVotedOptionIds.contains(opt.id);
            final pct = poll.totalVotes > 0 ? (opt.voteCount / poll.totalVotes * 100).round() : 0;
            final barWidth = maxVotes > 0 ? opt.voteCount / maxVotes : 0.0;

            if (showResults) {
              // Result view
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (wasVoted) const Icon(Icons.check_circle, color: EbiColors.primaryBlue, size: 14),
                        if (wasVoted) const SizedBox(width: 4),
                        Expanded(child: Text(opt.text, style: TextStyle(color: wasVoted ? EbiColors.primaryBlue : Colors.white70, fontSize: 13))),
                        Text('${opt.voteCount}票 ($pct%)', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: barWidth,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        color: wasVoted ? EbiColors.primaryBlue : Colors.white.withValues(alpha: 0.3),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // Vote selection view
              return GestureDetector(
                onTap: () {
                  setState(() {
                    final set = _selectedOptions.putIfAbsent(poll.id, () => {});
                    if (poll.pollType == PollType.singleChoice) {
                      set.clear();
                      set.add(opt.id);
                    } else {
                      if (set.contains(opt.id)) {
                        set.remove(opt.id);
                      } else {
                        set.add(opt.id);
                      }
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? EbiColors.primaryBlue.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? EbiColors.primaryBlue : Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        poll.pollType == PollType.singleChoice
                            ? (isSelected ? Icons.radio_button_checked : Icons.radio_button_off)
                            : (isSelected ? Icons.check_box : Icons.check_box_outline_blank),
                        color: isSelected ? EbiColors.primaryBlue : Colors.white38,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(opt.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              );
            }
          }),

          // Actions
          if (!hasVoted && poll.isActive) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedOptions[poll.id]?.isNotEmpty ?? false) ? () => _vote(poll) : null,
                style: ElevatedButton.styleFrom(backgroundColor: EbiColors.primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('投票', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
          if (widget.isHost && poll.isActive) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _closePoll(poll.id),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('关闭投票', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
