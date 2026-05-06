import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/league_manager/firestore_service.dart';
import 'league_initialization_screen.dart';

const _kSurface = Color(0xFF161A23);
const _kSurface2 = Color(0xFF1A1F2E);
const _kBg = Color(0xFF0F1117);
const _kGreen = Color(0xFF81C784);
const _kAmber = Color(0xFFFFB74D);
const _kBlue = Color(0xFF4FC3F7);
const _kRed = Color(0xFFE57373);

class LeagueListScreen extends StatefulWidget {
  const LeagueListScreen({super.key});

  @override
  State<LeagueListScreen> createState() => _LeagueListScreenState();
}

class _LeagueListScreenState extends State<LeagueListScreen>
    with TickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<dynamic> _leagues = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  bool _searchFocused = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _searchController.addListener(_onSearch);
    _searchFocus.addListener(
        () => setState(() => _searchFocused = _searchFocus.hasFocus));

    _loadLeagues();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadLeagues() async {
    setState(() => _loading = true);
    final docs = await _firestoreService.fetchLeagues();
    setState(() {
      _leagues = docs;
      _filtered = docs;
      _loading = false;
    });
    _fadeCtrl.forward(from: 0);
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _leagues
          : _leagues.where((doc) {
              final data = (doc as dynamic).data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final season = (data['season'] ?? '').toString().toLowerCase();
              return name.contains(q) || season.contains(q);
            }).toList();
    });
  }

  void _openLeague(dynamic doc) {
    final data = doc.data() as Map<String, dynamic>;
    final id = doc.id as String;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: LeagueInitializationScreen(leagueId: id),
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 650;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: _filtered.isEmpty
                        ? _buildEmptyState()
                        : _buildLeagueList(isMobile),
                  ),
          ),
        ],
      ),
      floatingActionButton: _AnimatedFab(
        onPressed: () => context.push('/create_league'),
      ),
    );
  }

  // ── HEADER ──
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
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
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Leagues',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              // Refresh button
              _iconBtn(
                icon: Icons.refresh_rounded,
                onTap: _loadLeagues,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Search bar
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
              style:
                  const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search leagues...',
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
                          _onSearch();
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
          border:
              Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  // ── LEAGUE LIST ──
  Widget _buildLeagueList(bool isMobile) {
    return RefreshIndicator(
      color: AppColors.primaryColor,
      backgroundColor: _kSurface2,
      onRefresh: _loadLeagues,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _filtered.length + 1,
        itemBuilder: (context, i) {
          if (i == _filtered.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  '${_filtered.length} league${_filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      letterSpacing: 0.3),
                ),
              ),
            );
          }
          return _LeagueCard(
            doc: _filtered[i],
            index: i,
            onTap: () => _openLeague(_filtered[i]),
          );
        },
      ),
    );
  }

  // ── EMPTY STATE ──
  Widget _buildEmptyState() {
    final hasQuery = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              hasQuery
                  ? Icons.search_off_rounded
                  : Icons.emoji_events_rounded,
              color: _kBlue,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'No results found' : 'No leagues yet',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery
                ? 'Try a different search term'
                : 'Tap + to create your first league',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   LEAGUE CARD
// ════════════════════════════════════════════════════════════════════
class _LeagueCard extends StatefulWidget {
  final dynamic doc;
  final int index;
  final VoidCallback onTap;

  const _LeagueCard({
    required this.doc,
    required this.index,
    required this.onTap,
  });

  @override
  State<_LeagueCard> createState() => _LeagueCardState();
}

class _LeagueCardState extends State<_LeagueCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  static const _accentColors = [
    _kBlue, _kGreen, _kAmber, _kRed,
    Color(0xFFBA68C8), Color(0xFF4DD0E1),
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

    Future.delayed(
        Duration(milliseconds: widget.index * 50),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final name = data['name'] as String? ?? 'Unnamed League';
    final season = data['season'] as String? ?? '—';
    final status = (data['status'] as String? ?? 'inactive').toLowerCase();
    final system = data['MatchesSystem'] as String? ?? '—';
    final teams = data['NumberOfTeams'];
    final groups = data['NumberOfGroups'];
    final logoUrl = data['logoUrl'] as String?;
    final isActive = status == 'active';
    final color = _accentColors[widget.index % _accentColors.length];

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _hovered
                    ? Colors.white.withOpacity(0.06)
                    : _kSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hovered
                      ? color.withOpacity(0.25)
                      : Colors.white.withOpacity(0.07),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Logo / Initials avatar
                  _LeagueAvatar(
                      name: name, logoUrl: logoUrl, color: color),
                  const SizedBox(width: 14),

                  // Main info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusDot(isActive: isActive),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _MetaChip(
                              icon: Icons.calendar_today_rounded,
                              label: season,
                            ),
                            if (teams != null)
                              _MetaChip(
                                icon: Icons.people_alt_rounded,
                                label: '$teams teams',
                              ),
                            if (groups != null && groups != 0)
                              _MetaChip(
                                icon: Icons.grid_view_rounded,
                                label: '$groups groups',
                              ),
                            _MetaChip(
                              icon: Icons.sports_soccer_rounded,
                              label: system,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _hovered ? color : Colors.grey.shade700,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── League logo / initials avatar ──
class _LeagueAvatar extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final Color color;

  const _LeagueAvatar({
    required this.name,
    required this.logoUrl,
    required this.color,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'L';
  }

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          logoUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsWidget(),
        ),
      );
    }
    return _initialsWidget();
  }

  Widget _initialsWidget() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Active/Inactive dot badge ──
class _StatusDot extends StatelessWidget {
  final bool isActive;
  const _StatusDot({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final c = isActive ? _kGreen : _kAmber;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
                color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
                color: c,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Small meta info chip ──
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   ANIMATED FAB
// ════════════════════════════════════════════════════════════════════
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
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }
}