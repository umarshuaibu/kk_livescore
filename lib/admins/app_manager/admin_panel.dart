import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/admins/app_manager/admin_body_view.dart';
import 'package:kklivescoreadmin/admins/app_manager/dashboard_overview.dart';
import 'package:kklivescoreadmin/admins/management/models/player_model.dart';
import 'package:kklivescoreadmin/admins/management/screens/coach_list_screen.dart';
import 'package:kklivescoreadmin/admins/management/screens/create_player_screen.dart';
import 'package:kklivescoreadmin/admins/management/screens/edit_player_screen.dart';
import 'package:kklivescoreadmin/admins/management/screens/player_list_screen.dart';
import 'package:kklivescoreadmin/admins/management/screens/team_list_screen.dart';
import 'package:kklivescoreadmin/admins/management/screens/transfer_list_screen.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/league_manager/league_list_screen.dart';
import 'package:kklivescoreadmin/league_manager/live_updater/match_selector_screen.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  AdminBodyView _activeBodyView = AdminBodyView.dashboard;
  Player? _selectedPlayer;



  // ================= NAVIGATION HANDLER =================
  void _handleDashboardNavigation(
    AdminBodyView view, {
    Player? player,
  }) {
    setState(() {
      _activeBodyView = view;
      _selectedPlayer = player;
    });
  }

Future<void> signOut(BuildContext context) async {
  try {
    // 1️⃣ Show a loading indicator to prevent multiple taps
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // 2️⃣ Sign out from Firebase
    await FirebaseAuth.instance.signOut();

    // 3️⃣ Navigate to your login screen (replace with your actual login screen widget)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardPage ()),
      (route) => false,
    );
  } catch (_) {
    // Show a generic error message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to sign out. Please try again.'),
      ),
    );
  } finally {
    // 4️⃣ Close the loading dialog if it is still open
    if (Navigator.canPop(context)) Navigator.of(context).pop();
  }
}



  // ================= MAIN BODY RESOLVER =================
  Widget _resolveMainBody() {
    switch (_activeBodyView) {
      case AdminBodyView.dashboard:
        return DashboardOverview(
          key: const ValueKey('dashboard'),
          onNavigate: _handleDashboardNavigation,
        );

      case AdminBodyView.players:
        return PlayerListScreen(
          key: const ValueKey('players'),
          onNavigate: _handleDashboardNavigation,
        );

      case AdminBodyView.createPlayer:
        return CreatePlayerScreen(
          key: const ValueKey('create_player'),
          onDone: () =>
              _handleDashboardNavigation(AdminBodyView.players),
        );

      case AdminBodyView.editPlayer:
        if (_selectedPlayer == null) {
          return const Center(child: Text('No player selected'));
        }
        return EditPlayerScreen(
          key: const ValueKey('edit_player'),
          playerId: _selectedPlayer!.id,
          onDone: () =>
              _handleDashboardNavigation(AdminBodyView.players),
        );

      case AdminBodyView.teams:
        return TeamListScreen(key: ValueKey('teams'));

      case AdminBodyView.transfers:
        return TransferListScreen(key: ValueKey('transfers'));

      case AdminBodyView.coaches:
        return CoachListScreen(key: ValueKey('coaches'));

      case AdminBodyView.liveMatchUpdater:
        return const MatchSelectorScreen(key: ValueKey('live_matches'));
        
              case AdminBodyView.leagues:
        return const LeagueListScreen(key: ValueKey('Leagues_list'));

      case AdminBodyView.news:
        return const LeagueListScreen(key: ValueKey('news'));

      default:
        return const SizedBox.shrink();
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: kSecondaryColor,
      body: Row(
        children: [
          // ================= SIDEBAR =================
          if (isDesktop)
            Container(
              width: 240,
              decoration: BoxDecoration(
                color: kPrimaryColor,
                boxShadow: const [
                  BoxShadow(color: kScaffoldColor, blurRadius: 6),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    "KK LIVESCORE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _sidebarItem(Icons.dashboard, "Dashboard",
                      () => _handleDashboardNavigation(AdminBodyView.dashboard)),

                  _sidebarItem(Icons.sports_soccer, "Live Matches",
                      () => _handleDashboardNavigation(AdminBodyView.liveMatchUpdater)),

                  _sidebarItem(Icons.article, "News",
                      () => _handleDashboardNavigation(AdminBodyView.news)),

                  _sidebarItem(Icons.group, "Teams",
                      () => _handleDashboardNavigation(AdminBodyView.teams)),

                  _sidebarItem(Icons.people, "Players",
                      () => _handleDashboardNavigation(AdminBodyView.players)),

                  _sidebarItem(Icons.swap_horiz, "Transfers",
                      () => _handleDashboardNavigation(AdminBodyView.transfers)),

                  _sidebarItem(Icons.people, "Coaches",
                      () => _handleDashboardNavigation(AdminBodyView.coaches)),

                  const Spacer(),
                  const Divider(color: Colors.white24),
                 _sidebarItem(Icons.logout, "Logout", () {
  signOut(context); // Call the cleaned-up function
}),

                  const SizedBox(height: 16),
                ],
              ),
            ),

          // ================= MAIN CONTENT =================
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _resolveMainBody(),
            ),
          ),
        ],
      ),
    );
  }





  // ================= SIDEBAR ITEM =================
  Widget _sidebarItem(
      IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
