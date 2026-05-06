// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/league_manager/live_updater/live_updater_screen.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

// ── Design tokens ──
const _kBg = Color(0xFF0F1117);
const _kSurface = Color(0xFF161A23);
const _kSurface2 = Color(0xFF1A1F2E);
const _kGreen = Color(0xFF81C784);
const _kAmber = Color(0xFFFFB74D);
const _kBlue = Color(0xFF4FC3F7);
const _kRed = Color(0xFFE57373);
const _kPurple = Color(0xFFBA68C8);

const int _pageSize = 8;

DocumentSnapshot? _lastMatchDoc;
bool _isLoadingMore = false;
bool _hasMore = true;

final Map<String, String> _teamNameCache = {};

class MatchSelectorScreen extends StatefulWidget {
  const MatchSelectorScreen({super.key});

  @override
  State<MatchSelectorScreen> createState() => _MatchSelectorScreenState();
}

class _MatchSelectorScreenState extends State<MatchSelectorScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedLeagueId;
  String? _selectedLeagueName;
  String? _selectedMatchId;
  String? _teamAId;
  String? _teamBId;
  String? _teamAName;
  String? _teamBName;

  List<Map<String, dynamic>> _teamAPlayers = [];
  List<Map<String, dynamic>> _teamBPlayers = [];
  List<Map<String, dynamic>> _selectedTeamAPlayers = [];
  List<Map<String, dynamic>> _selectedTeamBPlayers = [];

  bool _loading = false;
  bool _loadingMatchDetails = false;

  final List<QueryDocumentSnapshot> _matchDocs = [];
  StreamSubscription<QuerySnapshot>? _matchesSubscription;
  bool _matchesLoading = false;
  bool _matchesError = false;
  String? _matchesErrorMessage;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Step state: 0=league, 1=match, 2=lineups, 3=ready
  int get _currentStep {
    if (_selectedLeagueId == null) return 0;
    if (_selectedMatchId == null) return 1;
    if (_teamAPlayers.isNotEmpty || _teamBPlayers.isNotEmpty) return 2;
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _matchesSubscription?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── HELPERS ──
  Future<List<Map<String, dynamic>>> _fetchPlayersByIds(
      List<dynamic> ids) async {
    if (ids.isEmpty) return [];
    final snapshot = await _firestore
        .collection('players')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc['name']})
        .toList();
  }

  Future<String> _getTeamName(String teamId) async {
    if (_teamNameCache.containsKey(teamId)) return _teamNameCache[teamId]!;
    final doc = await _firestore.collection('teams').doc(teamId).get();
    final name = doc.data()?['name'] ?? 'Unknown';
    _teamNameCache[teamId] = name;
    return name;
  }

  Future<void> _loadMatchDetails(
      String leagueId, String matchId) async {
    setState(() => _loadingMatchDetails = true);
    try {
      final matchDoc = await _firestore
          .collection('leagues')
          .doc(leagueId)
          .collection('matches')
          .doc(matchId)
          .get();

      if (matchDoc.exists) {
        final data = matchDoc.data()!;
        _teamAId = data['teamAId'];
        _teamBId = data['teamBId'];

        final teamASnap =
            await _firestore.collection('teams').doc(_teamAId).get();
        final teamBSnap =
            await _firestore.collection('teams').doc(_teamBId).get();

        _teamAName = teamASnap.data()?['name'] ?? 'Unknown';
        _teamBName = teamBSnap.data()?['name'] ?? 'Unknown';

        final playersAIds =
            List<dynamic>.from(teamASnap.data()?['players'] ?? []);
        final playersBIds =
            List<dynamic>.from(teamBSnap.data()?['players'] ?? []);

        final playersA = await _fetchPlayersByIds(playersAIds);
        final playersB = await _fetchPlayersByIds(playersBIds);

        if (mounted) {
          setState(() {
            _teamAPlayers = playersA;
            _teamBPlayers = playersB;
          });
          _fadeCtrl.forward(from: 0.6);
        }
      } else {
        if (mounted) {
          setState(() {
            _teamAId = null;
            _teamBId = null;
            _teamAName = null;
            _teamBName = null;
            _teamAPlayers = [];
            _teamBPlayers = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading match details: $e');
      if (mounted) {
        _showSnack('Failed to load match details.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _loadingMatchDetails = false);
    }
  }

  Future<void> _saveLineups() async {
    if (_selectedLeagueId == null || _selectedMatchId == null) return;
    setState(() => _loading = true);

    final matchRef = _firestore
        .collection('leagues')
        .doc(_selectedLeagueId)
        .collection('matches')
        .doc(_selectedMatchId);

    try {
      if (_selectedTeamAPlayers.isNotEmpty && _teamAId != null) {
        await matchRef.collection('lineups').doc(_teamAId).set(
            {'teamId': _teamAId, 'players': _selectedTeamAPlayers});
      }
      if (_selectedTeamBPlayers.isNotEmpty && _teamBId != null) {
        await matchRef.collection('lineups').doc(_teamBId).set(
            {'teamId': _teamBId, 'players': _selectedTeamBPlayers});
      }
    } catch (e) {
      debugPrint('Error saving lineups: $e');
      if (mounted) _showSnack('Failed to save lineups.', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: LiveUpdaterScreen(
              leagueId: _selectedLeagueId!,
              matchId: _selectedMatchId!,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  // ── MATCH PAGINATION ──
  Query _matchesBaseQuery(String leagueId) {
    return _firestore
        .collection('leagues')
        .doc(leagueId)
        .collection('matches')
        .where('status', isNotEqualTo: 'completed')
        .orderBy('status')
        .orderBy('date');
  }

  Future<void> _resetAndFetchMatches() async {
    await _matchesSubscription?.cancel();
    _matchesSubscription = null;
    _matchDocs.clear();
    _lastMatchDoc = null;
    _hasMore = true;
    _isLoadingMore = false;
    _matchesError = false;
    _matchesErrorMessage = null;
    if (_selectedLeagueId != null) await _fetchInitialMatches();
    else setState(() {});
  }

  Future<void> _fetchInitialMatches() async {
    if (_selectedLeagueId == null) return;
    setState(() {
      _matchesLoading = true;
      _matchesError = false;
      _matchesErrorMessage = null;
    });
    try {
      final snapshot = await _matchesBaseQuery(_selectedLeagueId!)
          .limit(_pageSize)
          .get();
      _matchDocs
        ..clear()
        ..addAll(snapshot.docs);
      _lastMatchDoc =
          snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length == _pageSize;
      _subscribeToMatches();
    } catch (e) {
      debugPrint('Error fetching initial matches: $e');
      _matchesError = true;
      _matchesErrorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _matchesLoading = false);
    }
  }

  Future<void> _loadMoreMatches() async {
    if (_selectedLeagueId == null ||
        !_hasMore ||
        _isLoadingMore ||
        _lastMatchDoc == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final more = await _matchesBaseQuery(_selectedLeagueId!)
          .startAfterDocument(_lastMatchDoc!)
          .limit(_pageSize)
          .get();
      if (more.docs.isNotEmpty) {
        _matchDocs.addAll(more.docs);
        _lastMatchDoc = more.docs.last;
      }
      _hasMore = more.docs.length == _pageSize;
      _subscribeToMatches();
    } catch (e) {
      debugPrint('Error loading more matches: $e');
      if (mounted) _showSnack('Failed to load more matches.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _subscribeToMatches() {
    _matchesSubscription?.cancel();
    _matchesSubscription = null;
    if (_selectedLeagueId == null || _matchDocs.isEmpty) return;

    final limit = _matchDocs.length;
    _matchesSubscription = _matchesBaseQuery(_selectedLeagueId!)
        .limit(limit)
        .snapshots()
        .listen((snapshot) {
      final realtimeDocs = snapshot.docs;
      final remaining = _matchDocs.length > realtimeDocs.length
          ? _matchDocs.sublist(realtimeDocs.length)
          : <QueryDocumentSnapshot>[];
      _matchDocs
        ..clear()
        ..addAll(realtimeDocs)
        ..addAll(remaining);
      setState(() {});
    }, onError: (e) {
      debugPrint('Matches subscription error: $e');
      setState(() {
        _matchesError = true;
        _matchesErrorMessage = e.toString();
      });
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? _kRed.withOpacity(0.9) : _kSurface2,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _fmtDate(Timestamp ts) {
    final dt = ts.toDate();
    return DateFormat('dd MMM yyyy  HH:mm').format(dt);
  }

  // ════════════════════════════════════════
  //   BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(context),
            if (_loading)
              const LinearProgressIndicator(
                  backgroundColor: Colors.transparent, color: _kBlue),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step 1: League
                    _buildStepCard(
                      step: 1,
                      title: 'Select League',
                      subtitle: _selectedLeagueName ?? 'Choose a league to continue',
                      icon: Icons.emoji_events_rounded,
                      color: _kAmber,
                      isDone: _selectedLeagueId != null,
                      child: _buildLeagueDropdown(),
                    ),

                    const SizedBox(height: 14),

                    // Step 2: Match
                    AnimatedOpacity(
                      opacity: _selectedLeagueId != null ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 300),
                      child: _buildStepCard(
                        step: 2,
                        title: 'Select Match',
                        subtitle: _selectedMatchId != null
                            ? 'Match selected'
                            : 'Choose a match to manage',
                        icon: Icons.sports_soccer_rounded,
                        color: _kBlue,
                        isDone: _selectedMatchId != null,
                        child: _selectedLeagueId == null
                            ? _buildLockedHint('Select a league first')
                            : _buildMatchList(),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Step 3: Lineups
                    AnimatedOpacity(
                      opacity: _selectedMatchId != null ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 300),
                      child: _buildStepCard(
                        step: 3,
                        title: 'Set Lineups',
                        subtitle: 'Optional — select starting players',
                        icon: Icons.group_rounded,
                        color: _kGreen,
                        isDone: _selectedTeamAPlayers.isNotEmpty ||
                            _selectedTeamBPlayers.isNotEmpty,
                        child: _selectedMatchId == null
                            ? _buildLockedHint('Select a match first')
                            : _buildLineupsSection(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Pinned bottom CTA
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildContinueButton(),
    );
  }

  // ── HEADER ──
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(
            bottom:
                BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live Match',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4)),
                SizedBox(height: 2),
                Text('Select a match to manage live',
                    style: TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          // Step indicator
          _StepIndicator(currentStep: _currentStep),
        ],
      ),
    );
  }

  // ── STEP CARD WRAPPER ──
  Widget _buildStepCard({
    required int step,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDone,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? color.withOpacity(0.25)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Column(
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(
                    color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: Row(
              children: [
                // Step circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDone
                        ? color.withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? color.withOpacity(0.4)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? Icon(Icons.check_rounded,
                            color: color, size: 15)
                        : Text('$step',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 1),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11)),
                    ],
                  ),
                ),
                Icon(icon,
                    color: isDone
                        ? color
                        : Colors.grey.shade700,
                    size: 18),
              ],
            ),
          ),
          // Card body
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }

  // ── LEAGUE DROPDOWN ──
  Widget _buildLeagueDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('leagues').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildInlineError(
              'Error loading leagues: ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _kBlue));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildLockedHint('No leagues available');
        }

        final leagues = snapshot.data!.docs
            .cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedLeagueId,
              isExpanded: true,
              dropdownColor: _kSurface2,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14),
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade500),
              hint: Text('Choose a league',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 14)),
              items: leagues.map((doc) {
                final data = doc.data();
                final name =
                    data['name'] as String? ?? 'Unnamed League';
                final status =
                    data['status'] as String? ?? 'inactive';
                return DropdownMenuItem(
                  value: doc.id,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: status == 'active'
                              ? _kGreen
                              : _kAmber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(name,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final leagues2 = snapshot.data!.docs;
                // Cast to avoid Dart web type mismatch with firstWhere/orElse
                final docList = leagues2
                    .cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
                final selectedDoc = docList.firstWhere(
                  (d) => d.id == val,
                  orElse: () => docList.first,
                );
                final data = selectedDoc.data();
                setState(() {
                  _selectedLeagueId = val;
                  _selectedLeagueName =
                      data['name'] as String? ?? 'League';
                  _selectedMatchId = null;
                  _teamAPlayers = [];
                  _teamBPlayers = [];
                  _selectedTeamAPlayers = [];
                  _selectedTeamBPlayers = [];
                });
                _resetAndFetchMatches();
              },
            ),
          ),
        );
      },
    );
  }

  // ── MATCH LIST ──
  Widget _buildMatchList() {
    if (_matchesLoading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _kBlue)));
    }

    if (_matchesError) {
      return Column(
        children: [
          _buildInlineError(
              'Error: ${_matchesErrorMessage ?? 'Unknown'}'),
          const SizedBox(height: 10),
          _OutlineBtn(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onTap: _fetchInitialMatches,
          ),
        ],
      );
    }

    if (_matchDocs.isEmpty) {
      return _buildLockedHint('No upcoming matches found');
    }

    return Column(
      children: [
        ...List.generate(_matchDocs.length, (index) {
          final doc = _matchDocs[index];
          final data = doc.data() as Map<String, dynamic>;
          final teamAId = data['teamAId'] as String?;
          final teamBId = data['teamBId'] as String?;
          final dateTs = data['date'] as Timestamp?;
          final status =
              (data['status'] as String? ?? 'scheduled').toLowerCase();
          final isSelected = doc.id == _selectedMatchId;

          return _MatchTile(
            index: index,
            teamAId: teamAId,
            teamBId: teamBId,
            dateTs: dateTs,
            status: status,
            isSelected: isSelected,
            getTeamName: _getTeamName,
            onTap: () {
              setState(() {
                _selectedMatchId = doc.id;
                _selectedTeamAPlayers.clear();
                _selectedTeamBPlayers.clear();
                _teamAPlayers.clear();
                _teamBPlayers.clear();
              });
              if (_selectedLeagueId != null) {
                _loadMatchDetails(_selectedLeagueId!, doc.id);
              }
            },
          );
        }),

        // Load more
        if (_hasMore) ...[
          const SizedBox(height: 8),
          _OutlineBtn(
            label: _isLoadingMore ? 'Loading...' : 'Load more',
            icon: _isLoadingMore
                ? Icons.hourglass_empty_rounded
                : Icons.expand_more_rounded,
            onTap: _isLoadingMore ? null : _loadMoreMatches,
          ),
        ],
      ],
    );
  }

  // ── LINEUPS SECTION ──
  Widget _buildLineupsSection() {
    if (_loadingMatchDetails) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2, color: _kGreen),
              SizedBox(height: 12),
              Text('Loading players...',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_teamAPlayers.isEmpty && _teamBPlayers.isEmpty) {
      return _buildLockedHint(
          'No players found for the selected match teams');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_teamAPlayers.isNotEmpty) ...[
          _lineupLabel(_teamAName ?? 'Team A', _kBlue),
          const SizedBox(height: 8),
          _buildPlayerMultiSelect(
            players: _teamAPlayers,
            teamName: _teamAName ?? 'Team A',
            selected: _selectedTeamAPlayers,
            onConfirm: (vals) {
              setState(() {
                _selectedTeamAPlayers =
                    vals.cast<Map<String, dynamic>>();
              });
            },
          ),
          const SizedBox(height: 14),
        ],
        if (_teamBPlayers.isNotEmpty) ...[
          _lineupLabel(_teamBName ?? 'Team B', _kPurple),
          const SizedBox(height: 8),
          _buildPlayerMultiSelect(
            players: _teamBPlayers,
            teamName: _teamBName ?? 'Team B',
            selected: _selectedTeamBPlayers,
            onConfirm: (vals) {
              setState(() {
                _selectedTeamBPlayers =
                    vals.cast<Map<String, dynamic>>();
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _lineupLabel(String name, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(name,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
        const SizedBox(width: 8),
        if (_selectedTeamAPlayers.isNotEmpty && color == _kBlue)
          _countBadge(_selectedTeamAPlayers.length, color),
        if (_selectedTeamBPlayers.isNotEmpty && color == _kPurple)
          _countBadge(_selectedTeamBPlayers.length, color),
      ],
    );
  }

  Widget _countBadge(int count, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text('$count selected',
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPlayerMultiSelect({
    required List<Map<String, dynamic>> players,
    required String teamName,
    required List<Map<String, dynamic>> selected,
    required void Function(List<dynamic>) onConfirm,
  }) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: AppColors.primaryColor,
          surface: _kSurface2,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.primaryColor.withOpacity(0.12),
          selectedColor: AppColors.primaryColor.withOpacity(0.25),
          labelStyle:
              const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      child: MultiSelectDialogField<Map<String, dynamic>>(
        items: players
            .map((p) => MultiSelectItem(p, p['name'] as String))
            .toList(),
        title: Text('$teamName Players',
            style: const TextStyle(color: Colors.white)),
        searchable: true,
        listType: MultiSelectListType.CHIP,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withOpacity(0.08)),
        ),
        buttonIcon: Icon(Icons.people_alt_outlined,
            color: Colors.grey.shade600, size: 17),
        buttonText: Text(
          selected.isEmpty
              ? 'Select starting players'
              : '${selected.length} players selected',
          style: TextStyle(
              color: selected.isEmpty
                  ? Colors.grey.shade600
                  : Colors.white,
              fontSize: 13),
        ),
        onConfirm: onConfirm,
      ),
    );
  }

  // ── CONTINUE BUTTON ──
  Widget _buildContinueButton() {
    final enabled = _selectedMatchId != null && !_loading;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: enabled ? _saveLineups : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            disabledBackgroundColor:
                AppColors.primaryColor.withOpacity(0.3),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sports_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Continue to Live Updater',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2)),
                  ],
                ),
        ),
      ),
    );
  }

  // ── UTILITY WIDGETS ──
  Widget _buildLockedHint(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Text(msg,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInlineError(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kRed.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 15, color: _kRed),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: _kRed, fontSize: 12))),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   MATCH TILE
