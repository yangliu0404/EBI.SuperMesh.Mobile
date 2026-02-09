import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';

void main() {
  runApp(const MeshPortalApp());
}

class MeshPortalApp extends StatelessWidget {
  const MeshPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeshPortal',
      theme: EbiTheme.meshPortal(),
      debugShowCheckedModeBanner: false,
      home: const MeshPortalHome(),
    );
  }
}

class MeshPortalHome extends StatefulWidget {
  const MeshPortalHome({super.key});

  @override
  State<MeshPortalHome> createState() => _MeshPortalHomeState();
}

class _MeshPortalHomeState extends State<MeshPortalHome> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _HomePage(),
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Updates',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

// ── Placeholder Pages ──

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'MeshPortal', showBack: false),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.public,
              size: 80,
              color: EbiColors.primaryBlue,
            ),
            const SizedBox(height: 24),
            Text('Welcome to MeshPortal', style: EbiTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              'Your Supply Chain at a Glance',
              style: EbiTextStyles.bodyMedium,
            ),
            const SizedBox(height: 32),
            EbiButton(
              text: 'View Projects',
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
      appBar: const EbiAppBar(title: 'My Orders', showBack: false),
      body: const EbiEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No Orders',
        subtitle: 'Your orders and quotations will appear here.',
      ),
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'Updates', showBack: false),
      body: const EbiEmptyState(
        icon: Icons.notifications_outlined,
        title: 'No Updates',
        subtitle: 'Project updates and notifications will appear here.',
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EbiAppBar(title: 'Account', showBack: false),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: EbiColors.secondaryCyan,
              child: const Icon(Icons.business, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text('Client Company', style: EbiTextStyles.h3),
            const SizedBox(height: 4),
            Text('client@company.com', style: EbiTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
