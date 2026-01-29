// ignore_for_file: unnecessary_to_list_in_spreads, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/league_manager/firestore_service.dart';
import 'package:kklivescoreadmin/league_manager/manual_pairing.dart';
import 'package:kklivescoreadmin/league_manager/match_scheduler.dart';
import 'package:kklivescoreadmin/league_manager/match_system.dart';

class LeagueInitializationScreen extends StatefulWidget {
  final String leagueId;
  const LeagueInitializationScreen({super.key, required this.leagueId});

  @override
  State<LeagueInitializationScreen> createState() => _LeagueInitializationScreenState();
}

class _LeagueInitializationScreenState extends State<LeagueInitializationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _firestoreService = FirestoreService();
  late final Map<String, String> _teamIdToName;
  void _buildTeamLookup() {
  _teamIdToName = {
    for (final d in _availableTeamDocs)
      ((d.data() as Map<String, dynamic>)['teamId'] as String?) ?? d.id:
      ((d.data() as Map<String, dynamic>)['name'] as String?) ?? d.id,
  };
}


  Map<String, dynamic>? _leagueData;
  List<Map<String, dynamic>> _leagueTeams = []; // teams saved under leagues/{leagueId}/teams
  List<QueryDocumentSnapshot> _availableTeamDocs = []; // top-level teams/
  DateTime? _startingDate;
  bool _loading = true;

  // Assignment UI state
  final Map<String, Set<String>> _groupSelections = {}; // group -> set of teamIds
  final Set<String> _assignedTeamsSet = {};

  // Manual pairing rows (for ManualPairing)
  final List<Map<String, dynamic>> _manualPairs = []; // {group: 'A', teams: [t1,t2]}

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final leagueSnap = await _firestoreService.getLeague(widget.leagueId);
    final leagueData = (leagueSnap.data() ?? {}) as Map<String, dynamic>;
    // fetch teams already under leagues/{leagueId}/teams
    final teamDocs = await _firestoreService.fetchLeagueTeams(widget.leagueId);
    // fetch available teams from top-level teams/
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
  }

  Future<void> _pickStartingDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d == null) return;
    setState(() {
      _startingDate = d;
    });
  }

  int get numberOfTeams => (_leagueData?['NumberOfTeams'] as int?) ?? 0;
  int get numberOfGroups => (_leagueData?['NumberOfGroups'] as int?) ?? 0;
  List<String> get groupNames {
    final ng = numberOfGroups;
    return List.generate(ng, (i) => String.fromCharCode(65 + i));
  }

  int get perGroup {
    final ng = numberOfGroups == 0 ? 1 : numberOfGroups;
    final nt = numberOfTeams;
    return nt ~/ ng;
  }

  // UI: toggle team selection for a group
  void _toggleTeamForGroup(String group, String teamId) {
    final set = _groupSelections[group] ?? <String>{};
    if (set.contains(teamId)) {
      set.remove(teamId);
      _assignedTeamsSet.remove(teamId);
    } else {
      // prevent same team in multiple groups
      if (_assignedTeamsSet.contains(teamId)) {
        // show alert
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team already assigned to another group')));
        return;
      }
      set.add(teamId);
      _assignedTeamsSet.add(teamId);
    }
    _groupSelections[group] = set;
    setState(() {});
  }

  bool _validateAssignments() {
    // Each group must have exactly perGroup teams and overall assigned count must equal numberOfTeams
    if (groupNames.isEmpty) return false;
    for (final g in groupNames) {
      final sel = _groupSelections[g] ?? <String>{};
      if (sel.length != perGroup) return false;
    }
    // total assigned
    final totalAssigned = _groupSelections.values.fold<int>(0, (p, s) => p + s.length);
    if (totalAssigned != numberOfTeams) return false;
    return true;
  }

  Future<void> _saveAssignmentsToFirestore() async {
    // Save each assigned team under leagues/{leagueId}/teams/{teamId} with fields teamId, group, leagueId
    for (final g in groupNames) {
      final sel = _groupSelections[g] ?? <String>{};
      for (final tid in sel) {
        await _firestoreService.createLeagueTeam(leagueId: widget.leagueId, teamId: tid, group: g);
      }
    }
    // refresh local league teams
    final teamDocs = await _firestoreService.fetchLeagueTeams(widget.leagueId);
    setState(() {
      _leagueTeams = teamDocs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {'teamId': data['teamId'], 'group': data['group']};
      }).toList();
    });
  }