// ════════════════════════════════════════════════════════════════════
class _MatchTile extends StatefulWidget {
  final int index;
  final String? teamAId;
  final String? teamBId;
  final Timestamp? dateTs;
  final String status;
  final bool isSelected;
  final Future<String> Function(String) getTeamName;
  final VoidCallback onTap;

  const _MatchTile({
    required this.index,
    required this.teamAId,
    required this.teamBId,
    required this.dateTs,
    required this.status,
    required this.isSelected,
    required this.getTeamName,
    required this.onTap,
  });

  @override
  State<_MatchTile> createState() => _MatchTileState();
}

class _MatchTileState extends State<_MatchTile>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  Color get _statusColor {
    switch (widget.status) {
      case 'scheduled': return _kBlue;
      case 'postponed': return _kAmber;
      case 'live': return _kGreen;
      default: return Colors.grey.shade600;
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.04), end: Offset.zero)
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
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppColors.primaryColor.withOpacity(0.1)
                    : _hovered
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isSelected
                      ? AppColors.primaryColor.withOpacity(0.4)
                      : _hovered
                          ? Colors.white.withOpacity(0.12)
                          : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Selected indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 4,
                        height: 36,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? AppColors.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      Expanded(
                        child: FutureBuilder<List<String>>(
                          future: Future.wait([
                            widget.teamAId != null
                                ? widget.getTeamName(widget.teamAId!)
                                : Future.value('Unknown'),
                            widget.teamBId != null
                                ? widget.getTeamName(widget.teamBId!)
                                : Future.value('Unknown'),
                          ]),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return Row(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('vs',
                                      style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 11)),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 80,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            }

                            final teamA = snap.data?[0] ?? 'Unknown';
                            final teamB = snap.data?[1] ?? 'Unknown';

                            return Row(
                              children: [
                                Expanded(
                                  child: Text(teamA,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: widget.isSelected
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 13,
                                          fontWeight: widget.isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500)),
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withOpacity(0.06),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text('VS',
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700)),
                                ),
                                Expanded(
                                  child: Text(teamB,
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: widget.isSelected
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 13,
                                          fontWeight: widget.isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500)),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      if (widget.dateTs != null) ...[
                        Icon(Icons.calendar_today_rounded,
                            size: 11,
                            color: Colors.grey.shade600),
                        const SizedBox(width: 5),
                        Text(
                          DateFormat('dd MMM  HH:mm')
                              .format(widget.dateTs!.toDate()),
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11),
                        ),
                        const SizedBox(width: 10),
                      ],
                      _StatusPill(
                          status: widget.status,
                          color: _statusColor),
                      const Spacer(),
                      if (widget.isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.primaryColor, size: 16),
                    ],
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

// ════════════════════════════════════════════════════════════════════
//   SMALL REUSABLE WIDGETS
// ════════════════════════════════════════════════════════════════════

class _StatusPill extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusPill({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _OutlineBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = i < currentStep;
        final isCurrent = i == currentStep - 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(left: 4),
          width: isCurrent ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryColor
                : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}