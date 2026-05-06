import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kklivescoreadmin/admins/app_manager/admin_body_view.dart';
import 'package:kklivescoreadmin/admins/management/reusables/edit_player_panel.dart';
import 'package:kklivescoreadmin/admins/management/screens/create_player_screen.dart';
//import 'package:kklivescoreadmin/admins/management/reusables/player_table_row.dart';
import '../reusables/constants.dart';
import '../models/player_model.dart';
import '../services/player_service.dart';
import '../reusables/custom_progress_indicator.dart';
import '../reusables/custom_dialog.dart';

// ================= SORT OPTIONS =================
enum _SortOption { none, team, state }

class PlayerListScreen extends StatefulWidget {
  final PlayerService playerService = PlayerService();
  final void Function(AdminBodyView view, {Player? player}) onNavigate;

  PlayerListScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  State<PlayerListScreen> createState() => _PlayerListScreenState();
}

class _PlayerListScreenState extends State<PlayerListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  List<Player> _filteredPlayers = [];

  _SortOption _sortOption = _SortOption.none;
  bool _sortAscending = true;
  bool _searchFocused = false;

bool _creatingPlayer = false;
Player? _editingPlayer;

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

  List<Player> _filterAndSort(List<Player> players, String query) {
    // Filter
    List<Player> result = query.isEmpty
        ? List.from(players)
        : players
            .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
            .toList();

    // Sort
    if (_sortOption == _SortOption.team) {
      result.sort((a, b) {
        final ta = (a.team ?? '').toLowerCase();
        final tb = (b.team ?? '').toLowerCase();
        return _sortAscending ? ta.compareTo(tb) : tb.compareTo(ta);
      });
    } else if (_sortOption == _SortOption.state) {
      result.sort((a, b) {
        final sa = a.state.toLowerCase();
        final sb = b.state.toLowerCase();
        return _sortAscending ? sa.compareTo(sb) : sb.compareTo(sa);
      });
    }

    return result;
  }

  void _toggleSort(_SortOption option) {
    setState(() {
      if (_sortOption == option) {
        _sortAscending = !_sortAscending;
      } else {
        _sortOption = option;
        _sortAscending = true;
      }
    });
  }

  void _clearSort() {
    setState(() {
      _sortOption = _SortOption.none;
      _sortAscending = true;
    });
  }

  Future<void> _deletePlayer(Player player) async {
    final confirm = await CustomDialog.show(
      context,
      title: 'Confirm Delete',
      message: 'Are you sure you want to delete ${player.name}?',
      type: DialogType.warning,
    );

    if (confirm != true) return;

    try {
      await widget.playerService.deletePlayer(player.id);
      if (!mounted) return;
      CustomDialog.show(
        context,
        title: 'Deleted',
        message: '${player.name} has been deleted.',
        type: DialogType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomDialog.show(
        context,
        title: 'Error',
        message: 'Failed to delete player: $e',
        type: DialogType.error,
      );
    }
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
        children:[
          FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // ================= HEADER =================
            _buildHeader(context, isMobile),

            // ================= SORT CHIPS =================
            _buildSortBar(),

            // ================= BODY =================
            Expanded(
              child: StreamBuilder<List<Player>>(
                stream: widget.playerService.streamPlayers(),
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
                      icon: Icons.people_alt_rounded,
                      message: 'No players found',
                      sub: 'Add your first player using the + button',
                      color: const Color(0xFF4FC3F7),
                    );
                  }

                  final players = snapshot.data!;
                  _filteredPlayers =
                      _filterAndSort(players, _searchController.text);

                  if (_filteredPlayers.isEmpty) {
                    return _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      message: 'No results found',
                      sub: 'Try a different search term',
                      color: const Color(0xFF81C784),
                    );
                  }

                  return isMobile
                      ? _buildCardList(_filteredPlayers)
                      : _buildTable(_filteredPlayers);
                },
              ),
            ),
          ],
        ),
      ),

              // ================= EDIT PANEL OVERLAY =================
        if (_editingPlayer != null)
          EditPlayerPanel(
            player: _editingPlayer!,
            onDone: () {
              setState(() {
                _editingPlayer = null;
              });
            },
          ),
          
          if (_creatingPlayer)
  CreatePlayerPanel(
    onDone: () {
      setState(() {
        _creatingPlayer = false;
      });
    },
  ),
      ],
    ),

      // ================= FAB =================
      floatingActionButton: _AnimatedFab(
       onPressed: () {
  setState(() {
    _creatingPlayer = true;
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
          Row(
            children: [
              _buildIconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => context.go('/admin_panel'),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Players',
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
                hintText: 'Search players...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade600, fontSize: 14),
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

  // ================= SORT BAR =================
  Widget _buildSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161A23),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'SORT BY',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 10),
          _SortChip(
            label: 'Team',
            icon: Icons.shield_outlined,
            isActive: _sortOption == _SortOption.team,
            ascending: _sortAscending,
            onTap: () => _toggleSort(_SortOption.team),
          ),
          const SizedBox(width: 8),
          _SortChip(
            label: 'State',
            icon: Icons.flag_outlined,
            isActive: _sortOption == _SortOption.state,
            ascending: _sortAscending,
            onTap: () => _toggleSort(_SortOption.state),
          ),
          if (_sortOption != _SortOption.none) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _clearSort,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded,
                        size: 12, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          // Player count badge
          StreamBuilder<List<Player>>(
            stream: widget.playerService.streamPlayers(),
            builder: (context, snapshot) {
              final total = snapshot.data?.length ?? 0;
              final showing = _filteredPlayers.length;
              return Text(
                _sortOption != _SortOption.none ||
                        _searchController.text.isNotEmpty
                    ? '$showing / $total'
                    : '$total total',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= DESKTOP TABLE =================
  Widget _buildTable(List<Player> players) {
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
                      _tableHeader('SN', flex: 1),
                      _tableHeader('Player', flex: 4),
                      _tableHeader('Team', flex: 3),
                      _tableHeader('State', flex: 2),
                      _tableHeader('Actions', flex: 2,
                          align: TextAlign.right),
                    ],
                  ),
                ),
                // Rows
                ...players.asMap().entries.map((entry) {
                  return _PlayerTableRow(
                    player: entry.value,
                    index: entry.key,
                    serialNumber: entry.key + 1,
                    initials: _initials(entry.value.name),
                   // onEdit: (p) => context.go('/edit_player', extra: p.id),
                   onEdit: (p) {
  setState(() {
    _editingPlayer = (p);
  });
},
                    onTransfer: (p) => _showTransferDialog(p),
                    onDelete: (p) => _deletePlayer(p),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildCountFooter(players.length),
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
  Widget _buildCardList(List<Player> players) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: players.length + 1,
      itemBuilder: (context, i) {
        if (i == players.length) return _buildCountFooter(players.length);
        final player = players[i];
        return _MobilePlayerCard(
          player: player,
          serialNumber: i + 1,
          index: i,
          initials: _initials(player.name),
          //onEdit: (p) => context.go('/edit_player', extra: p.id),
                             onEdit: (p) {
  setState(() {
    _editingPlayer = (p);
  });
},
          onTransfer: (p) => _showTransferDialog(p),
          onDelete: (p) => _deletePlayer(p),
        );
      },
    );
  }

  // ================= TRANSFER DIALOG =================
  void _showTransferDialog(Player player) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E2330),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
                      color: const Color(0xFFFFB74D).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded,
                        color: Color(0xFFFFB74D), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Transfer Player',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Transfer ${player.name} to another team?',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB74D).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFFB74D)
                                  .withOpacity(0.3)),
                        ),
                        child: const Center(
                          child: Text('Confirm',
                              style: TextStyle(
                                color: Color(0xFFFFB74D),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
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
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCountFooter(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        '$count player${count == 1 ? '' : 's'}'
        '${_sortOption != _SortOption.none ? ' · sorted by ${_sortOption.name}' : ''}',
        style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            letterSpacing: 0.3),
      ),
    );
  }
}

