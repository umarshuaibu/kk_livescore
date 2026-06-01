// ignore_for_file: unnecessary_to_list_in_spreads, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/league_manager/firestore_service.dart';
import 'package:kklivescoreadmin/league_manager/knockout_system/knockout_system_logics.dart';
import 'package:kklivescoreadmin/league_manager/manual_pairing.dart';
import 'package:kklivescoreadmin/league_manager/match_scheduler.dart';
import 'package:kklivescoreadmin/league_manager/match_system.dart';

// ── Accent palette (mirrors the dashboard) ──
const _kBlue = Color(0xFF4FC3F7);
const _kGreen = Color(0xFF81C784);
const _kAmber = Color(0xFFFFB74D);
const _kRed = Color(0xFFE57373);
const _kPurple = Color(0xFFBA68C8);
const _kCyan = Color(0xFF4DD0E1);
const _kSurface = Color(0xFF161A23);
const _kSurface2 = Color(0xFF1A1F2E);
const _kBg = Color(0xFF0F1117);

class LeagueInitializationScreen extends StatefulWidget {
  final String leagueId;
  const LeagueInitializationScreen({super.key, required this.leagueId});

  @override
  State<LeagueInitializationScreen> createState() =>
      _LeagueInitializationScreenState();
}

class _LeagueInitializationScreenState
    extends State<LeagueInitializationScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _firestoreService = FirestoreService();
  late final Map<String, String> _teamIdToName;

  Map<String, dynamic>? _leagueData;
  List<Map<String, dynamic>> _leagueTeams = [];
  List<QueryDocumentSnapshot> _availableTeamDocs = [];
  DateTime? _startingDate;
  bool _loading = true;

  final Map<String, Set<String>> _groupSelections = {};
  final Set<String> _assignedTeamsSet = {};
  final List<Map<String, dynamic>> _manualPairs = [];

  bool _isInitializing = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  void _buildTeamLookup() {
    _teamIdToName = {
      for (final d in _availableTeamDocs)
        ((d.data() as Map<String, dynamic>)['teamId'] as String?) ?? d.id:
            ((d.data() as Map<String, dynamic>)['name'] as String?) ?? d.id,
    };
  }

  @override
  void initState() {
    super.initState();
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadAll();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final leagueSnap = await _firestoreService.getLeague(widget.leagueId);
    final leagueData = (leagueSnap.data() ?? {}) as Map<String, dynamic>;
    final teamDocs = await _firestoreService.fetchLeagueTeams(widget.leagueId);
    final available = await _firestoreService.fetchAvailableTeams();

    setState(() {
      _leagueData = leagueData;
      _leagueTeams = teamDocs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {'teamId': data['teamId'], 'group': data['group']};
      }).toList();
      _availableTeamDocs = available;
      _buildTeamLookup();
      _loading = false;
    });
    _fadeCtrl.forward(from: 0);
  }

  Future<void> _pickStartingDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
              primary: AppColors.primaryColor2,
              surface: _kSurface2),
          dialogBackgroundColor: _kSurface,
        ),
        child: child!,
      ),
    );
    if (d == null) return;
    setState(() => _startingDate = d);
  }

  int get numberOfTeams => (_leagueData?['NumberOfTeams'] as int?) ?? 0;
  int get numberOfGroups => (_leagueData?['NumberOfGroups'] as int?) ?? 0;

  List<String> get groupNames {
    final ng = numberOfGroups;
    return List.generate(ng, (i) => String.fromCharCode(65 + i));
  }

  int get perGroup {
    final ng = numberOfGroups == 0 ? 1 : numberOfGroups;
    return numberOfTeams ~/ ng;
  }

  void _toggleTeamForGroup(String group, String teamId) {
    final set = _groupSelections[group] ?? <String>{};
    if (set.contains(teamId)) {
      set.remove(teamId);
      _assignedTeamsSet.remove(teamId);
    } else {
      if (_assignedTeamsSet.contains(teamId)) {
        _showSnack('Team already assigned to another group', isError: true);
        return;
      }
      set.add(teamId);
      _assignedTeamsSet.add(teamId);
    }
    _groupSelections[group] = set;
    setState(() {});
  }

  bool _validateAssignments() {
    if ((_leagueData?['MatchesSystem'] as String?) == 'Knockout') {
      return _leagueTeams.length == numberOfTeams;
    }
    if (groupNames.isEmpty) return false;
    for (final g in groupNames) {
      final sel = _groupSelections[g] ?? <String>{};
      if (sel.length != perGroup) return false;
    }
    final totalAssigned =
        _groupSelections.values.fold<int>(0, (p, s) => p + s.length);
    return totalAssigned == numberOfTeams;
  }

  Future<void> _saveAssignmentsToFirestore() async {
    for (final g in groupNames) {
      final sel = _groupSelections[g] ?? <String>{};
      for (final tid in sel) {
        await _firestoreService.createLeagueTeam(
            leagueId: widget.leagueId, teamId: tid, group: g);
      }
    }
    final teamDocs = await _firestoreService.fetchLeagueTeams(widget.leagueId);
    setState(() {
      _leagueTeams = teamDocs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {'teamId': data['teamId'], 'group': data['group']};
      }).toList();
    });
  }

  // ── AUTOMATED INITIALIZATION ──
  Future<void> _initializeAutomated() async {
    if (_isInitializing) return;
    if (!_validateAssignments()) {
      await _showDialog(
          title: 'Invalid configuration',
          message: 'Teams per group must match configuration.');
      return;
    }
    if (_startingDate == null) {
      await _showDialog(title: 'Missing date', message: 'Please select a starting date.');
      return;
    }

    setState(() => _isInitializing = true);

    try {
      final matchDays = List<String>.from(_leagueData?['MatchDays'] ?? []);
      final matchesSystem = _leagueData?['MatchesSystem'] as String? ?? 'Home_and_away';
      final Map<String, List<String>> groupsMap = {};

      if (_leagueTeams.isNotEmpty) {
        for (final t in _leagueTeams) {
          final g = t['group'] as String;
          final tid = t['teamId'] as String;
          groupsMap.putIfAbsent(g, () => []).add(tid);
        }
      } else {
        for (final g in groupNames) {
          groupsMap[g] = _groupSelections[g]?.toList() ?? [];
        }
      }

      List<PlannedMatch> plannedMatches = [];

      if (matchesSystem == 'Knockout') {
        List<Map<String, dynamic>> firstRoundPairs = [];
        if (_manualPairs.isNotEmpty) {
          firstRoundPairs = generateManualMatches(pairs: _manualPairs, isKnockout: true);
        } else {
          final teams = _leagueTeams.map((t) => t['teamId'] as String).toList();
          for (int i = 0; i < teams.length; i += 2) {
            if (i + 1 < teams.length) {
              firstRoundPairs.add({'teamAId': teams[i], 'teamBId': teams[i + 1]});
            } else {
              firstRoundPairs.add({'teamAId': teams[i], 'teamBId': 'BYE'});
            }
          }
        }
        plannedMatches = knockoutTournamentFromManual(firstRoundPairs);
      } else {
        final Map<String, List<PlannedMatch>> matchesByGroup = {};
        for (final g in groupNames) {
          final teams = groupsMap[g] ?? [];
          final pairs = matchesSystem == 'Home_and_away'
              ? doubleRoundRobin(teams)
              : singleRoundRobin(teams);
          matchesByGroup[g] =
              pairs.map((p) => PlannedMatch(group: g, teamAId: p[0], teamBId: p[1])).toList();
        }
        int round = 0;
        bool hasMore = true;
        while (hasMore) {
          hasMore = false;
          for (final g in groupNames) {
            final groupMatches = matchesByGroup[g]!;
            if (round < groupMatches.length) {
              plannedMatches.add(groupMatches[round]);
              hasMore = true;
            }
          }
          round++;
        }
      }

      if (plannedMatches.isEmpty) throw Exception('No matches generated');

      final globalDates = scheduleMatches(
          startDate: _startingDate!,
          matchDays: matchDays,
          totalMatches: plannedMatches.length);

      if (globalDates.length < plannedMatches.length) {
        throw Exception('Not enough dates generated');
      }

      final List<Future<void>> writeTasks = [];
      for (int i = 0; i < plannedMatches.length; i++) {
        final m = plannedMatches[i];
        final id = _firestore.collection('x').doc().id;
        writeTasks.add(_firestoreService.createMatch(
            leagueId: widget.leagueId,
            matchId: id,
            matchData: {
              'id': id,
              'leagueId': widget.leagueId,
              'group': m.group,
              'teamAId': m.teamAId,
              'teamBId': m.teamBId,
              'status': 'scheduled',
              'date': globalDates[i],
            }));
      }

      final teamDocs = await _firestoreService.fetchLeagueTeams(widget.leagueId);
      for (final d in teamDocs) {
        final data = d.data() as Map<String, dynamic>;
        final teamId = data['teamId'] as String;
        final group = data['group'] as String? ?? '';
        writeTasks.add(_firestoreService.createStanding(
            leagueId: widget.leagueId,
            teamId: teamId,
            standingData: {
              'teamId': teamId,
              'leagueId': widget.leagueId,
              'group': group,
              'played': 0, 'won': 0, 'drawn': 0, 'lost': 0,
              'goalsFor': 0, 'goalsAgainst': 0, 'goalDifference': 0,
              'points': 0, 'lastUpdated': DateTime.now(),
            }));
      }

      await Future.wait(writeTasks);
      await _firestore.collection('leagues').doc(widget.leagueId).update({'status': 'active'});

      if (!mounted) return;
      await _showDialog(title: 'League Initialized', message: 'The league has been successfully activated.');
      await _loadAll();
    } catch (_) {
      if (mounted) {
        await _showDialog(title: 'Initialization failed', message: 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  // ── MANUAL INITIALIZATION ──
  Future<void> _initializeManual() async {
    final matchesSystem = (_leagueData?['MatchesSystem'] as String?) ?? 'Home_and_away';
    final bool isKnockout = matchesSystem == 'Knockout';

    if (!isKnockout && !_validateAssignments()) {
      await _showDialog(title: 'Invalid', message: 'Teams per group must equal NumberOfTeams/NumberOfGroups');
      return;
    }
    if (_startingDate == null) {
      _showSnack('Pick a starting date', isError: true);
      return;
    }

    final matchDays = List<String>.from(_leagueData?['MatchDays'] ?? []);

    if (isKnockout) {
      final manager = KnockoutLeagueManager(leagueId: widget.leagueId);
      await manager.initializeKnockoutLeague(
        manualPairs: _manualPairs,
        availableTeams: _availableTeamDocs,
        startDate: _startingDate!,
      );
      await FirebaseFirestore.instance
          .collection('leagues').doc(widget.leagueId).update({'status': 'active'});
      if (!mounted) return;
      _showSnack('Knockout league initialized successfully');
      await _loadAll();
      return;
    }

    if (_manualPairs.isEmpty) {
      _showSnack('No pairs added', isError: true);
      return;
    }

    List<Map<String, dynamic>> pairs = generateManualMatches(pairs: _manualPairs);
    final scheduleDates = scheduleMatches(
        startDate: _startingDate!, matchDays: matchDays, totalMatches: pairs.length);

    for (int i = 0; i < pairs.length; i++) {
      final match = pairs[i];
      final id = FirebaseFirestore.instance.collection('x').doc().id;
      await _firestoreService.createMatch(
          leagueId: widget.leagueId,
          matchId: id,
          matchData: {
            'id': id, 'teamAId': match['teamAId'], 'teamBId': match['teamBId'],
            'status': 'scheduled', 'group': match['group'] ?? '',
            'round': match['round'] ?? 1, 'leagueId': widget.leagueId,
            'date': scheduleDates[i],
          });
    }

    final teamDocs = await _firestoreService.fetchLeagueTeams(widget.leagueId);
    for (final d in teamDocs) {
      final data = d.data() as Map<String, dynamic>;
      final teamId = data['teamId'] as String;
      final group = data['group'] as String? ?? '';
      await _firestoreService.createStanding(
          leagueId: widget.leagueId,
          teamId: teamId,
          standingData: {
            'teamId': teamId, 'leagueId': widget.leagueId, 'group': group,
            'played': 0, 'won': 0, 'drawn': 0, 'lost': 0,
            'goalsFor': 0, 'goalsAgainst': 0, 'goalDifference': 0,
            'points': 0, 'lastUpdated': DateTime.now(),
          });
    }

    await FirebaseFirestore.instance
        .collection('leagues').doc(widget.leagueId).update({'status': 'active'});
    if (!mounted) return;
    _showSnack('League initialized (manual)');
    await _loadAll();
  }

  // ── HELPERS ──
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _kRed.withOpacity(0.9) : _kSurface2,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _showDialog({required String title, required String message}) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _kSurface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(message,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.5)),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('OK',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    DateTime? dt;
    if (raw is Timestamp) dt = raw.toDate();
    if (raw is DateTime) dt = raw;
    if (dt == null) return raw.toString();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _shortDate(dynamic raw) {
    if (raw == null) return '—';
    DateTime? dt;
    if (raw is Timestamp) dt = raw.toDate();
    if (raw is DateTime) dt = raw;
    if (dt == null) return raw.toString();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final status = (_leagueData?['status'] as String?) ?? 'inactive';

    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: status == 'inactive'
                  ? _buildInactiveView()
                  : _buildActiveView(),
            ),
          ],
        ),
      ),
    );
  }

  // ── PAGE HEADER ──
  Widget _buildHeader(BuildContext context) {
    final name = _leagueData?['name'] as String? ?? 'League';
    final status = (_leagueData?['status'] as String?) ?? 'inactive';
    final isActive = status == 'active';

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
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
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                const SizedBox(height: 2),
                Text('League Initialization',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          _StatusBadge(isActive: isActive),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  //   INACTIVE VIEW
  // ════════════════════════════════════════
  Widget _buildInactiveView() {
    final matchesSystem = _leagueData?['MatchesSystem'] as String? ?? 'Home_and_away';
    final isKnockout = matchesSystem == 'Knockout';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── League Info Card ──
          _LeagueInfoCard(leagueData: _leagueData),
          const SizedBox(height: 24),

          // ── Starting Date ──
          _sectionLabel('Starting Date'),
          const SizedBox(height: 10),
          _buildDatePickerTile(),
          const SizedBox(height: 24),

          // ── Team Assignment ──
          _sectionLabel(isKnockout ? 'Knockout Setup' : 'Group Assignment'),
          const SizedBox(height: 10),

          isKnockout
              ? _buildKnockoutSetup()
              : _buildGroupAssignmentSection(),

          const SizedBox(height: 32),

          // ── Action Buttons ──
          _buildInitButtons(isKnockout),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDatePickerTile() {
    return GestureDetector(
      onTap: _pickStartingDate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _startingDate != null
              ? AppColors.primaryColor.withOpacity(0.08)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _startingDate != null
                ? AppColors.primaryColor.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                color: _startingDate != null
                    ? AppColors.primaryColor
                    : Colors.grey.shade600,
                size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _startingDate == null
                    ? 'Select starting date'
                    : _shortDate(_startingDate!),
                style: TextStyle(
                  color: _startingDate != null ? Colors.white : Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.grey.shade600, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildKnockoutSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Available teams
        _subLabel('Available Teams — tap to select (then pair)'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableTeamDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final teamId = data['teamId'] as String? ?? doc.id;
            final teamName = data['name'] as String? ?? doc.id;
            final selected = _assignedTeamsSet.contains(teamId);
            final inPair = _manualPairs.any((p) => (p['teams'] as List).contains(teamId));

            return _TeamChip(
              label: teamName,
              selected: selected,
              locked: inPair,
              onTap: () {
                if (!inPair) _toggleTeamForGroup('knockout', teamId);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Create pair button
        if (_assignedTeamsSet.length >= 2) ...[
          _PrimaryBtn(
            icon: Icons.add_link_rounded,
            label: 'Create Pair from Selected (${_assignedTeamsSet.length} selected)',
            onTap: () {
              final selectedList = _assignedTeamsSet.toList();
              final pairTeams = selectedList.take(2).toList();
              setState(() {
                _manualPairs.add({'group': 'knockout', 'teams': pairTeams});
                for (final t in pairTeams) _assignedTeamsSet.remove(t);
              });
            },
          ),
          const SizedBox(height: 16),
        ],

        // Manual pairs
        if (_manualPairs.isNotEmpty) ...[
          _subLabel('Pairs (tap × to remove)'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _manualPairs.map((pair) {
              final names = (pair['teams'] as List)
                  .map((tid) => _teamIdToName[tid] ?? tid)
                  .join(' vs ');
              return _PairChip(
                label: names,
                onDelete: () {
                  setState(() {
                    for (final t in pair['teams']) _assignedTeamsSet.remove(t);
                    _manualPairs.remove(pair);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildGroupAssignmentSection() {
    if (groupNames.isEmpty) {
      return _InfoTile(
        icon: Icons.info_outline_rounded,
        message: 'No groups defined for this league.',
        color: _kAmber,
      );
    }

    return Column(
      children: groupNames.map((group) {
        final sel = _groupSelections[group] ?? <String>{};
        final isFull = sel.length == perGroup;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isFull
                  ? _kGreen.withOpacity(0.3)
                  : Colors.white.withOpacity(0.07),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        color: isFull ? _kGreen.withOpacity(0.15) : AppColors.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(group,
                            style: TextStyle(
                                color: isFull ? _kGreen : AppColors.primaryColor,
                                fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Group $group',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    const Spacer(),
                    _CountBadge(count: sel.length, total: perGroup),
                  ],
                ),
              ),
              // Team chips
              Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTeamDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final teamId = data['teamId'] as String? ?? doc.id;
                    final teamName = data['name'] as String? ?? doc.id;
                    final isSelected = sel.contains(teamId);
                    final assignedElsewhere = _assignedTeamsSet.contains(teamId) && !isSelected;

                    return _TeamChip(
                      label: teamName,
                      selected: isSelected,
                      locked: assignedElsewhere,
                      onTap: () {
                        if (!assignedElsewhere || isSelected) {
                          _toggleTeamForGroup(group, teamId);
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInitButtons(bool isKnockout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isKnockout) ...[
          _PrimaryBtn(
            icon: Icons.auto_awesome_rounded,
            label: 'Auto-Initialize League',
            onTap: _isInitializing ? null : _initializeAutomated,
            loading: _isInitializing,
            color: _kGreen,
          ),
          const SizedBox(height: 12),
        ],
        _PrimaryBtn(
          icon: Icons.edit_calendar_rounded,
          label: isKnockout ? 'Initialize Knockout League' : 'Initialize Manually',
          onTap: _isInitializing ? null : _initializeManual,
          loading: _isInitializing,
          color: AppColors.primaryColor,
        ),
      ],
    );
  }

  // ════════════════════════════════════════
  //   ACTIVE VIEW
  // ════════════════════════════════════════
  Widget _buildActiveView() {
    final matchesSystem = _leagueData?['MatchesSystem'] as String? ?? 'Home_and_away';
    final isKnockout = matchesSystem == 'Knockout';

    return FutureBuilder(
      future: Future.wait([
        _firestoreService.getLeague(widget.leagueId),
        _firestoreService.fetchLeagueTeams(widget.leagueId),
        _firestoreService.fetchMatches(widget.leagueId),
        _firestoreService.fetchAvailableTeams(),
        _firestore.collection('leagues').doc(widget.leagueId)
            .collection('standings').get(),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final leagueDoc = snap.data![0] as DocumentSnapshot;
        final league = (leagueDoc.data() ?? {}) as Map<String, dynamic>;
        final teamDocs = snap.data![1] as List<QueryDocumentSnapshot>;
        final matchDocs = snap.data![2] as List<QueryDocumentSnapshot>;
        final globalTeamDocs = snap.data![3] as List<QueryDocumentSnapshot>;
        final standingsDocs = (snap.data![4] as QuerySnapshot).docs;

        // Build team name map from global teams
final Map<String, String> teamNames = {
  for (final d in globalTeamDocs)
    (() {
      final data = d.data() as Map<String, dynamic>;
      final id = data['teamId'] as String? ?? d.id;
      final name = data['name'] as String? ?? d.id;
      return MapEntry(id, name);
    })().key:
    (() {
      final data = d.data() as Map<String, dynamic>;
      final id = data['teamId'] as String? ?? d.id;
      final name = data['name'] as String? ?? d.id;
      return MapEntry(id, name);
    })().value,
};

        // Supplement with _teamIdToName
        teamNames.addAll(_teamIdToName);

        // Group teams
        final Map<String, List<String>> grouped = {};
        for (final d in teamDocs) {
          final data = d.data() as Map<String, dynamic>;
          final tid = data['teamId'] as String;
          final g = data['group'] as String? ?? 'All';
          grouped.putIfAbsent(g, () => []).add(tid);
        }

        // Categorize matches
        final scheduled = matchDocs.where((m) {
          final s = (m.data() as Map)['status'] as String? ?? '';
          return s == 'scheduled';
        }).toList();
        final completed = matchDocs.where((m) {
          final s = (m.data() as Map)['status'] as String? ?? '';
          return s == 'completed' || s == 'Completed';
        }).toList();
        final postponed = matchDocs.where((m) {
          final s = (m.data() as Map)['status'] as String? ?? '';
          return s == 'postponed' || s == 'Postponed';
        }).toList();

        return DefaultTabController(
          length: isKnockout ? 2 : 3,
          child: Column(
            children: [
              // Tab bar
              Container(
                color: _kSurface,
                child: TabBar(
                  isScrollable: true,
                  indicatorColor: AppColors.primaryColor,
                  indicatorWeight: 2,
                  labelColor: AppColors.primaryColor2,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(text: 'Matches (${matchDocs.length})'),
                    if (!isKnockout) Tab(text: 'Standings'),
                    Tab(text: 'Info'),
                  ],
                ),
              ),

              Expanded(
                child: TabBarView(
                  children: [
                    // ── MATCHES TAB ──
                    _MatchesTab(
                      scheduled: scheduled,
                      completed: completed,
                      postponed: postponed,
                      teamNames: teamNames,
                      leagueId: widget.leagueId,
                      globalTeamDocs: globalTeamDocs,
                      formatDate: _shortDate,
                      onRefresh: _loadAll,
                    ),

                    // ── STANDINGS TAB (non-knockout) ──
                    if (!isKnockout)
                      _StandingsTab(
                        standingsDocs: standingsDocs,
                        grouped: grouped,
                        teamNames: teamNames,
                        leagueId: widget.leagueId,
                        onRefresh: _loadAll,
                      ),

                    // ── INFO TAB ──
                    _InfoTab(league: league, grouped: grouped, teamNames: teamNames),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Shared section/sub labels ──
  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(
            color: AppColors.primaryColor, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade400, fontSize: 12,
                fontWeight: FontWeight.w600, letterSpacing: 0.6)),
      ],
    );
  }

  Widget _subLabel(String label) {
    return Text(label,
        style: TextStyle(
            color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500));
  }
}

// ════════════════════════════════════════════════════════════════════
//   MATCHES TAB
// ════════════════════════════════════════════════════════════════════
// STEP 1: Add this at the top of your _MatchesTab class
class _MatchesTab extends StatefulWidget {
  final List<QueryDocumentSnapshot> scheduled;
  final List<QueryDocumentSnapshot> completed;
  final List<QueryDocumentSnapshot> postponed;
  final Map<String, String> teamNames;
  final String leagueId;
  final List<QueryDocumentSnapshot> globalTeamDocs;
  final String Function(dynamic) formatDate;
  final VoidCallback onRefresh;

  const _MatchesTab({
    required this.scheduled,
    required this.completed,
    required this.postponed,
    required this.teamNames,
    required this.leagueId,
    required this.globalTeamDocs,
    required this.formatDate,
    required this.onRefresh,
  });

  @override
  State<_MatchesTab> createState() => _MatchesTabState();
}

// STEP 2: Add this new State class right after _MatchesTab
class _MatchesTabState extends State<_MatchesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // STEP 3: Add this filter method
  List<QueryDocumentSnapshot> _filterMatches(
    List<QueryDocumentSnapshot> matches,
  ) {
    if (_searchQuery.isEmpty) return matches;

    return matches.where((match) {
      final data = match.data() as Map<String, dynamic>;
      final homeTeam = data['teamAId'] ?? '';
      final awayTeam = data['teamBId'] ?? '';

      final homeTeamName = widget.teamNames[homeTeam] ?? homeTeam ?? '';
      final awayTeamName = widget.teamNames[awayTeam] ?? awayTeam ?? '';

      return homeTeamName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          awayTeamName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Filter all lists
    final filteredScheduled = _filterMatches(widget.scheduled);
    final filteredCompleted = _filterMatches(widget.completed);
    final filteredPostponed = _filterMatches(widget.postponed);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // STEP 4: Add search box here
          _buildSearchBox(),
          const SizedBox(height: 20),

          if (filteredScheduled.isNotEmpty) ...[
            _matchCategory(
              'Scheduled',
              filteredScheduled,
              _kBlue,
              Icons.schedule_rounded,
              context,
            ),
            const SizedBox(height: 20),
          ],
          if (filteredCompleted.isNotEmpty) ...[
            _matchCategory(
              'Completed',
              filteredCompleted,
              _kGreen,
              Icons.check_circle_rounded,
              context,
            ),
            const SizedBox(height: 20),
          ],
          if (filteredPostponed.isNotEmpty)
            _matchCategory(
              'Postponed',
              filteredPostponed,
              _kAmber,
              Icons.pause_circle_rounded,
              context,
            ),
          if (filteredScheduled.isEmpty &&
              filteredCompleted.isEmpty &&
              filteredPostponed.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  _searchQuery.isEmpty ? 'No matches yet' : 'No matches found',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // STEP 5: Add this search box widget
  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by team name...',
          hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade600,
            size: 18,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.grey.shade600,
                    size: 18,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _matchCategory(
    String title,
    List<QueryDocumentSnapshot> matches,
    Color color,
    IconData icon,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${matches.length}',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...matches.map(
          (m) => _MatchCard(
            matchDoc: m,
            teamNames: widget.teamNames,
            globalTeamDocs: widget.globalTeamDocs,
            leagueId: widget.leagueId,
            formatDate: widget.formatDate,
            statusColor: color,
            onUpdated: widget.onRefresh,
          ),
        ),
      ],
    );
  }
}
// ════════════════════════════════════════════════════════════════════
//   MATCH CARD
// ════════════════════════════════════════════════════════════════════
class _MatchCard extends StatefulWidget {
  final QueryDocumentSnapshot matchDoc;
  final Map<String, String> teamNames;
  final List<QueryDocumentSnapshot> globalTeamDocs;
  final String leagueId;
  final String Function(dynamic) formatDate;
  final Color statusColor;
  final VoidCallback onUpdated;

  const _MatchCard({
    required this.matchDoc,
    required this.teamNames,
    required this.globalTeamDocs,
    required this.leagueId,
    required this.formatDate,
    required this.statusColor,
    required this.onUpdated,
  });

  @override
  State<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<_MatchCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.matchDoc.data() as Map<String, dynamic>;
    final teamAId = data['teamAId'] as String? ?? '';
    final teamBId = data['teamBId'] as String? ?? '';
    final teamAName = widget.teamNames[teamAId] ?? teamAId;
    final teamBName = widget.teamNames[teamBId] ?? teamBId;
    final status = data['status'] as String? ?? 'scheduled';
    final group = data['group'] as String?;
    final date = data['date'];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _hovered ? Colors.white.withOpacity(0.06) : _kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered
                ? widget.statusColor.withOpacity(0.25)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                // Team A
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(teamAName,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
                // VS
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('VS',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                // Team B
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(teamBName,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 5),
                Text(widget.formatDate(date),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                const Spacer(),
                if (group != null && group.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Grp $group',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                  ),
                  const SizedBox(width: 8),
                ],
                _StatusPill(status: status),
                const SizedBox(width: 10),
                // Modify button
                GestureDetector(
                  onTap: () => _openModifyDialog(context, data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primaryColor2.withOpacity(0.3)),
                    ),
                    child: Text('Modify',
                        style: TextStyle(
                            color: AppColors.primaryColor2,
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openModifyDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => _ModifyMatchDialog(
        matchId: widget.matchDoc.id,
        matchData: data,
        leagueId: widget.leagueId,
        globalTeamDocs: widget.globalTeamDocs,
        teamNames: widget.teamNames,
        onSaved: () {
          Navigator.pop(context);
          widget.onUpdated();
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   MODIFY MATCH DIALOG
// ════════════════════════════════════════════════════════════════════
class _ModifyMatchDialog extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic> matchData;
  final String leagueId;
  final List<QueryDocumentSnapshot> globalTeamDocs;
  final Map<String, String> teamNames;
  final VoidCallback onSaved;

  const _ModifyMatchDialog({
    required this.matchId,
    required this.matchData,
    required this.leagueId,
    required this.globalTeamDocs,
    required this.teamNames,
    required this.onSaved,
  });

  @override
  State<_ModifyMatchDialog> createState() => _ModifyMatchDialogState();
}

class _ModifyMatchDialogState extends State<_ModifyMatchDialog> {
  late String _teamAId;
  late String _teamBId;
  late String _status;
  late DateTime? _selectedDate;
  bool _saving = false;

  final List<String> _statuses = ['scheduled', 'completed', 'postponed'];

  @override
  void initState() {
    super.initState();
    _teamAId = widget.matchData['teamAId'] as String? ?? '';
    _teamBId = widget.matchData['teamBId'] as String? ?? '';
    _status = (widget.matchData['status'] as String? ?? 'scheduled').toLowerCase();
    if (!_statuses.contains(_status)) _status = 'scheduled';

    final raw = widget.matchData['date'];
    if (raw is Timestamp) _selectedDate = raw.toDate();
    else if (raw is DateTime) _selectedDate = raw;
    else _selectedDate = null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.primaryColor2, surface: _kSurface2),
          dialogBackgroundColor: _kSurface,
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate ?? now),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.primaryColor2, surface: _kSurface2),
          dialogBackgroundColor: _kSurface,
        ),
        child: child!,
      ),
    );

    setState(() {
      _selectedDate = DateTime(
        picked.year, picked.month, picked.day,
        pickedTime?.hour ?? 0,
        pickedTime?.minute ?? 0,
      );
    });
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return 'Select date & time';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${m[dt.month-1]} ${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'teamAId': _teamAId,
        'teamBId': _teamBId,
        'status': _status,
      };
      if (_selectedDate != null) updates['date'] = Timestamp.fromDate(_selectedDate!);

      await FirebaseFirestore.instance
          .collection('leagues').doc(widget.leagueId)
          .collection('matches').doc(widget.matchId)
          .update(updates);

      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: _kRed.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTeams = widget.globalTeamDocs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return MapEntry(data['teamId'] as String? ?? d.id, data['name'] as String? ?? d.id);
    }).toList();

    return Dialog(
      backgroundColor: _kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_rounded, color: AppColors.primaryColor2, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Modify Match',
                        style: TextStyle(
                            color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white60, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team A
                  _dialogLabel('Team A'),
                  const SizedBox(height: 8),
                  _teamDropdown(
                    value: _teamAId,
                    teams: allTeams,
                    onChanged: (v) { if (v != null) setState(() => _teamAId = v); },
                  ),
                  const SizedBox(height: 16),

                  // Team B
                  _dialogLabel('Team B'),
                  const SizedBox(height: 8),
                  _teamDropdown(
                    value: _teamBId,
                    teams: allTeams,
                    onChanged: (v) { if (v != null) setState(() => _teamBId = v); },
                  ),
                  const SizedBox(height: 16),

                  // Date & Time
                  _dialogLabel('Date & Time'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_fmtDate(_selectedDate),
                                style: TextStyle(
                                    color: _selectedDate != null
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontSize: 13)),
                          ),
                          Icon(Icons.edit_calendar_rounded,
                              size: 14, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status
                  _dialogLabel('Match Status'),
                  const SizedBox(height: 8),
                  Row(
                    children: _statuses.map((s) {
                      final isSelected = _status == s;
                      Color c;
                      switch (s) {
                        case 'completed': c = _kGreen; break;
                        case 'postponed': c = _kAmber; break;
                        default: c = _kBlue;
                      }
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _status = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: EdgeInsets.only(right: s != 'postponed' ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? c.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? c.withOpacity(0.4) : Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Center(
                              child: Text(s[0].toUpperCase() + s.substring(1),
                                  style: TextStyle(
                                      color: isSelected ? c : Colors.grey.shade600,
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        disabledBackgroundColor: AppColors.primaryColor.withOpacity(0.35),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Changes',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamDropdown(
      {required String value,
      required List<MapEntry<String, String>> teams,
      required void Function(String?) onChanged}) {
    // Ensure value is valid
    final validValue = teams.any((e) => e.key == value) ? value : (teams.isNotEmpty ? teams.first.key : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          isExpanded: true,
          dropdownColor: _kSurface2,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade500, size: 18),
          items: teams
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dialogLabel(String label) {
    return Text(label,
        style: TextStyle(
            color: Colors.grey.shade400, fontSize: 11,
            fontWeight: FontWeight.w600, letterSpacing: 0.4));
  }
}

// ════════════════════════════════════════════════════════════════════
//   STANDINGS TAB
// ════════════════════════════════════════════════════════════════════
class _StandingsTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> standingsDocs;
  final Map<String, List<String>> grouped;
  final Map<String, String> teamNames;
  final String leagueId;
  final VoidCallback onRefresh;

  const _StandingsTab({
    required this.standingsDocs,
    required this.grouped,
    required this.teamNames,
    required this.leagueId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (standingsDocs.isEmpty) {
      return const Center(
        child: Text('No standings data yet.', style: TextStyle(color: Colors.grey)),
      );
    }

    // Group standings
    final Map<String, List<Map<String, dynamic>>> byGroup = {};
    for (final d in standingsDocs) {
      final data = d.data() as Map<String, dynamic>;
      final g = data['group'] as String? ?? 'All';
      byGroup.putIfAbsent(g, () => []).add({...data, 'docId': d.id});
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: byGroup.entries.map((entry) {
          final group = entry.key;
          final standings = entry.value
            ..sort((a, b) => (b['points'] as int? ?? 0).compareTo(a['points'] as int? ?? 0));

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Group header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
                  ),
                  child: Row(
                    children: [
                      Text('Group $group',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                ),
                // Column headers
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white.withOpacity(0.02),
                  child: Row(
                    children: [
                      const SizedBox(width: 24),
                      const Expanded(flex: 4, child: Text('Team', style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w600))),
                      ..._standingColHeader(['P','W','D','L','GF','GA','GD','Pts']),
                      const SizedBox(width: 64), // widened to accommodate both icons
                    ],
                  ),
                ),
                // Rows
                ...standings.asMap().entries.map((e) {
                  final i = e.key;
                  final s = e.value;
                  final teamName = teamNames[s['teamId']] ?? s['teamId'] ?? '—';
                  return _StandingRow(
                    rank: i + 1,
                    teamName: teamName,
                    standing: s,
                    docId: s['docId'] as String,
                    leagueId: leagueId,
                    onUpdated: onRefresh,
                  );
                }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _standingColHeader(List<String> cols) {
    return cols.map((c) => Expanded(
      child: Text(c,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF6B7280), fontSize: 11, fontWeight: FontWeight.w600)),
    )).toList();
  }
}

// ── Standing row with modify + delete buttons ──
class _StandingRow extends StatefulWidget {
  final int rank;
  final String teamName;
  final Map<String, dynamic> standing;
  final String docId;
  final String leagueId;
  final VoidCallback onUpdated;

  const _StandingRow({
    required this.rank,
    required this.teamName,
    required this.standing,
    required this.docId,
    required this.leagueId,
    required this.onUpdated,
  });

  @override
  State<_StandingRow> createState() => _StandingRowState();
}

class _StandingRowState extends State<_StandingRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.standing;
    final isTop3 = widget.rank <= 3;
    final rankColor = widget.rank == 1
        ? _kAmber
        : widget.rank == 2
            ? const Color(0xFFB0BEC5)
            : widget.rank == 3
                ? const Color(0xFFBCAAA4)
                : Colors.grey.shade700;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? Colors.white.withOpacity(0.04) : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text('${widget.rank}',
                  style: TextStyle(
                      color: rankColor, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              flex: 4,
              child: Text(widget.teamName,
                  style: TextStyle(
                      color: isTop3 ? Colors.white : Colors.white70,
                      fontSize: 13, fontWeight: isTop3 ? FontWeight.w600 : FontWeight.w400)),
            ),
            ..._statCell(s['played']),
            ..._statCell(s['won']),
            ..._statCell(s['drawn'] ?? s['draw']),
            ..._statCell(s['lost']),
            ..._statCell(s['goalsFor']),
            ..._statCell(s['goalsAgainst']),
            ..._statCell(s['goalDifference']),
            ..._statCell(s['points'], bold: true, color: AppColors.primaryColor2),
            // ── Edit button ──
            SizedBox(
              width: 32,
              child: GestureDetector(
                onTap: () => _openEditDialog(context),
                child: Icon(Icons.edit_rounded,
                    size: 14,
                    color: _hovered ? AppColors.whiteColor : Colors.grey.shade700),
              ),
            ),
            // ── Delete button ──
            SizedBox(
              width: 32,
              child: GestureDetector(
                onTap: () => _confirmDelete(context),
                child: Icon(Icons.delete_outline_rounded,
                    size: 14,
                    color: _hovered ? _kRed : Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _statCell(dynamic val, {bool bold = false, Color? color}) {
    return [
      Expanded(
        child: Text(
          val?.toString() ?? '0',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color ?? Colors.grey.shade400,
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    ];
  }

  void _openEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _EditStandingDialog(
        docId: widget.docId,
        leagueId: widget.leagueId,
        standing: widget.standing,
        teamName: widget.teamName,
        onSaved: () {
          Navigator.pop(context);
          widget.onUpdated();
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: _kRed.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.delete_outline_rounded, color: _kRed, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Delete Standing',
                          style: TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.close_rounded, color: Colors.white60, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.5),
                        children: [
                          const TextSpan(text: 'Are you sure you want to delete the standing for '),
                          TextSpan(
                            text: widget.teamName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: '? This action cannot be undone.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        // Cancel
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.white.withOpacity(0.12)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Cancel',
                                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Delete
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: _DeleteConfirmButton(
                              docId: widget.docId,
                              leagueId: widget.leagueId,
                              onDeleted: () {
                                Navigator.pop(context);
                                widget.onUpdated();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stateful delete button to handle loading state ──
class _DeleteConfirmButton extends StatefulWidget {
  final String docId;
  final String leagueId;
  final VoidCallback onDeleted;

  const _DeleteConfirmButton({
    required this.docId,
    required this.leagueId,
    required this.onDeleted,
  });

  @override
  State<_DeleteConfirmButton> createState() => _DeleteConfirmButtonState();
}

class _DeleteConfirmButtonState extends State<_DeleteConfirmButton> {
  bool _deleting = false;

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await FirebaseFirestore.instance
          .collection('leagues').doc(widget.leagueId)
          .collection('standings').doc(widget.docId)
          .delete();
      widget.onDeleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: _kRed.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
        ));
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _deleting ? null : _delete,
      style: ElevatedButton.styleFrom(
        backgroundColor: _kRed,
        disabledBackgroundColor: _kRed.withOpacity(0.35),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _deleting
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text('Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   EDIT STANDING DIALOG
// ════════════════════════════════════════════════════════════════════
class _EditStandingDialog extends StatefulWidget {
  final String docId;
  final String leagueId;
  final Map<String, dynamic> standing;
  final String teamName;
  final VoidCallback onSaved;

  const _EditStandingDialog({
    required this.docId,
    required this.leagueId,
    required this.standing,
    required this.teamName,
    required this.onSaved,
  });

  @override
  State<_EditStandingDialog> createState() => _EditStandingDialogState();
}

class _EditStandingDialogState extends State<_EditStandingDialog> {
  late Map<String, TextEditingController> _controllers;
  bool _saving = false;

  final _fields = ['played', 'won', 'drawn', 'lost', 'goalsFor', 'goalsAgainst', 'goalDifference', 'points'];
  final _labels = ['Played', 'Won', 'Drawn', 'Lost', 'Goals For', 'Goals Against', 'Goal Diff', 'Points'];

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final f in _fields)
        f: TextEditingController(
            text: (widget.standing[f] ?? widget.standing['draw'] ?? 0).toString())
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{};
      for (final f in _fields) {
        updates[f == 'drawn' ? 'draw' : f] = int.tryParse(_controllers[f]!.text) ?? 0;
      }
      updates['drawn'] = int.tryParse(_controllers['drawn']!.text) ?? 0;
      updates['lastUpdated'] = DateTime.now();

      await FirebaseFirestore.instance
          .collection('leagues').doc(widget.leagueId)
          .collection('standings').doc(widget.docId)
          .update(updates);

      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: _kRed.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: _kGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.leaderboard_rounded, color: _kGreen, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Edit Standing',
                            style: TextStyle(
                                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(widget.teamName,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close_rounded, color: Colors.white60, size: 16),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3.2,
                    children: List.generate(_fields.length, (i) {
                      return _standingField(_labels[i], _controllers[_fields[i]]!);
                    }),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        disabledBackgroundColor: AppColors.primaryColor.withOpacity(0.35),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Standings',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _standingField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primaryColor.withOpacity(0.5)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
// ════════════════════════════════════════════════════════════════════
//   INFO TAB
// ════════════════════════════════════════════════════════════════════
class _InfoTab extends StatelessWidget {
  final Map<String, dynamic> league;
  final Map<String, List<String>> grouped;
  final Map<String, String> teamNames;

  const _InfoTab({
    required this.league,
    required this.grouped,
    required this.teamNames,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _LeagueInfoCard(leagueData: league),
          const SizedBox(height: 20),
          // Teams by group
          ...grouped.entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: ThemeData.dark(),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Center(
                        child: Text(e.key,
                            style: TextStyle(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Group ${e.key}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 8),
                    Text('(${e.value.length} teams)',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
                children: e.value.map((tid) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 10),
                      Text(teamNames[tid] ?? tid,
                          style: TextStyle(color: Colors.grey.shade300, fontSize: 13)),
                    ],
                  ),
                )).toList(),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   REUSABLE WIDGETS
// ════════════════════════════════════════════════════════════════════

class _LeagueInfoCard extends StatelessWidget {
  final Map<String, dynamic>? leagueData;
  const _LeagueInfoCard({required this.leagueData});

  @override
  Widget build(BuildContext context) {
    final d = leagueData ?? {};
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _row('Season', d['season']),
          _row('Teams', d['NumberOfTeams']),
          _row('Groups', d['NumberOfGroups']),
          _row('Match System', d['MatchesSystem']),
          _row('Team Pairing', d['TeamsPairing'] ?? d['Teamspairing']),
          _row('Match Days', (d['MatchDays'] as List<dynamic>?)?.join('  •  ')),
        ],
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const Spacer(),
          Text(value?.toString() ?? '—',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: (isActive ? _kGreen : _kAmber).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isActive ? _kGreen : _kAmber).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: isActive ? _kGreen : _kAmber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                  color: isActive ? _kGreen : _kAmber,
                  fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color c;
    IconData ic;
    switch (s) {
      case 'completed': c = _kGreen; ic = Icons.check_circle_rounded; break;
      case 'postponed': c = _kAmber; ic = Icons.pause_circle_rounded; break;
      default: c = _kBlue; ic = Icons.schedule_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 10, color: c),
          const SizedBox(width: 4),
          Text(s[0].toUpperCase() + s.substring(1),
              style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  const _TeamChip({
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryColor : locked ? Colors.grey.shade700 : Colors.grey.shade600;

    return GestureDetector(
      onTap: locked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryColor.withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primaryColor.withOpacity(0.4)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locked) Icon(Icons.lock_rounded, size: 11, color: color),
            if (selected && !locked) Icon(Icons.check_rounded, size: 11, color: color),
            if ((selected || locked)) const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: locked ? Colors.grey.shade700 : selected ? color : Colors.grey.shade400,
                    fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

class _PairChip extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;

  const _PairChip({required this.label, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _kPurple.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kPurple.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_soccer_rounded, size: 12, color: _kPurple),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: _kPurple, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded, size: 13, color: _kPurple.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final int total;
  const _CountBadge({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final full = count >= total;
    final c = full ? _kGreen : AppColors.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text('$count / $total',
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _PrimaryBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final Color color;

  const _PrimaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.color = const Color(0xFF4FC3F7),
  });

  @override
  State<_PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<_PrimaryBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.loading;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 50,
          decoration: BoxDecoration(
            color: disabled
                ? widget.color.withOpacity(0.1)
                : _hovered
                    ? widget.color.withOpacity(0.22)
                    : widget.color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: disabled
                  ? widget.color.withOpacity(0.15)
                  : widget.color.withOpacity(0.4),
            ),
          ),
          child: Center(
            child: widget.loading
                ? SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: widget.color))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon,
                          color: disabled ? widget.color.withOpacity(0.4) : widget.color,
                          size: 18),
                      const SizedBox(width: 10),
                      Text(widget.label,
                          style: TextStyle(
                              color: disabled ? widget.color.withOpacity(0.4) : widget.color,
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _InfoTile({required this.icon, required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}

// ── PlannedMatch ──
class PlannedMatch {
  final String group;
  final String teamAId;
  final String teamBId;

  const PlannedMatch({
    required this.group,
    required this.teamAId,
    required this.teamBId,
  });
}