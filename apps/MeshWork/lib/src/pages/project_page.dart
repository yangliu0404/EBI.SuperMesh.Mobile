import 'package:flutter/material.dart';
import 'package:ebi_ui_kit/ebi_ui_kit.dart';
import 'package:ebi_core/ebi_core.dart';
import 'search_page.dart';

/// Project page placeholder.
class ProjectPage extends StatefulWidget {
  const ProjectPage({super.key});

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'Home',
    'RFQ',
    'Order',
    'Lot',
    'Shipment',
    'Buyer',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: EbiColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        titleSpacing: 0,
        title: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          dividerColor: Colors.transparent,
          tabs: _tabs.map((t) => Tab(text: context.L(t))).toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              return EbiEmptyState(
                icon: Icons.folder_outlined,
                title: context.L(tab),
                subtitle: context.L('NoProjectsDescription'),
              );
            }).toList(),
          ),
          // Intercept edge swipes to manually pop open the outer Scaffold's drawer.
          // This overrides the TabBarView which greedily swallows horizontal gestures.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 24,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // Opaque physically blocks TabBarView from getting this touch event
              onHorizontalDragUpdate: (details) {
                // Any rightward swipe immediately triggers the parent drawer
                if (details.delta.dx > 0) {
                  Scaffold.of(context).openDrawer();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectDrawer extends StatefulWidget {
  const ProjectDrawer({super.key});

  @override
  State<ProjectDrawer> createState() => _ProjectDrawerState();
}

class _ProjectDrawerState extends State<ProjectDrawer>
    with SingleTickerProviderStateMixin {
  late TabController _drawerTabController;
  
  // placeholder tabs for the drawer
  final List<String> _drawerTabs = [
    'Favorites',
    'Recent',
    'Archive',
  ];

  @override
  void initState() {
    super.initState();
    _drawerTabController =
        TabController(length: _drawerTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _drawerTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Tabs
            TabBar(
              controller: _drawerTabController,
              labelColor: EbiColors.primaryBlue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: EbiColors.primaryBlue,
              dividerColor: Colors.grey.withOpacity(0.2),
              tabs: _drawerTabs.map((t) => Tab(text: t)).toList(),
            ),
            // Drawer Tab Contents
            Expanded(
              child: TabBarView(
                controller: _drawerTabController,
                children: [
                  // Favorites (Starred) Projects List
                  ListView.builder(
                    itemCount: 8,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(
                          Icons.star, 
                          color: Colors.orangeAccent
                        ),
                        title: Text('Starred Project ${index + 1}'),
                        subtitle: Text('Details for project ${index + 1}'),
                        onTap: () {
                          // TODO: Quick jump to corresponding page
                          Navigator.pop(context); // Close the drawer
                        },
                      );
                    },
                  ),
                  // Placeholder 1
                  const Center(
                    child: Text(
                      'Recent (Placeholder)', 
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  // Placeholder 2
                  const Center(
                    child: Text(
                      'Archive (Placeholder)', 
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Bottom-left Icon Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Colors.grey),
                    tooltip: 'Settings',
                    onPressed: () {
                      // TODO: Navigate to settings
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.grey),
                    tooltip: 'Filter',
                    onPressed: () {
                      // TODO: Show filters
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.grey),
                    tooltip: 'More',
                    onPressed: () {
                      // TODO: More actions
                    },
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
