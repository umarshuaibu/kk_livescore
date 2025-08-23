import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/player_list_screen.dart';
import '/reusables/constants.dart'; // Adjust import path as needed

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab labels (also used to form the /admin/<tab> route when lowercased)
  final List<String> _tabs = [
    'Matches',
    'Teams',
    'Players',
    'Coaches',
    'Transfers',
  ];

  int _selectedIndex = 0; // bottom nav index

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // Rebuild FAB on index change + keep URL in sync (content stays in TabBarView)
    _tabController.addListener(() {
      if (mounted) setState(() {});
      if (_tabController.indexIsChanging) {
        _navigateToTab(_tabs[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToTab(String tabName) {
    final String route = '/admin/${tabName.toLowerCase()}';
    context.go(route); // keeps URL updated, does NOT leave this screen
  }

  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    switch (index) {
      case 0:
        context.go('/admin');
        break;
      case 1:
        context.go('/admin/quick');
        break;
      case 2:
        context.go('/admin/more');
        break;
    }
  }

  /// Extended FAB builder depending on current tab index
  Widget? _buildFab() {
    switch (_tabController.index) {
      case 0: // Matches
        return FloatingActionButton.extended(
          onPressed: () => context.go(
              '/admin/create-match' // ← REPLACE with your exact route
              ),
          label: const Text('Add Match'),
          icon: const Icon(Icons.add),
          backgroundColor: AppColors.primaryColor,
          foregroundColor: AppColors.whiteColor,
        );
      case 1: // Teams
        return FloatingActionButton.extended(
          onPressed: () => context.go(
              '/screens/create_team' // ← REPLACE with your exact route
              ),
          label: const Text('Add Team'),
          icon: const Icon(Icons.group_add),
          backgroundColor: AppColors.primaryColor,
          foregroundColor: AppColors.whiteColor,
        );
      case 2: // Players
        return FloatingActionButton.extended(
          onPressed: () => context.go(
              '/screens/create_player' // ← REPLACE with your exact route
              ),
          label: const Text('Add Player'),
          icon: const Icon(Icons.person_add),
          backgroundColor: AppColors.primaryColor,
          foregroundColor: AppColors.whiteColor,
        );
      case 3: // Coaches
        return FloatingActionButton.extended(
          onPressed: () => context.go(
              '/screens/create_coach' // ← REPLACE with your exact route
              ),
          label: const Text('Add Coach'),
          icon: const Icon(Icons.school),
          backgroundColor: AppColors.primaryColor,
          foregroundColor: AppColors.whiteColor,
        );
      case 4: // Transfers
        return FloatingActionButton.extended(
          onPressed: () => context.go(
              '/admin/create-transfer' // ← REPLACE with your exact route
              ),
          label: const Text('Add Transfer'),
          icon: const Icon(Icons.swap_horiz),
          backgroundColor: AppColors.primaryColor,
          foregroundColor: AppColors.whiteColor,
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: AppTextStyles.headingStyle,
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.whiteColor,
          unselectedLabelColor: AppColors.secondaryColor,
          labelStyle: AppTextStyles.subheadingStyle,
          unselectedLabelStyle: AppTextStyles.subheadingStyle,
          indicatorColor: AppColors.whiteColor,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          onTap: (i) {
            // Ensure URL updates on direct taps too
            _navigateToTab(_tabs[i]);
          },
        ),
      ),

      /// TAB CONTENT AREA — stays on the same screen
      body: TabBarView(
        controller: _tabController,
        children:  [
          // 🔻 Replace these placeholders with your actual widgets
          PlayerListScreen(),
          TeamsTabPlaceholder(),
          PlayerListScreen(),
          CoachesTabPlaceholder(),
          TransfersTabPlaceholder(),
        ],
      ),

      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: AppColors.secondaryColor,
        selectedLabelStyle: AppTextStyles.bodyStyle,
        unselectedLabelStyle: AppTextStyles.bodyStyle,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on),
            label: 'Quick',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

/// ----------------------
/// PLACEHOLDER WIDGETS
/// Replace each with your real tab screens
/// ----------------------

class MatchesTabPlaceholder extends StatelessWidget {
  const MatchesTabPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Matches content goes here', style: AppTextStyles.bodyStyle),
    );
  }
}

class TeamsTabPlaceholder extends StatelessWidget {
  const TeamsTabPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Teams content goes here', style: AppTextStyles.bodyStyle),
    );
  }
}

class PlayersTabPlaceholder extends StatelessWidget {
  const PlayersTabPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Players content goes here', style: AppTextStyles.bodyStyle),
    );
  }
}

class CoachesTabPlaceholder extends StatelessWidget {
  const CoachesTabPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      
      child: Text('Coaches content goes here', style: AppTextStyles.bodyStyle),
    );
  }
}

class TransfersTabPlaceholder extends StatelessWidget {
  const TransfersTabPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Transfers content goes here', style: AppTextStyles.bodyStyle),
    );
  }
}
