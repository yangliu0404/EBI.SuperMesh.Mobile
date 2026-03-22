import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebi_core/ebi_core.dart';
import 'package:ebi_chat/ebi_chat.dart';
import 'package:mesh_portal/src/pages/home_page.dart';
import 'package:mesh_portal/src/pages/orders_page.dart';
import 'package:mesh_portal/src/pages/notifications_page.dart';
import 'package:mesh_portal/src/pages/profile_page.dart';

/// 5-Tab bottom navigation shell for MeshPortal.
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
    // Initialize notifications after login (only fetches once).
    ref.read(notificationsProvider.notifier).init();
    // Connect SignalR for real-time chat (fire-and-forget, errors are logged).
    ref.read(signalRConnectionProvider).connect().catchError((e) {
      AppLogger.error('[AppShell] SignalR connect failed', e);
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomePage(),
          const OrdersPage(),
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
          const NotificationsPage(),
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
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long),
            label: ref.L('Orders'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            activeIcon: const Icon(Icons.chat_bubble),
            label: ref.L('Messages'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.notifications_outlined),
            activeIcon: const Icon(Icons.notifications),
            label: ref.L('Updates'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: ref.L('Account'),
          ),
        ],
      ),
    );
  }
}
