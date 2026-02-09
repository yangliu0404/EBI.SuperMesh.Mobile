import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

void main() {
  runApp(const MeshWorkApp());
}

class MeshWorkApp extends StatelessWidget {
  const MeshWorkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshWork',
      theme: EbiTheme.meshWork(),
      debugShowCheckedModeBanner: false,
      home: const MeshWorkHome(),
    );
  }
}

class MeshWorkHome extends StatefulWidget {
  const MeshWorkHome({super.key});

  @override
  State<MeshWorkHome> createState() => _MeshWorkHomeState();
}

class _MeshWorkHomeState extends State<MeshWorkHome> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _DashboardPage(),
    _OrdersPage(),
    _NotificationsPage(),
    _ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ── Placeholder Pages ──

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'MeshWork', showBack: false),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.engineering,
              size: 80,
              color: EbiColors.primaryBlue,
            ),
            const SizedBox(height: 24),
            Text('Welcome to MeshWork', style: EbiTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'e-bi Employee Mobile Office',
              style: EbiTextStyles.bodyMedium,
            ),
            const SizedBox(height: 32),
            EbiButton(
              text: 'Get Started',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersPage extends StatelessWidget {
  const _OrdersPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'Orders', showBack: false),
      body: const EbiEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No Orders Yet',
        subtitle: 'Your assigned orders will appear here.',
      ),
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'Alerts', showBack: false),
      body: const EbiEmptyState(
        icon: Icons.notifications_outlined,
        title: 'All Caught Up',
        subtitle: 'No new alerts or notifications.',
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'Profile', showBack: false),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: EbiColors.primaryBlue,
              child: const Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text('Employee Name', style: EbiTextStyles.h3),
            const SizedBox(height: 4),
            Text('employee@e-bi.com', style: EbiTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
