import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/admins/management/reusables/edit_coach_panel.dart';
import 'package:kklivescoreadmin/admins/management/screens/create_coach_screen.dart';
import '../reusables/constants.dart';
import '../models/coach_model.dart';
import '../services/coach_service.dart';
import '../reusables/custom_progress_indicator.dart';
import '../reusables/custom_dialog.dart';

class CoachListScreen extends StatefulWidget {
  final CoachService coachService = CoachService();

  CoachListScreen({super.key});

  @override
  State<CoachListScreen> createState() => _CoachListScreenState();
}

class _CoachListScreenState extends State<CoachListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  List<Coach> _filteredCoaches = [];
  bool _searchFocused = false;
  
  Coach? _editingCoach;
  bool _creatingCoach = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
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

  List<Coach> _filterCoaches(List<Coach> coaches, String query) {
    if (query.isEmpty) return coaches;
    return coaches
        .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<void> _deleteCoach(Coach coach) async {
    final confirm = await CustomDialog.show(
      context,
      title: 'Confirm Delete',
      message: 'Are you sure you want to delete ${coach.name}?',
      type: DialogType.warning,
    );

    if (confirm != true) return;

    try {
      await widget.coachService.deleteCoach(coach.id);
      if (!mounted) return;
      CustomDialog.show(
        context,
        title: 'Deleted',
        message: '${coach.name} has been deleted.',
        type: DialogType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomDialog.show(
        context,
        title: 'Error',
        message: 'Failed to delete coach: $e',
        type: DialogType.error,
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
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
        // ================= MAIN CONTENT =================
        FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // ================= HEADER =================
              _buildHeader(context, isMobile),

              // ================= BODY =================
              Expanded(
                child: StreamBuilder<List<Coach>>(
                  stream: widget.coachService.streamCoaches(),
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
                        icon: Icons.manage_accounts_rounded,
                        message: 'No coaches found',
                        sub: 'Add your first coach using the + button',
                        color: const Color(0xFFFFB74D),
                      );
                    }

                    final coaches = snapshot.data!;
                    _filteredCoaches =
                        _filterCoaches(coaches, _searchController.text);

                    if (_filteredCoaches.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.search_off_rounded,
                        message: 'No results found',
                        sub: 'Try a different search term',
                        color: const Color(0xFF4FC3F7),
                      );
                    }

                    return isMobile
                        ? _buildCardList(_filteredCoaches)
                        : _buildTable(_filteredCoaches);
                  },
                ),
              ),
            ],
          ),
        ),

        // ================= EDIT PANEL OVERLAY =================
        if (_editingCoach != null)
          EditCoachPanel(
            coach: _editingCoach!,
            onDone: () {
              setState(() {
                _editingCoach = null;
              });
            },
          ),

if (_creatingCoach)
  CreateCoachPanel(
    onDone: () {
      setState(() => _creatingCoach = false);
    },
  ),

      ],
    ),

    // ================= FAB =================
    floatingActionButton: _AnimatedFab(
    onPressed: () {
  setState(() => _creatingCoach = true);
}
    ),
  );
}
  // ================= HEADER =================
  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161A23),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
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
          // Back + Title Row
          Row(
            children: [
              _buildIconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => context.go('/admin_panel'),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Coaches',
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

          // Search Bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(_searchFocused ? 0.08 : 0.05),
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
                hintText: 'Search coaches...',
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
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(
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
  Widget _buildTable(List<Coach> coaches) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161A23),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Table Header
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
                      _tableHeader('Coach', flex: 3),
                      _tableHeader('Team', flex: 3),
                      _tableHeader('Date of Birth', flex: 2),
                      _tableHeader('Actions', flex: 2, align: TextAlign.right),
                    ],
                  ),
                ),

                // Table Rows
                ...coaches.asMap().entries.map((entry) {
                  final i = entry.key;
                  final coach = entry.value;
                  return _TableRow(
                    coach: coach,
                    index: i,
                    initials: _initials(coach.name),
                    formattedDate: _formatDate(coach.dateOfBirth),
                   onEdit: () {
                            setState(() {
                              _editingCoach = coach;
                            });
                          },
                    onDelete: () => _deleteCoach(coach),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _buildCountFooter(coaches.length),
        ],
      ),
    );
  }

  Widget _tableHeader(String label,
      {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
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
  Widget _buildCardList(List<Coach> coaches) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: coaches.length + 1,
      itemBuilder: (context, i) {
        if (i == coaches.length) return _buildCountFooter(coaches.length);
        final coach = coaches[i];
        return _MobileCoachCard(
          coach: coach,
          initials: _initials(coach.name),
          formattedDate: _formatDate(coach.dateOfBirth),
          onEdit: () {
              setState(() {
                _editingCoach = coach;
              });
            },
          onDelete: () => _deleteCoach(coach),
          index: i,
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
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ================= COUNT FOOTER =================
  Widget _buildCountFooter(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '$count coach${count == 1 ? '' : 'es'} total',
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ================= DESKTOP TABLE ROW =================
class _TableRow extends StatefulWidget {
  final Coach coach;
  final int index;
  final String initials;
  final String formattedDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TableRow({
    required this.coach,
    required this.index,
    required this.initials,
    required this.formattedDate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
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
    final color = _avatarColors[widget.index % _avatarColors.length];

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
            bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Name + Avatar
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _Avatar(initials: widget.initials, color: color),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.coach.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Team
            Expanded(
              flex: 3,
              child: Text(
                widget.coach.teamName ?? '—',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // DOB
            Expanded(
              flex: 2,
              child: Text(
                widget.formattedDate,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ),

            // Actions
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF4FC3F7),
                    tooltip: 'Edit',
                    onTap: widget.onEdit,
                  ),
                  const SizedBox(width: 8),
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

// ================= MOBILE COACH CARD =================
class _MobileCoachCard extends StatefulWidget {
  final Coach coach;
  final int index;
  final String initials;
  final String formattedDate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MobileCoachCard({
    required this.coach,
    required this.index,
    required this.initials,
    required this.formattedDate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_MobileCoachCard> createState() => _MobileCoachCardState();
}

class _MobileCoachCardState extends State<_MobileCoachCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(
        Duration(milliseconds: widget.index * 40), () {
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
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _Avatar(initials: widget.initials, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.coach.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 12,
                            color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          widget.coach.teamName ?? 'No team',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.cake_outlined,
                            size: 12,
                            color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          widget.formattedDate,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
      ),
    );
  }
}

// ================= AVATAR =================
class _Avatar extends StatelessWidget {
  final String initials;
  final Color color;

  const _Avatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withOpacity(0.18)
                  : widget.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, color: widget.color, size: 16),
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
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    Future.delayed(const Duration(milliseconds: 300),
        () => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
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
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }
}
