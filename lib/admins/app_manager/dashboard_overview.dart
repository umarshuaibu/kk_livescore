import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/admins/app_manager/admin_body_view.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/admins/management/services/coach_service.dart';
import 'package:kklivescoreadmin/admins/management/services/player_service.dart';
import 'package:kklivescoreadmin/admins/management/services/team_service.dart';
import 'package:kklivescoreadmin/admins/management/services/transfer_service.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/league_manager/firestore_service.dart';

class DashboardOverview extends StatefulWidget {
  final ValueChanged<AdminBodyView> onNavigate;

  const DashboardOverview({
    super.key,
    required this.onNavigate,
  });

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

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
    if (width >= 900) gridCount = 3;
    if (width >= 1300) gridCount = 4;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: width > 800 ? 32 : 16,
            vertical: 28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= HEADER =================
                  _buildHeader(),

                  const SizedBox(height: 28),

                  // ================= ACTION CARDS =================
                  _buildSectionLabel("Quick Actions"),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _actionCard(
                        context,
                        title: "Live Match Update",
                        subtitle: "Update scores & match events",
                        icon: Icons.sports_soccer_rounded,
                        accentColor: const Color(0xFF00D4AA),
                        onTap: () =>
                            widget.onNavigate(AdminBodyView.liveMatchUpdater),
                      ),
                      _actionCard(
                        context,
                        title: "Broadcast News",
                        subtitle: "Publish announcements & updates",
                        icon: Icons.campaign_rounded,
                        accentColor: const Color(0xFFFF6B6B),
                        onTap: () => widget.onNavigate(AdminBodyView.news),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // ================= STAT GRID =================
                  _buildSectionLabel("Overview"),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: gridCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: width < 600 ? 1.6 : 1.9,
                    children: [
                      _statCard(
                        context,
                        label: "Players",
                        icon: Icons.people_alt_rounded,
                        future: PlayerService().fetchPlayers(),
                        accentColor: const Color(0xFF4FC3F7),
                        onTap: () =>
                            widget.onNavigate(AdminBodyView.players),
                        delay: 0,
                      ),
                      _statCard(
                        context,
                        label: "Teams",
                        icon: Icons.shield_rounded,
                        future: TeamService().fetchTeams(),
                        accentColor: const Color(0xFF81C784),
                        onTap: () => widget.onNavigate(AdminBodyView.teams),
                        delay: 50,
                      ),
                      _statCard(
                        context,
                        label: "Coaches",
                        icon: Icons.manage_accounts_rounded,
                        future: CoachService().fetchCoaches(),
                        accentColor: const Color(0xFFFFB74D),
                        onTap: () =>
                            widget.onNavigate(AdminBodyView.coaches),
                        delay: 100,
                      ),
                      _statCard(
                        context,
                        label: "Leagues",
                        icon: Icons.emoji_events_rounded,
                        future: FirestoreService().getAllLeagues(),
                        accentColor: const Color(0xFFE57373),
                        onTap: () =>
                            widget.onNavigate(AdminBodyView.leagues),
                        delay: 150,
                      ),
                      _statCard(
                        context,
                        label: "Transfers",
                        icon: Icons.swap_horiz_rounded,
                        future: TransferService().fetchTransfers(),
                        accentColor: const Color(0xFFBA68C8),
                        onTap: () =>
                            widget.onNavigate(AdminBodyView.transfers),
                        delay: 200,
                      ),
                      _statCard(
                        context,
                        label: "News",
                        icon: Icons.article_rounded,
                        future: CoachService().fetchCoaches(),
                        accentColor: const Color(0xFF4DD0E1),
                        onTap: () => widget.onNavigate(AdminBodyView.news),
                        delay: 250,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ================= FOOTER =================
                  Center(
                    child: Text(
                      "© ${DateTime.now().year} KK Livescore Admin Panel",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Dashboard",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Welcome back — here's what's happening",
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        _buildDateBadge(),
      ],
    );
  }

  Widget _buildDateBadge() {
    final now = DateTime.now();
    final weekdays = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 14, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(
            "${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}",
            style: TextStyle(
              color: Colors.grey.shade300,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ================= SECTION LABEL =================
  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  // ================= ACTION CARD =================
  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 300,
      child: _HoverCard(
        borderRadius: 14,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.07),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.06),
                Colors.white.withOpacity(0.02),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: accentColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }

  // ================= STAT CARD =================
  Widget _statCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Future<List<dynamic>> future,
    required VoidCallback onTap,
    required Color accentColor,
    int delay = 0,
  }) {
    return _DelayedEntrance(
      delay: delay,
      child: _HoverCard(
        borderRadius: 14,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.06),
                Colors.white.withOpacity(0.02),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: accentColor),
                  ),
                  Icon(Icons.north_east_rounded,
                      size: 14, color: Colors.grey.shade700),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<int>(
                    future: _getCount(future),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accentColor,
                          ),
                        );
                      }
                      return Text(
                        "${snapshot.data ?? 0}",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
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

// ================= HOVER CARD WRAPPER =================
class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  const _HoverCard({
    required this.child,
    this.onTap,
    this.borderRadius = 12,
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}

// ================= DELAYED ENTRANCE ANIMATION =================
class _DelayedEntrance extends StatefulWidget {
  final Widget child;
  final int delay;

  const _DelayedEntrance({required this.child, this.delay = 0});

  @override
  State<_DelayedEntrance> createState() => _DelayedEntranceState();
}

class _DelayedEntranceState extends State<_DelayedEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}