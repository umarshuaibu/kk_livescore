import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/admins/management/reusables/edit_team_panel.dart';
import 'package:kklivescoreadmin/admins/management/screens/create_team_screen.dart';
import '../reusables/constants.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../reusables/custom_progress_indicator.dart';

class TeamListScreen extends StatefulWidget {
  final TeamService teamService = TeamService();

  TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final TeamService _teamService = TeamService();
  final Map<String, String> _coachNameCache = {};
   

  Timer? _debounce;
  List<Team> _filteredTeams = [];
  bool _searchFocused = false;

  Team? _editingTeam;
bool _creatingTeam = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ================= COACH NAME CACHE =================
  Future<String?> _getCoachName(String coachId) async {
    if (_coachNameCache.containsKey(coachId)) return _coachNameCache[coachId];
    try {
      final doc = await FirebaseFirestore.instance
          .collection('coaches')
          .doc(coachId)
          .get();
      if (!doc.exists) {
        _coachNameCache[coachId] = '—';
        return '—';
      }
      final name = doc.data()?['name'] as String?;
      _coachNameCache[coachId] = name ?? '—';
      return name ?? '—';
    } catch (_) {
      return '—';
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() {});
    });
  }

  List<Team> _filterTeams(List<Team> teams, String query) {
    if (query.isEmpty) return teams;
    return teams
        .where((t) => t.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 650;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),

      body: Stack(
        children: [ 
          FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeader(context, isMobile),
            Expanded(
              child: StreamBuilder<List<Team>>(
                stream: widget.teamService.streamTeams(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CustomProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _buildEmptyState(
                      icon: Icons.error_outline_rounded,
                      message: 'Something went wrong',
                      sub: '${snapshot.error}',
                      color: const Color(0xFFE57373),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.shield_outlined,
                      message: 'No teams found',
                      sub: 'Add your first team using the + button',
                      color: const Color(0xFF81C784),
                    );
                  }

                  final teams = snapshot.data!;
                  _filteredTeams =
                      _filterTeams(teams, _searchController.text);

                  if (_filteredTeams.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      message: 'No results found',
                      sub: 'Try a different search term',
                      color: const Color(0xFF4FC3F7),
                    );
                  }

                  return isMobile
                      ? _buildCardList(_filteredTeams)
                      : _buildTable(_filteredTeams);
                },
              ),
            ),
          ],
        ),
      ),

        // ================= EDIT PANEL OVERLAY =================
        if (_editingTeam != null)
          EditTeamPanel(
            team: _editingTeam!,
            onDone: () {
              setState(() {
                _editingTeam = null;
              });
            },
          ),

          if (_creatingTeam)
  CreateTeamPanel(
    onDone: () {
      setState(() => _creatingTeam = false);
    },
  ),
      ],
    ),
      
      floatingActionButton: _AnimatedFab(
       onPressed: () {
  setState(() {
    _creatingTeam = true;
  });
},
      ),
    );
  }

  // ================= HEADER =================
  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161A23),
        border:
            Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => context.go('/admin_panel'),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Teams',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white
                  .withOpacity(_searchFocused ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _searchFocused
                    ? AppColors.primaryColor.withOpacity(0.5)
                    : Colors.white.withOpacity(0.07),
                width: 1.2,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search teams...',
                hintStyle: TextStyle(
                    color: Colors.grey.shade600, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.grey.shade600, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: Colors.grey.shade500),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 13, horizontal: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  // ================= DESKTOP TABLE =================
  Widget _buildTable(List<Team> teams) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161A23),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withOpacity(0.07)),
                    ),
                  ),
                  child: Row(
                    children: [
                      _tableHeader('SN', flex: 1),
                      _tableHeader('Team', flex: 4),
                      _tableHeader('Abbr.', flex: 2),
                      _tableHeader('Coach', flex: 3),
                      _tableHeader('Players', flex: 2),
                      _tableHeader('Actions', flex: 2,
                          align: TextAlign.right),
                    ],
                  ),
                ),
                ...teams.asMap().entries.map((entry) {
                    final i = entry.key;
                    final team = entry.value;
                  return _TeamTableRow(
    team: team,
    index: i,
    serialNumber: i + 1,
    initials: _initials(team.name),
    getCoachName: _getCoachName,
    onView: () => context.go(
      '/team_details',
      extra: team.id,
    ),

                  /*  onEdit: () =>
                        context.go('/edit_team/${entry.value.id}'),*/
                        onEdit: () {
  setState(() {
    _editingTeam = team;
  });
},
                    onDelete: () => _confirmDeleteTeam(
                        context, entry.value, _teamService),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildCountFooter(teams.length),
        ],
      ),
    );
  }

  Widget _tableHeader(String label,
      {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: align,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ================= MOBILE CARD LIST =================
  Widget _buildCardList(List<Team> teams) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: teams.length + 1,
      itemBuilder: (context, i) {
        if (i == teams.length) return _buildCountFooter(teams.length);
        final team = teams[i];
        return _MobileTeamCard(
          team: team,
          serialNumber: i + 1,
          index: i,
          initials: _initials(team.name),
          getCoachName: _getCoachName,
          onView: () =>
              context.go('/team_details', extra: team.id),
          //onEdit: () => context.go('/edit_team/${team.id}'),
                                  onEdit: () {
  setState(() {
    _editingTeam = team;
  });
},
          onDelete: () =>
              _confirmDeleteTeam(context, team, _teamService),
        );
      },
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String sub,
    required Color color,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(sub,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCountFooter(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '$count team${count == 1 ? '' : 's'} total',
        style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            letterSpacing: 0.3),
      ),
    );
  }
}

