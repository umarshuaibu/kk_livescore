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
  State<LeagueInitializationScreen> createState() =>
      _LeagueInitializationScreenState();
}

class _LeagueInitializationScreenState
    extends State<LeagueInitializationScreen> {
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
  List<Map<String, dynamic>> _leagueTeams = [];
  List<QueryDocumentSnapshot> _availableTeamDocs = [];
  DateTime? _startingDate;
  bool _loading = true;

  final Map<String, Set<String>> _groupSelections = {};
  final Set<String> _assignedTeamsSet = {};
  final List<Map<String, dynamic>> _manualPairs = []; // {group:'A', teams:[t1,t2]}

  @override
  void initState() {
    super.initState();
    _loadAll();
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

  void _toggleTeamForGroup(String group, String teamId) {
    final set = _groupSelections[group] ?? <String>{};
    if (set.contains(teamId)) {
      set.remove(teamId);
      _assignedTeamsSet.remove(teamId);
    } else {
      if (_assignedTeamsSet.contains(teamId)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Team already assigned to another group')));
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
    if (totalAssigned != numberOfTeams) return false;
    return true;
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

  bool _isInitializing = false;

  /// ---------------- AUTOMATED INITIALIZATION ----------------
  Future<void> _initializeAutomated() async {
    if (_isInitializing) return;

    if (!_validateAssignments()) {
      await _showDialog(
          title: 'Invalid configuration',
          message: 'Teams per group must match configuration.');
      return;
    }

    if (_startingDate == null) {
      await _showDialog(
          title: 'Missing date', message: 'Please select a starting date.');
      return;
    }

    setState(() => _isInitializing = true);

    try {
      final matchDays = List<String>.from(_leagueData?['MatchDays'] ?? []);
      final matchesSystem =
          _leagueData?['MatchesSystem'] as String? ?? 'Home_and_away';

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
        // Flatten all teams into first-round manual pairs if any
        List<Map<String, dynamic>> firstRoundPairs = [];
        if (_manualPairs.isNotEmpty) {
          firstRoundPairs =
              generateManualMatches(pairs: _manualPairs, isKnockout: true);
        } else {
          final teams = _leagueTeams.map((t) => t['teamId'] as String).toList();
          // auto-pair sequentially if no manual pairs
          for (int i = 0; i < teams.length; i += 2) {
            if (i + 1 < teams.length) {
              firstRoundPairs.add({
                'teamAId': teams[i],
                'teamBId': teams[i + 1],
              });
            } else {
              firstRoundPairs.add({
                'teamAId': teams[i],
                'teamBId': 'BYE',
              });
            }
          }
        }

        plannedMatches = knockoutTournamentFromManual(firstRoundPairs);
      } else {
        // Group-based round robin
        final Map<String, List<PlannedMatch>> matchesByGroup = {};
        for (final g in groupNames) {
          final teams = groupsMap[g] ?? [];
          final pairs =
              matchesSystem == 'Home_and_away' ? doubleRoundRobin(teams) : singleRoundRobin(teams);
          matchesByGroup[g] = pairs
              .map((p) => PlannedMatch(group: g, teamAId: p[0], teamBId: p[1]))
              .toList();
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

      if (plannedMatches.isEmpty) {
        throw Exception('No matches generated');
      }

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

        writeTasks.add(_firestoreService.createMatch(leagueId: widget.leagueId, matchId: id, matchData: {
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
        writeTasks.add(_firestoreService.createStanding(
            leagueId: widget.leagueId, teamId: teamId, standingData: standing));
      }

      await Future.wait(writeTasks);

      await _firestore
          .collection('leagues')
          .doc(widget.leagueId)
          .update({'status': 'active'});

      if (!mounted) return;

      await _showDialog(
          title: 'League Initialized',
          message: 'The league has been successfully activated.');

      await _loadAll();
    } catch (_) {
      if (mounted) {
        await _showDialog(
            title: 'Initialization failed',
            message:
                'Something went wrong while initializing the league. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  /// ---------------- MANUAL INITIALIZATION ----------------
  Future<void> _initializeManual() async {
    if (!_validateAssignments()) {
      await _showDialog(
          title: 'Invalid',
          message: 'Teams per group must equal NumberOfTeams/NumberOfGroups');
      return;
    }
    if (_startingDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick a starting date')));
      return;
    }
    if (_manualPairs.isEmpty &&
        (_leagueData?['MatchesSystem'] as String?) != 'Knockout') {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No pairs added')));
      return;
    }

    final matchDays = List<String>.from(_leagueData?['MatchDays'] ?? []);
    List<Map<String, dynamic>> pairs;

    if ((_leagueData?['MatchesSystem'] as String?) == 'Knockout') {
      pairs = generateManualMatches(pairs: _manualPairs, isKnockout: true);
      if (pairs.isEmpty) {
        final teams = _leagueTeams.map((t) => t['teamId'] as String).toList();
        pairs = [];
        for (int i = 0; i < teams.length; i += 2) {
          if (i + 1 < teams.length) {
            pairs.add({'teamAId': teams[i], 'teamBId': teams[i + 1]});
          } else {
            pairs.add({'teamAId': teams[i], 'teamBId': 'BYE'});
          }
        }
      }
      pairs = generateKnockoutRounds(pairs);
    } else {
      pairs = generateManualMatches(pairs: _manualPairs);
    }

    final scheduleDates =
        scheduleMatches(startDate: _startingDate!, matchDays: matchDays, totalMatches: pairs.length);

    for (int i = 0; i < pairs.length; i++) {
      final match = pairs[i];
      final id = FirebaseFirestore.instance.collection('x').doc().id;
      final matchDoc = {
        'id': id,
        'teamAId': match['teamAId'],
        'teamBId': match['teamBId'],
        'status': 'scheduled',
        'group': match['group'] ?? '',
        'leagueId': widget.leagueId,
        'date': scheduleDates[i],
      };
      await _firestoreService.createMatch(
          leagueId: widget.leagueId, matchId: id, matchData: matchDoc);
    }

    final teamDocs = await _firestoreService.fetchLeagueTeams(widget.leagueId);
    for (final d in teamDocs) {
      final data = d.data() as Map<String, dynamic>;
      final teamId = data['teamId'] as String;
      final group = data['group'] as String? ?? '';
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
      await _firestoreService.createStanding(
          leagueId: widget.leagueId, teamId: teamId, standingData: standing);
    }

    await FirebaseFirestore.instance
        .collection('leagues')
        .doc(widget.leagueId)
        .update({'status': 'active'});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('League initialized (manual)')));
    await _loadAll();
  }

  /// ---------------- HELPERS ----------------
  Future<void> _showDialog(
      {required String title, required String message}) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
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
        child: status == 'inactive'
            ? _buildInitializationView()
            : _buildActiveView(),
      ),
    );
  }

Widget _buildInitializationView() {
  final matchesSystem = _leagueData?['MatchesSystem'] as String? ?? 'Home_and_away';
  final isKnockout = matchesSystem == 'Knockout';

  if (isKnockout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select teams for Knockout League:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _availableTeamDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final teamId = data['teamId'] as String? ?? doc.id;
            final teamName = data['name'] as String? ?? doc.id;
            final selected = _assignedTeamsSet.contains(teamId);
            final isInManualPair = _manualPairs.any(
                (p) => p['teams'].contains(teamId));

            return ChoiceChip(
              label: Text(teamName),
              selected: selected || isInManualPair,
              onSelected: (_) {
                if (!selected && !isInManualPair) {
                  _toggleTeamForGroup('knockout', teamId);
                } else if (selected) {
                  _toggleTeamForGroup('knockout', teamId);
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Manual pairing builder
        const Text('Manual Pairs (tap to remove):',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _manualPairs.map((pair) {
            final teamNames = pair['teams']
                .map((tid) => _teamIdToName[tid] ?? tid)
                .join(' vs ');
            return InputChip(
              label: Text(teamNames),
              onDeleted: () {
                setState(() {
                  for (final t in pair['teams']) {
                    _assignedTeamsSet.remove(t);
                  }
                  _manualPairs.remove(pair);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Button to create pair from selected teams
        if (_assignedTeamsSet.length >= 2)
          ElevatedButton(
            onPressed: () {
              final selectedList = _assignedTeamsSet.toList();
              final pairTeams = selectedList.take(2).toList();
              setState(() {
                _manualPairs.add({'group': 'knockout', 'teams': pairTeams});
                for (final t in pairTeams) {
                  _assignedTeamsSet.remove(t);
                }
              });
            },
            child: const Text('Create Pair'),
          ),

        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _pickStartingDate,
          child: Text(_startingDate == null
              ? 'Pick Starting Date'
              : 'Start Date: ${_startingDate!.toLocal()}'.split(' ')[0]),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _manualPairs.isEmpty || _startingDate == null
              ? null
              : _initializeManual,
          child: const Text('INITIALIZE KNOCKOUT LEAGUE'),
        ),
      ],
    );
  }

  // Default: group-based initialization
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Group-based league initialization UI'),
      // your original group-based team selection UI here
    ],
  );
}


Widget _buildActiveView() {
  final matchesSystem = _leagueData?['MatchesSystem'] as String? ?? 'Home_and_away';
  final isKnockout = matchesSystem == 'Knockout';

  if (isKnockout) {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _firestoreService.fetchMatches(widget.leagueId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No matches scheduled yet.'));
        }

        final matches = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Knockout Matches:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...matches.map((m) {
              final teamA = _teamIdToName[m['teamAId']] ?? m['teamAId'];
              final teamB = _teamIdToName[m['teamBId']] ?? m['teamBId'];
              final date = m['date'] != null
                  ? (m['date'] as Timestamp).toDate()
                  : null;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text('$teamA vs $teamB'),
                  subtitle: date != null
                      ? Text('Date: ${date.toLocal()}'.split(' ')[0])
                      : null,
                  trailing: Text(m['status'] ?? ''),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  // Default: group-based active view
  return Column(
    children: [
      const Text('Group-based matches view'),
      // your original group matches list
    ],
  );
}
}

// ----------------- Planned Match -----------------
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
