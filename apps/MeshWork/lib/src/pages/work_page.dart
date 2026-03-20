import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_chat/ebi_chat.dart';

/// Work page — workbench with entries to various features.
class WorkPage extends StatelessWidget {
  const WorkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'Work', showBack: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Communication
          _SectionHeader(title: '协作工具'),
          const SizedBox(height: 8),
          _WorkbenchGrid(
            items: [
              _WorkbenchItem(
                icon: Icons.videocam_rounded,
                label: '会议',
                color: EbiColors.primaryBlue,
                onTap: () => _openMeetingList(context),
              ),
              _WorkbenchItem(
                icon: Icons.calendar_month_rounded,
                label: '日程',
                color: const Color(0xFF8B5CF6),
                onTap: () {},
              ),
              _WorkbenchItem(
                icon: Icons.task_alt_rounded,
                label: '任务',
                color: const Color(0xFF22C55E),
                onTap: () {},
              ),
              _WorkbenchItem(
                icon: Icons.description_rounded,
                label: '文档',
                color: const Color(0xFFF59E0B),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openMeetingList(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MeetingListPage(
          onJoinMeeting: () {
            Navigator.of(ctx).push(
              MaterialPageRoute(builder: (c) => const JoinMeetingPage()),
            );
          },
          onScheduleMeeting: () {
            Navigator.of(ctx).push(
              MaterialPageRoute(builder: (c) => const ScheduleMeetingPage()),
            );
          },
          onMeetingTap: (meeting) {
            Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (c) => ScheduleMeetingPage(meeting: meeting),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: EbiColors.textSecondary,
      ),
    );
  }
}

class _WorkbenchGrid extends StatelessWidget {
  final List<_WorkbenchItem> items;
  const _WorkbenchGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: items,
    );
  }
}

class _WorkbenchItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _WorkbenchItem({
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: EbiColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