// ================= DELETE DIALOG =================
Future<void> _confirmDeleteTeam(
  BuildContext context,
  Team team,
  TeamService teamService,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1E2330),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE57373).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFE57373), size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Delete Team',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Delete "${team.name}"?\n\nThis will remove the team, unassign its players and coach. This cannot be undone.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 14))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE57373).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFE57373).withOpacity(0.3)),
                      ),
                      child: const Center(
                          child: Text('Delete',
                              style: TextStyle(
                                color: Color(0xFFE57373),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (confirmed == true) {
    try {
      await teamService.deleteTeam(team.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Team deleted successfully'),
            backgroundColor: const Color(0xFF1E2330),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete team: $e'),
            backgroundColor: const Color(0xFFE57373).withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

// ================= DESKTOP TABLE ROW =================
class _TeamTableRow extends StatefulWidget {
  final Team team;
  final int index;
  final int serialNumber;
  final String initials;
  final Future<String?> Function(String) getCoachName;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TeamTableRow({
    required this.team,
    required this.index,
    required this.serialNumber,
    required this.initials,
    required this.getCoachName,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TeamTableRow> createState() => _TeamTableRowState();
}

class _TeamTableRowState extends State<_TeamTableRow> {
  bool _hovered = false;

  static const _avatarColors = [
    Color(0xFF4FC3F7),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFE57373),
    Color(0xFFBA68C8),
    Color(0xFF4DD0E1),
  ];

  @override
  Widget build(BuildContext context) {
    final color =
        _avatarColors[widget.index % _avatarColors.length];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered
              ? Colors.white.withOpacity(0.04)
              : Colors.transparent,
          border: Border(
              bottom:
                  BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 13),
        child: Row(
          children: [
            // SN
            Expanded(
              flex: 1,
              child: Text('${widget.serialNumber}',
                  style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),

            // Team name + logo/initials
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _TeamAvatar(
                      team: widget.team,
                      initials: widget.initials,
                      color: color),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.team.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Abbr
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.team.abbr ?? '—',
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),

            // Coach
            Expanded(
              flex: 3,
              child: widget.team.coachId == null
                  ? Text('—',
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13))
                  : FutureBuilder<String?>(
                      future:
                          widget.getCoachName(widget.team.coachId!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.grey.shade600,
                            ),
                          );
                        }
                        return Text(
                          snapshot.data ?? '—',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
            ),

            // Players count
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(Icons.people_alt_rounded,
                      size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 5),
                  Text(
                    '${widget.team.players?.length ?? 0}',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Actions
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                    icon: Icons.visibility_rounded,
                    color: const Color(0xFF81C784),
                    tooltip: 'View',
                    onTap: widget.onView,
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF4FC3F7),
                    tooltip: 'Edit',
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFE57373),
                    tooltip: 'Delete',
                    onTap: widget.onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= MOBILE TEAM CARD =================
class _MobileTeamCard extends StatefulWidget {
  final Team team;
  final int serialNumber;
  final int index;
  final String initials;
  final Future<String?> Function(String) getCoachName;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobileTeamCard({
    required this.team,
    required this.serialNumber,
    required this.index,
    required this.initials,
    required this.getCoachName,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_MobileTeamCard> createState() => _MobileTeamCardState();
}

class _MobileTeamCardState extends State<_MobileTeamCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  static const _avatarColors = [
    Color(0xFF4FC3F7),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFE57373),
    Color(0xFFBA68C8),
    Color(0xFF4DD0E1),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 40),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        _avatarColors[widget.index % _avatarColors.length];

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF161A23),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // SN
              SizedBox(
                width: 22,
                child: Text('${widget.serialNumber}',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),

              _TeamAvatar(
                  team: widget.team,
                  initials: widget.initials,
                  color: color),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.team.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.team.abbr != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(widget.team.abbr!,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.manage_accounts_outlined,
                            size: 11,
                            color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        widget.team.coachId == null
                            ? Text('No coach',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11))
                            : FutureBuilder<String?>(
                                future: widget.getCoachName(
                                    widget.team.coachId!),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.data ?? '...',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11),
                                  );
                                },
                              ),
                        const SizedBox(width: 10),
                        Icon(Icons.people_alt_outlined,
                            size: 11,
                            color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.team.players?.length ?? 0} players',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.visibility_rounded,
                color: const Color(0xFF81C784),
                tooltip: 'View',
                onTap: widget.onView,
              ),
              const SizedBox(width: 4),
              _ActionBtn(
                icon: Icons.edit_rounded,
                color: const Color(0xFF4FC3F7),
                tooltip: 'Edit',
                onTap: widget.onEdit,
              ),
              const SizedBox(width: 4),
              _ActionBtn(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFE57373),
                tooltip: 'Delete',
                onTap: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= TEAM AVATAR =================
class _TeamAvatar extends StatelessWidget {
  final Team team;
  final String initials;
  final Color color;

  const _TeamAvatar({
    required this.team,
    required this.initials,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (team.logoUrl != null && team.logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          team.logoUrl!,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _initialsAvatar(initials, color),
        ),
      );
    }
    return _initialsAvatar(initials, color);
  }

  Widget _initialsAvatar(String initials, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Center(
        child: Text(initials,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ================= ACTION BUTTON =================
class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withOpacity(0.18)
                  : widget.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, color: widget.color, size: 15),
          ),
        ),
      ),
    );
  }
}

// ================= ANIMATED FAB =================
class _AnimatedFab extends StatefulWidget {
  final VoidCallback onPressed;

  const _AnimatedFab({required this.onPressed});

  @override
  State<_AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<_AnimatedFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale =
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    Future.delayed(
        const Duration(milliseconds: 300), () => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FloatingActionButton(
        onPressed: widget.onPressed,
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }
}