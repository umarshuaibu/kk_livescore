import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/admins/app_manager/admin_body_view.dart';
import 'package:kklivescoreadmin/admins/app_manager/dashboard_overview.dart';
import 'package:kklivescoreadmin/admins/management/models/player_model.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/admins/management/screens/coach_list_screen.dart';
import 'package:kklivescoreadmin/admins/management/screens/create_player_screen.dart';
//import 'package:kklivescoreadmin/admins/management/screens/edit_player_screen.dart';
import 'package:kklivescoreadmin/admins/management/screens/player_list_screen.dart';
import 'package:kklivescoreadmin/admins/management/screens/team_list_screen.dart';
import 'package:kklivescoreadmin/admins/management/screens/transfer_list_screen.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/league_manager/league_list_screen.dart';
import 'package:kklivescoreadmin/league_manager/live_updater/match_selector_screen.dart';

// ── Sidebar width constants ──
const double _kSidebarExpanded = 230.0;
const double _kSidebarCollapsed = 64.0;
const double _kDesktopBreak = 1024.0;
const double _kTabletBreak = 768.0;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  AdminBodyView _activeBodyView = AdminBodyView.dashboard;
  Player? _selectedPlayer;

  // Sidebar state
  bool _sidebarCollapsed = false;
  bool _drawerOpen = false;

  // Animation for sidebar width transition
  late AnimationController _sidebarCtrl;
  late Animation<double> _sidebarAnim;

  // Mobile drawer animation
  late AnimationController _drawerCtrl;
  late Animation<Offset> _drawerSlide;
  late Animation<double> _drawerFade;

  @override
  void initState() {
    super.initState();

    _sidebarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _sidebarAnim = Tween<double>(
      begin: _kSidebarExpanded,
      end: _kSidebarCollapsed,
    ).animate(
        CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeInOut));

    _drawerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _drawerSlide = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeOutCubic));
    _drawerFade =
        CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    _drawerCtrl.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    _sidebarCollapsed ? _sidebarCtrl.forward() : _sidebarCtrl.reverse();
  }

  void _openDrawer() {
    setState(() => _drawerOpen = true);
    _drawerCtrl.forward();
  }

  void _closeDrawer() {
    _drawerCtrl.reverse().then((_) {
      if (mounted) setState(() => _drawerOpen = false);
    });
  }

  // ================= NAVIGATION HANDLER =================
  void _handleDashboardNavigation(AdminBodyView view, {Player? player}) {
    setState(() {
      _activeBodyView = view;
      _selectedPlayer = player;
    });
    if (_drawerOpen) _closeDrawer();
  }

  // ================= SIGN OUT =================
  Future<void> signOut(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await FirebaseAuth.instance.signOut();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardPage()),
        (route) => false,
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to sign out. Please try again.')),
      );
    } finally {
      if (Navigator.canPop(context)) Navigator.of(context).pop();
    }
  }

  // ================= BODY RESOLVER =================
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

     /* case AdminBodyView.createPlayer:
        return CreatePlayerScreen(
          key: const ValueKey('create_player'),
          onDone: () => _handleDashboardNavigation(AdminBodyView.players),
        );*/

     /* case AdminBodyView.editPlayer:
        if (_selectedPlayer == null) {
          return const Center(child: Text('No player selected'));
        }
        return EditPlayerScreen(
          key: const ValueKey('edit_player'),
          playerId: _selectedPlayer!.id,
          onDone: () => _handleDashboardNavigation(AdminBodyView.players),
        );*/

      case AdminBodyView.teams:
        return TeamListScreen(key: const ValueKey('teams'));

      case AdminBodyView.transfers:
        return TransferListScreen(key: const ValueKey('transfers'));

      case AdminBodyView.coaches:
        return CoachListScreen(key: const ValueKey('coaches'));

      case AdminBodyView.liveMatchUpdater:
        return const MatchSelectorScreen(key: ValueKey('live_matches'));

      case AdminBodyView.leagues:
        return const LeagueListScreen(key: ValueKey('leagues'));

      case AdminBodyView.news:
        return const LeagueListScreen(key: ValueKey('news'));

      default:
        return const SizedBox.shrink();
    }
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= _kDesktopBreak;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Stack(
        children: [
          // ── MAIN LAYOUT ──
          Row(
            children: [
              // DESKTOP SIDEBAR
              if (isDesktop) _buildDesktopSidebar(),

              // CONTENT AREA
              Expanded(
                child: Column(
                  children: [
                    // MOBILE / TABLET TOP BAR
                    if (!isDesktop) _buildTopBar(context),

                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOut,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: _resolveMainBody(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // MOBILE DRAWER OVERLAY
          if (!isDesktop && _drawerOpen) ...[
            // Backdrop
            FadeTransition(
              opacity: _drawerFade,
              child: GestureDetector(
                onTap: _closeDrawer,
                child:
                    Container(color: Colors.black.withOpacity(0.5)),
              ),
            ),
            // Drawer panel
            SlideTransition(
              position: _drawerSlide,
              child: _buildMobileDrawer(),
            ),
          ],
        ],
      ),
    );
  }

  // ================= DESKTOP SIDEBAR =================
  Widget _buildDesktopSidebar() {
    return AnimatedBuilder(
      animation: _sidebarAnim,
      builder: (context, _) {
        final w = _sidebarAnim.value;
        final collapsed = _sidebarCollapsed;

        return Container(
          width: w,
          decoration: BoxDecoration(
            color: const Color(0xFF161A23),
            border: Border(
              right: BorderSide(color: Colors.white.withOpacity(0.07)),
            ),
          ),
          child: Column(
            children: [
              // ── LOGO AREA ──
              _buildLogoArea(collapsed),

              const SizedBox(height: 8),

              // ── NAV ITEMS ──
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _navItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        view: AdminBodyView.dashboard,
                        collapsed: collapsed,
                      ),
                      _navItem(
                        icon: Icons.sports_soccer_rounded,
                        label: 'Live Matches',
                        view: AdminBodyView.liveMatchUpdater,
                        collapsed: collapsed,
                      ),
                      _navItem(
                        icon: Icons.article_rounded,
                        label: 'News',
                        view: AdminBodyView.news,
                        collapsed: collapsed,
                      ),
                      _navDivider(collapsed),
                      _navItem(
                        icon: Icons.shield_rounded,
                        label: 'Teams',
                        view: AdminBodyView.teams,
                        collapsed: collapsed,
                      ),
                      _navItem(
                        icon: Icons.people_alt_rounded,
                        label: 'Players',
                        view: AdminBodyView.players,
                        collapsed: collapsed,
                      ),
                      _navItem(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Transfers',
                        view: AdminBodyView.transfers,
                        collapsed: collapsed,
                      ),
                      _navItem(
                        icon: Icons.manage_accounts_rounded,
                        label: 'Coaches',
                        view: AdminBodyView.coaches,
                        collapsed: collapsed,
                      ),
                      _navItem(
                        icon: Icons.emoji_events_rounded,
                        label: 'Leagues',
                        view: AdminBodyView.leagues,
                        collapsed: collapsed,
                      ),
                    ],
                  ),
                ),
              ),

              // ── BOTTOM ACTIONS ──
              _buildSidebarBottom(collapsed),
            ],
          ),
        );
      },
    );
  }

  // ── Logo / brand area ──
  Widget _buildLogoArea(bool collapsed) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sports_soccer_rounded,
                color: Colors.white, size: 18),
          ),
          if (!collapsed) ...[
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'KK Livescore',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(width: 4),
          // Collapse toggle
          GestureDetector(
            onTap: _toggleSidebar,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(7),
              ),
              child: AnimatedRotation(
                turns: collapsed ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.chevron_left_rounded,
                    color: Colors.white60, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom: logout ──
  Widget _buildSidebarBottom(bool collapsed) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: _navAction(
        icon: Icons.logout_rounded,
        label: 'Logout',
        color: const Color(0xFFE57373),
        collapsed: collapsed,
        onTap: () => signOut(context),
      ),
    );
  }

  // ── Divider between sections ──
  Widget _navDivider(bool collapsed) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 12 : 16,
        vertical: 6,
      ),
      child: collapsed
          ? Divider(color: Colors.white.withOpacity(0.08), height: 1)
          : Row(
              children: [
                Expanded(
                    child: Divider(
                        color: Colors.white.withOpacity(0.08), height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'MANAGEMENT',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(
                    child: Divider(
                        color: Colors.white.withOpacity(0.08), height: 1)),
              ],
            ),
    );
  }

  // ================= NAV ITEM =================
  Widget _navItem({
    required IconData icon,
    required String label,
    required AdminBodyView view,
    required bool collapsed,
  }) {
    final isActive = _activeBodyView == view;

    return _NavItemWidget(
      icon: icon,
      label: label,
      isActive: isActive,
      collapsed: collapsed,
      onTap: () => _handleDashboardNavigation(view),
    );
  }

  // ── Non-view nav action (logout etc.) ──
  Widget _navAction({
    required IconData icon,
    required String label,
    required Color color,
    required bool collapsed,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: collapsed ? label : '',
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: EdgeInsets.symmetric(
              horizontal: collapsed ? 10 : 12, vertical: 2),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ================= MOBILE TOP BAR =================
  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 56 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 12,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF161A23),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openDrawer,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.menu_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.sports_soccer_rounded,
                color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          const Text(
            'KK Livescore',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          // Current section badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryColor2.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primaryColor2.withOpacity(0.25)),
            ),
            child: Text(
              _viewLabel(_activeBodyView),
              style: TextStyle(
                color: AppColors.primaryColor2,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= MOBILE DRAWER =================
  Widget _buildMobileDrawer() {
    return Container(
      width: 260,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161A23),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withOpacity(0.07)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.sports_soccer_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'KK Livescore',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _closeDrawer,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white60, size: 16),
                      ),
                    ),
                  ],
                ),
              ),

              // Nav items
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _navItem(
                        icon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        view: AdminBodyView.dashboard,
                        collapsed: false,
                      ),
                      _navItem(
                        icon: Icons.sports_soccer_rounded,
                        label: 'Live Matches',
                        view: AdminBodyView.liveMatchUpdater,
                        collapsed: false,
                      ),
                      _navItem(
                        icon: Icons.article_rounded,
                        label: 'News',
                        view: AdminBodyView.news,
                        collapsed: false,
                      ),
                      _navDivider(false),
                      _navItem(
                        icon: Icons.shield_rounded,
                        label: 'Teams',
                        view: AdminBodyView.teams,
                        collapsed: false,
                      ),
                      _navItem(
                        icon: Icons.people_alt_rounded,
                        label: 'Players',
                        view: AdminBodyView.players,
                        collapsed: false,
                      ),
                      _navItem(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Transfers',
                        view: AdminBodyView.transfers,
                        collapsed: false,
                      ),
                      _navItem(
                        icon: Icons.manage_accounts_rounded,
                        label: 'Coaches',
                        view: AdminBodyView.coaches,
                        collapsed: false,
                      ),
                      _navItem(
                        icon: Icons.emoji_events_rounded,
                        label: 'Leagues',
                        view: AdminBodyView.leagues,
                        collapsed: false,
                      ),
                    ],
                  ),
                ),
              ),

              // Logout
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.07)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _navAction(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  color: const Color(0xFFE57373),
                  collapsed: false,
                  onTap: () => signOut(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper: view label for top bar badge ──
  String _viewLabel(AdminBodyView view) {
    switch (view) {
      case AdminBodyView.dashboard:
        return 'Dashboard';
      case AdminBodyView.players:
      case AdminBodyView.createPlayer:
      case AdminBodyView.editPlayer:
        return 'Players';
      case AdminBodyView.teams:
        return 'Teams';
      case AdminBodyView.coaches:
        return 'Coaches';
      case AdminBodyView.transfers:
        return 'Transfers';
      case AdminBodyView.leagues:
        return 'Leagues';
      case AdminBodyView.news:
        return 'News';
      case AdminBodyView.liveMatchUpdater:
        return 'Live Matches';
      default:
        return 'Dashboard';
    }
  }
}

// ================= NAV ITEM WIDGET =================
class _NavItemWidget extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
  });

  @override
  State<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends State<_NavItemWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final collapsed = widget.collapsed;

    return Tooltip(
      message: collapsed ? widget.label : '',
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: EdgeInsets.symmetric(
                horizontal: collapsed ? 10 : 12, vertical: 2),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primaryColor.withOpacity(0.15)
                  : _hovered
                      ? Colors.white.withOpacity(0.05)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: active
                  ? Border.all(
                      color: AppColors.primaryColor.withOpacity(0.25))
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                // Active indicator bar
                if (!collapsed)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primaryColor2
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                Icon(
                  widget.icon,
                  size: 18,
                  color: active
                      ? AppColors.primaryColor2
                      : _hovered
                          ? Colors.white
                          : Colors.white54,
                ),

                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: active
                            ? AppColors.primaryColor2
                            : _hovered
                                ? Colors.white
                                : Colors.white60,
                        fontSize: 13,
                        fontWeight: active
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Active dot
                  if (active)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}