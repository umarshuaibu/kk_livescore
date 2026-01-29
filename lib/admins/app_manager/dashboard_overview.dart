import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/admins/app_manager/admin_body_view.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/admins/management/services/coach_service.dart';
import 'package:kklivescoreadmin/admins/management/services/player_service.dart';
import 'package:kklivescoreadmin/admins/management/services/team_service.dart';
import 'package:kklivescoreadmin/admins/management/services/transfer_service.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/league_manager/firestore_service.dart';

class DashboardOverview extends StatelessWidget {
  final ValueChanged<AdminBodyView> onNavigate;

  const DashboardOverview({
    super.key,
    required this.onNavigate,
  });


  // ================= COUNT HELPER =================
  Future<int> _getCount(Future<List<dynamic>> fetchFn) async {
    try {
      final list = await fetchFn;
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    int gridCount = 2;
    if (width >= 1200) gridCount = 3;
    if (width >= 1600) gridCount = 4;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= PAGE TITLE =================
              const Text(
                "Dashboard Overview",
                style: TextStyle(
                  color: kWhiteColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 24),

              // ================= ACTION CARDS =================
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _actionCard(
                    context,
                    title: "Live Match Update",
                    subtitle: "Update scores & match events",
                    icon: Icons.sports_soccer,
                    onTap: () =>
                        onNavigate(AdminBodyView.liveMatchUpdater)
                  ),
                  _actionCard(
                    context,
                    title: "Broadcast News",
                    subtitle: "Publish announcements & updates",
                    icon: Icons.campaign,
                    onTap: () => onNavigate(AdminBodyView.news)
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ================= STAT GRID =================
              GridView.count(
                crossAxisCount: gridCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.8,
                children: [
                  _statCard(
                    context,
                    "Players",
                    Icons.people,
                    PlayerService().fetchPlayers(),
                    () => onNavigate(AdminBodyView.players),
                    
                  ),
                  _statCard(
                    context,
                    "Teams",
                    Icons.group,
                    TeamService().fetchTeams(),
                    () => onNavigate(AdminBodyView.teams),
                  ),
                  _statCard(
                    context,
          
                    "Coaches",
                    Icons.person,
                    CoachService().fetchCoaches(),
                  
                   () => onNavigate(AdminBodyView.coaches),
                  ),
                  _statCard(
                    context,
                    "Leagues",
                    Icons.emoji_events,
                    FirestoreService().getAllLeagues(),
                    () => onNavigate(AdminBodyView.leagues),
                  ),
                  _statCard(
                    context,
                    "Transfers",
                    Icons.swap_horiz,
                    TransferService().fetchTransfers(),
                  () => onNavigate(AdminBodyView.transfers),
                  ),
                  _statCard(
                    context,
                    "News",
                    Icons.article,
                    CoachService().fetchCoaches(),
                   () => onNavigate(AdminBodyView.news),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ================= FOOTER =================
              Center(
                child: Text(
                  "© ${DateTime.now().year} KK Livescore Admin Panel",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= ACTION CARD =================
  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 320,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Card(
          elevation: 1.5,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 28, color: AppColors.primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= STAT CARD =================
Widget _statCard(
  BuildContext context,
  String title,
  IconData icon,
  Future<List<dynamic>> future,
  VoidCallback onTap,
)
 {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onTap(),
      child: Card(
        elevation: 1,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 26, color: AppColors.primaryColor),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<int>(
                    future: _getCount(future),
                    builder: (context, snapshot) {
                      return Text(
                        "${snapshot.data ?? 0}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryColor,
                        ),
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
}