// ================= SORT CHIP =================
class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool ascending;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryColor.withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppColors.primaryColor.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color:
                    isActive ? AppColors.primaryColor : Colors.grey.shade600),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? AppColors.primaryColor
                    : Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 11,
                color: AppColors.primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ================= DESKTOP PLAYER ROW =================
class _PlayerTableRow extends StatefulWidget {
  final Player player;
  final int index;
  final int serialNumber;
  final String initials;
  final void Function(Player) onEdit;
  final void Function(Player) onTransfer;
  final void Function(Player) onDelete;

  const _PlayerTableRow({
    required this.player,
    required this.index,
    required this.serialNumber,
    required this.initials,
    required this.onEdit,
    required this.onTransfer,
    required this.onDelete,
  });

  @override
  State<_PlayerTableRow> createState() => _PlayerTableRowState();
}

class _PlayerTableRowState extends State<_PlayerTableRow> {
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
            bottom:
                BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            // SN
            Expanded(
              flex: 1,
              child: Text(
                '${widget.serialNumber}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Player name + avatar
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _Avatar(initials: widget.initials, color: color),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      widget.player.name,
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
                widget.player.team ?? '—',
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // State
            Expanded(
              flex: 2,
              child: _StateBadge(state: widget.player.state),
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
                    onTap: () => widget.onEdit(widget.player),
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.swap_horiz_rounded,
                    color: const Color(0xFFFFB74D),
                    tooltip: 'Transfer',
                    onTap: () => widget.onTransfer(widget.player),
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFE57373),
                    tooltip: 'Delete',
                    onTap: () => widget.onDelete(widget.player),
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

// ================= MOBILE PLAYER CARD =================
class _MobilePlayerCard extends StatefulWidget {
  final Player player;
  final int serialNumber;
  final int index;
  final String initials;
  final void Function(Player) onEdit;
  final void Function(Player) onTransfer;
  final void Function(Player) onDelete;

  const _MobilePlayerCard({
    required this.player,
    required this.serialNumber,
    required this.index,
    required this.initials,
    required this.onEdit,
    required this.onTransfer,
    required this.onDelete,
  });

  @override
  State<_MobilePlayerCard> createState() => _MobilePlayerCardState();
}

class _MobilePlayerCardState extends State<_MobilePlayerCard>
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

    Future.delayed(
        Duration(milliseconds: widget.index * 40),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColors[widget.index % _avatarColors.length];

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
                width: 24,
                child: Text(
                  '${widget.serialNumber}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              _Avatar(initials: widget.initials, color: color),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.player.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 11,
                            color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.player.team ?? 'No team',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StateBadge(
                            state: widget.player.state, small: true),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.edit_rounded,
                color: const Color(0xFF4FC3F7),
                tooltip: 'Edit',
                onTap: () => widget.onEdit(widget.player),
              ),
              const SizedBox(width: 4),
              _ActionBtn(
                icon: Icons.swap_horiz_rounded,
                color: const Color(0xFFFFB74D),
                tooltip: 'Transfer',
                onTap: () => widget.onTransfer(widget.player),
              ),
              const SizedBox(width: 4),
              _ActionBtn(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFE57373),
                tooltip: 'Delete',
                onTap: () => widget.onDelete(widget.player),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= STATE BADGE =================
class _StateBadge extends StatelessWidget {
  final String? state;
  final bool small;

  const _StateBadge({this.state, this.small = false});

  Color _color(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'active':
        return const Color(0xFF81C784);
      case 'injured':
        return const Color(0xFFE57373);
      case 'suspended':
        return const Color(0xFFFFB74D);
      case 'inactive':
        return const Color(0xFF90A4AE);
      default:
        return const Color(0xFF78909C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = state ?? '—';
    final c = _color(state);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w600,
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
      width: 36,
      height: 36,
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
            fontSize: 12,
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
        foregroundColor: AppColors.secondaryColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }
}