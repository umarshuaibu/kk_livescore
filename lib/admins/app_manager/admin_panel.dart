import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/admins/app_manager/tabs/dashboard_tab.dart';
import '../../reusables/constants.dart'; // Adjusted import path
//import '../../screens/matches_category_screen.dart';
//import '../../screens/transfers_screen.dart';
import '../../reusables/custom_dialog.dart'; // Import CustomDialog

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0; // For bottom navigation

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 tabs: Dashboard, Live Update, News
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _getTabContent(int index) {
    switch (index) {
      case 0:
        return DashboardTab(); // for Dashboard
      case 1:
        return Container(); // Placeholder for Live Update
      case 2:
        return Container(); // Placeholder for News
      default:
        return const SizedBox.shrink();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      // Navigate to AdminPanel (current screen)
      context.go('/admin_panel');
    } else if (index == 1) {
      // Show exit confirmation dialog
      CustomDialog.show(
        context,
        title: 'Exit Confirmation',
        message: 'Are you sure you want to exit the app?',
        confirmText: 'OK',
        cancelText: 'Cancel',
        onConfirm: () {
          SystemNavigator.pop(); // Exit app
        },
        onCancel: () {}, // No action on cancel, just close dialog
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel', style: AppTextStyles.headingStyle),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false, // Enable scrolling if needed
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.0, color: AppColors.whiteColor),
          ),
          labelColor: AppColors.whiteColor,
          unselectedLabelColor: AppColors.secondaryColor, // Assuming grey for unselected
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard),
              text: 'Dashboard',
            ),
            Tab(
              icon: Icon(Icons.live_tv),
              text: 'Live Update',
            ),
            Tab(
              icon: Icon(Icons.newspaper),
              text: 'Publish News',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _getTabContent(0),
          _getTabContent(1),
          _getTabContent(2),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: AppColors.primaryColor,
        selectedIconTheme: const IconThemeData(color: AppColors.secondaryColor),
        unselectedIconTheme: const IconThemeData(color: AppColors.primaryColor),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.exit_to_app),
            label: 'Exit',
          ),
        ],
      ),
    );
  }
}