bool _isInitializing = false;

Future<void> _initializeAutomated() async {
  if (_isInitializing) return;

  if (!_validateAssignments()) {
    await _showDialog(
      title: 'Invalid configuration',
      message: 'Teams per group must equal NumberOfTeams / NumberOfGroups.',
    );
    return;
  }

  if (_startingDate == null) {
    await _showDialog(
      title: 'Missing date',
      message: 'Please select a starting date.',
    );
    return;
  }

  setState(() => _isInitializing = true);

  try {
    final matchDays = List<String>.from(_leagueData?['MatchDays'] ?? []);
    final matchesSystem =
        _leagueData?['MatchesSystem'] as String? ?? 'Home_and_away';

    /// --------------------------------------------------
    /// 1️⃣ BUILD GROUP → TEAMS MAP
    /// --------------------------------------------------
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

    /// --------------------------------------------------
    /// 2️⃣ BUILD MATCHES PER GROUP
    /// --------------------------------------------------
    final Map<String, List<_PlannedMatch>> matchesByGroup = {};

    for (final g in groupNames) {
      final teams = groupsMap[g] ?? [];

      final pairs = matchesSystem == 'Home_and_away'
          ? doubleRoundRobin(teams)
          : singleRoundRobin(teams);

      matchesByGroup[g] = pairs
          .map(
            (p) => _PlannedMatch(
              group: g,
              teamAId: p[0],
              teamBId: p[1],
            ),
          )
          .toList();
    }

    /// --------------------------------------------------
    /// 3️⃣ INTERLEAVE MATCHES (A, B, A, B…)
    /// --------------------------------------------------
    final List<_PlannedMatch> plannedMatches = [];

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

    if (plannedMatches.isEmpty) {
      throw Exception('No matches generated');
    }

    /// --------------------------------------------------
    /// 4️⃣ GLOBAL MATCH CALENDAR
    /// --------------------------------------------------
    final globalDates = scheduleMatches(
      startDate: _startingDate!,
      matchDays: matchDays,
      totalMatches: plannedMatches.length,
    );

    if (globalDates.length < plannedMatches.length) {
      throw Exception('Not enough dates generated');
    }

    /// --------------------------------------------------
    /// 5️⃣ WRITE MATCHES (ORDERED & SAFE)
    /// --------------------------------------------------
    final List<Future<void>> writeTasks = [];

    for (int i = 0; i < plannedMatches.length; i++) {
      final m = plannedMatches[i];
      final id = _firestore.collection('x').doc().id;

      writeTasks.add(
        _firestoreService.createMatch(
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
          },
        ),
      );
    }

    /// --------------------------------------------------
    /// 6️⃣ INITIALIZE STANDINGS
    /// --------------------------------------------------
    final teamDocs =
        await _firestoreService.fetchLeagueTeams(widget.leagueId);

    for (final d in teamDocs) {
      final data = d.data() as Map<String, dynamic>;

      writeTasks.add(
        _firestoreService.createStanding(
          leagueId: widget.leagueId,
          teamId: data['teamId'],
          standingData: {
            'teamId': data['teamId'],
            'leagueId': widget.leagueId,
            'group': data['group'],
            'played': 0,
            'won': 0,
            'drawn': 0,
            'lost': 0,
            'goalsFor': 0,
            'goalsAgainst': 0,
            'goalDifference': 0,
            'points': 0,
            'lastUpdated': DateTime.now(),
          },
        ),
      );
    }

    /// --------------------------------------------------
    /// 7️⃣ COMMIT
    /// --------------------------------------------------
    await Future.wait(writeTasks);

    await _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .update({'status': 'active'});

    if (!mounted) return;

    await _showDialog(
      title: 'League Initialized',
      message: 'The league has been successfully activated.',
    );

    await _loadAll();
  } catch (_) {
    if (mounted) {
      await _showDialog(
        title: 'Initialization failed',
        message:
            'Something went wrong while initializing the league. Please try again.',
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }
}


  Future<void> _addManualPairRow() async {
    // Choose group and exactly 2 teams from assigned teams
    final groups = groupNames;
    if (groups.isEmpty) return;
    String selectedGroup = groups.first;
    final availableAssignedTeams = (await _firestoreService.fetchLeagueTeams(widget.leagueId))
        .map((d) => (d.data() as Map<String, dynamic>)['teamId'] as String)
        .toList();
    final selectedTeams = <String>{};
    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Add Pair'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedGroup,
                    items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setStateDialog(() => selectedGroup = v ?? selectedGroup),
                  ),
                  const SizedBox(height: 8),
                  const Text('Select exactly 2 teams'),
                  SizedBox(
                    height: 200,
                    child: ListView(
                      children: availableAssignedTeams.map((tid) {
                        final checked = selectedTeams.contains(tid);
                        return CheckboxListTile(
                          value: checked,
                          title: Text(tid),
                          onChanged: (val) {
                            setStateDialog(() {
                              if (val == true) {
                                selectedTeams.add(tid);
                              } else {
                                selectedTeams.remove(tid);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
              TextButton(
                onPressed: () {
                  if (selectedTeams.length != 2) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select exactly 2 teams')));
                    return;
                  }
                  _manualPairs.add({'group': selectedGroup, 'teams': selectedTeams.toList()});
                  Navigator.pop(context);
                },
                child: const Text('+ Pair Next Match'),
              ),
            ],
          );
        });
      },
    );
    setState(() {});
  }

  Future<void> _initializeManual() async {
    if (!_validateAssignments()) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Invalid'),
          content: const Text('Teams per group must equal NumberOfTeams/NumberOfGroups'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }
    if (_startingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a starting date')));
      return;
    }
    if (_manualPairs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pairs added')));
      return;
    }
    final matchDays = List<String>.from(_leagueData?['MatchDays'] ?? []);
    final pairs = generateManualMatches(pairs: _manualPairs);
    final scheduleDates = scheduleMatches(startDate: _startingDate!, matchDays: matchDays, totalMatches: pairs.length);

    for (int i = 0; i < pairs.length; i++) {
      final match = pairs[i];
      final id = FirebaseFirestore.instance.collection('x').doc().id;
      final matchDoc = {
        'id': id,
        'teamAId': match['teamAId'],
        'teamBId': match['teamBId'],
        'status': 'scheduled',
        'group': match['group'],
        'leagueId': widget.leagueId,
        'date': scheduleDates[i],
      };
      await _firestoreService.createMatch(leagueId: widget.leagueId, matchId: id, matchData: matchDoc);
    }

    // Create standings
    final teamDocs = await _firestoreService.fetchLeagueTeams(widget.leagueId);
    for (final d in teamDocs) {
      final data = d.data() as Map<String, dynamic>;
      final teamId = data['teamId'] as String;
      final group = data['group'] as String;
      final standing = {
        'teamId': teamId,
        'leagueId': widget.leagueId,
        'group': group,
        'played': 0,
        'won': 0,
        'drawn': 0,
        'lost': 0,
        'goalsFor': 0,
        'goalsAgainst': 0,
        'goalDifference': 0,
        'points': 0,
        'lastUpdated': DateTime.now(),
      };
      await _firestoreService.createStanding(leagueId: widget.leagueId, teamId: teamId, standingData: standing);
    }

    // Update league status to active
    await FirebaseFirestore.instance.collection('leagues').doc(widget.leagueId).update({'status': 'active'});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('League initialized (manual)')));
    await _loadAll();
  }

  Widget _buildInitializationView() {
    // Build assignment UI then pairing controls


    return Column(
      
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(_leagueData?['name'] ?? ''),
          subtitle: Text(_leagueData?['season'] ?? ''),
        ),
        const SizedBox(height: 12),
        ListTile(
          title: const Text('Starting Date'),
          subtitle: Text(_startingDate?.toIso8601String() ?? 'Not selected'),
          trailing: ElevatedButton(onPressed: _pickStartingDate, child: const Text('Pick')),
        ),
        const SizedBox(height: 12),
        const Text('Assign Teams to Groups', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Group sections dynamically
        ...groupNames.map((g) {
          final selected = _groupSelections[g] ?? <String>{};
          final selectedNames = selected.map((id) => _teamIdToName[id] ?? id).join(', ');
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Group $g', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Select $perGroup teams'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView(
                    children: _availableTeamDocs.map((d) {
                      final data = d.data() as Map<String, dynamic>;
                     final tid = (data['teamId'] as String?) ?? d.id;
                      final name = (data['name'] as String?) ?? tid;
                      final checked = selected.contains(tid);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(name),
                       // subtitle: Text(tid),
                        onChanged: (val) {
                          // Toggle selection if allowed
                          setState(() {
                            if (val == true) {
                              // only allow if this group's size < perGroup and team not assigned elsewhere
                              if ((selected.length < perGroup) && !_assignedTeamsSet.contains(tid)) {
                                _toggleTeamForGroup(g, tid);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot select team (limit or already assigned)')));
                              }
                            } else {
                              _toggleTeamForGroup(g, tid);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),



Text('Selected: $selectedNames'),

                
              ]),
            ),
          );
        }).toList(),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            if (!_validateAssignments()) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Invalid'),
                  content: const Text('Teams per group must equal NumberOfTeams/NumberOfGroups'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                ),
              );
              return;
            }
            await _saveAssignmentsToFirestore();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignments saved')));
            setState(() {}); // to reflect saved assignments
          },
          child: const Text('Save Assignments'),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text('Pairing & Scheduling', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        if ((_leagueData?['TeamsPairing'] as String?) == 'AutomatedPairing') ...[
          const Text('Automated Pairing will generate matches automatically'),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _initializeAutomated, child: const Text('INITIALIZE LEAGUE NOW')),
        ] else ...[
          const Text('Manual Pairing: add pairs then initialize'),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _addManualPairRow, child: const Text('+ Pair Next Match')),
          const SizedBox(height: 8),
          Column(
            children: _manualPairs
                .asMap()
                .entries
                .map((e) => ListTile(
                      title: Text('Pair ${e.key + 1}'),
                      subtitle: Text('${e.value['group']} : ${e.value['teams'].join(' vs ')}'),
                    ))
                .toList(),
          ),
          
          ElevatedButton(onPressed: _initializeManual, child: const Text('INITIALIZE LEAGUE NOW')),
      
        ],
      ],
    );
  }


