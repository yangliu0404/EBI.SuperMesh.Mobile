import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/ebi_chat.dart';
import 'package:mesh_work/src/pages/dashboard_page.dart';
import 'package:mesh_work/src/pages/project_page.dart';
import 'package:mesh_work/src/pages/work_page.dart';
import 'package:mesh_work/src/pages/profile_page.dart';

/// 5-Tab bottom navigation shell for MeshWork.
class AppShell extends ConsumerStatefulWidget {
  final VoidCallback? onLogout;
  final int currentIndex;
  final ValueChanged<int>? onTabChanged;

  const AppShell({
    super.key,
    this.onLogout,
    this.currentIndex = 0,
    this.onTabChanged,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    // Delay provider modifications to avoid "modified during build" error.
    Future.microtask(() {
      // Initialize notifications after login (only fetches once).
      ref.read(notificationsProvider.notifier).init();
      // Connect SignalR for real-time chat (fire-and-forget, errors are logged).
      ref.read(signalRConnectionProvider).connect().catchError((e) {
        AppLogger.error('[AppShell] SignalR connect failed', e);
      });
    });
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _currentIndex = widget.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _currentIndex == 1 ? const ProjectDrawer() : null,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const DashboardPage(),
          const ProjectPage(),
          const WorkPage(),
          ChatRoomListPage(
            onRoomTap: (roomId, roomName, unreadCount) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatDetailPage(
                    roomId: roomId,
                    roomName: roomName,
                    initialUnreadCount: unreadCount,
                  ),
                ),
              );
            },
          ),
          ProfilePage(onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          widget.onTabChanged?.call(index);
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: ref.L('Home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.folder_outlined),
            activeIcon: const Icon(Icons.folder),
            label: ref.L('Project'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.work_outline),
            activeIcon: const Icon(Icons.work),
            label: ref.L('Work'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.message_outlined),
            activeIcon: const Icon(Icons.message),
            label: ref.L('Message'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: ref.L('Me'),
          ),
        ],
      ),
    );
  }
}
