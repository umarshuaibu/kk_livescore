import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../reusables/constants.dart'; // Adjusted import path
import '../../../services/player_service.dart';
import '../../../services/team_service.dart';
import '../../../services/coach_service.dart';
/*import '../../services/league_service.dart';
import '../../services/transfer_service.dart';
import '../../services/news_service.dart';*/

// Dashboard tab widget to display management cards and action options
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  String? _selectedAction;

  final List<String> _actions = [
    'Add new player',
    'Add new team',
    'Add new coach',
    'Add new league',
    'Initiate player transfer',
  ];

  final Map<String, String> _actionRoutes = {
    'Add new player': '/create_player',
    'Add new team':   '/create_team',
    'Add new coach': '/create_coach',
    'Add new league': '/create_league',
    'Initiate player transfer': '/player_transfer',
  };

  // Fetches the count of items from a given Future<List<dynamic>> source
  Future<int> _getCount(Future<List<dynamic>> fetchFunction) async {
    try {
      final list = await fetchFunction;
      return list.length;
    } catch (e) {
      return 0; // Default to 0 on error
    }
  }

  // Builds a clickable card with icon, title, and count in three rows
  Widget _buildCard(String title, Future<List<dynamic>> countFuture, String route, IconData icon) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12.0), // 16px padding on all sides
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Row 1: Icon centered at the top
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 32, color: AppColors.primaryColor),
                ],
              ),
              const SizedBox(height: 3), // Spacer between icon and title
              // Row 2: Title centered
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: AppTextStyles.headingStyle, textAlign: TextAlign.center),
                ],
              ),
              const SizedBox(height: 4), // Spacer between title and count
              // Row 3: Count with FutureBuilder, centered
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FutureBuilder<int>(
                    future: _getCount(countFuture),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return Text(
                        '${snapshot.data ?? 0}',
                        style: AppTextStyles.headingStyle.copyWith(fontSize: 32, color: AppColors.primaryColor),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the action card with dropdown and proceed button
  Widget _buildActionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedAction,
              hint: const Text('Select Action', style: TextStyle(color: AppColors.primaryColor)),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: AppColors.whiteColor,
              ),
              items: _actions.map((action) {
                return DropdownMenuItem<String>(
                  value: action,
                  child: Text(action, style: const TextStyle(color: AppColors.primaryColor)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedAction = value;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _selectedAction == null
                  ? null
                  : () => context.go(_actionRoutes[_selectedAction!]!),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: AppColors.whiteColor,
                disabledBackgroundColor: AppColors.secondaryColor,
                disabledForegroundColor: AppColors.whiteColor,
              ),
              child: const Text('Proceed'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 2,
            padding: EdgeInsets.zero,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.0, // Increased to ~192px height for 96px width
            children: [
              _buildCard('Players', PlayerService().fetchPlayers(), '/player_list', Icons.people),
              _buildCard('Teams', TeamService().fetchTeams(), '/team_list', Icons.group),
              _buildCard('Coaches', CoachService().fetchCoaches(), '/coach_list', Icons.person),
              _buildCard('Leagues', PlayerService().fetchPlayers(), '/league_list', Icons.emoji_events),
              _buildCard('Transfers', TeamService().fetchTeams(), '/transfer_list', Icons.swap_horiz),
              _buildCard('News', CoachService().fetchCoaches(), '/news_list', Icons.article),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionCard(),
        ],
      ),
    );
  }
}