Widget _buildActiveView() {
  
  return FutureBuilder(
    
    future: Future.wait([
      _firestoreService.getLeague(widget.leagueId),
      _firestoreService.fetchLeagueTeams(widget.leagueId),
      _firestoreService.fetchMatches(widget.leagueId),
       _firestoreService.fetchAvailableTeams(), // 👈 GLOBAL TEAMS
    ]),
    builder: (context, AsyncSnapshot<List<dynamic>> snap) {
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final leagueDoc = snap.data![0] as DocumentSnapshot;
      final league = (leagueDoc.data() ?? {}) as Map<String, dynamic>;
      final teamDocs = snap.data![1] as List<QueryDocumentSnapshot>;
      final matchDocs = snap.data![2] as List<QueryDocumentSnapshot>;

      /// GROUP TEAMS
      final Map<String, List<String>> grouped = {};
      for (final d in teamDocs) {
        final data = d.data() as Map<String, dynamic>;
        final tid = data['teamId'] as String;
        final g = data['group'] as String;
        grouped.putIfAbsent(g, () => []).add(tid);
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// ---------------- LEAGUE HEADER ----------------
            Text(
              league['name'] ?? '',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            /// ---------------- LEAGUE INFO CARD ----------------
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow('Season', league['season']),
                    _infoRow('Teams', league['NumberOfTeams']),
                    _infoRow('Groups', league['NumberOfGroups']),
                    _infoRow('Match System', league['MatchesSystem']),
                    _infoRow('Pairing', league['TeamsPairing']),
                    _infoRow(
                      'Match Days',
                      (league['MatchDays'] as List<dynamic>?)?.join(', '),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// ---------------- TEAMS BY GROUP ----------------
            const Text(
              'Teams by Group',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ...grouped.entries.map((e) {
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: Text(
                    'Group ${e.key}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: e.value
                      .map(
                        (tid) => ListTile(
                          leading: const Icon(Icons.shield_outlined),
                          title: Text(tid),
                        ),
                      )
                      .toList(),
                ),
              );
            }).toList(),

            const SizedBox(height: 24),

            /// ---------------- MATCHES ----------------
            const Text(
              'Scheduled Matches',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ...matchDocs.map((d) {
              final data = d.data() as Map<String, dynamic>;

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.sports_soccer),
                  title: Text(
                    '${data['teamAId']}  vs  ${data['teamBId']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Group ${data['group']} • ${data['date']}',
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      );

    },

    
  );


}


  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final status = (_leagueData?['status'] as String?) ?? 'inactive';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initialize League'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: status == 'inactive' ? _buildInitializationView() : _buildActiveView(),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value?.toString() ?? '—',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
Future<void> _showDialog({
  required String title,
  required String message,
}) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}


}

class _PlannedMatch {
  final String group;
  final String teamAId;
  final String teamBId;

  const _PlannedMatch({
    required this.group,
    required this.teamAId,
    required this.teamBId,
  });
}
