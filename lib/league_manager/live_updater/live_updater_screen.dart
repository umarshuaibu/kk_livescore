// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/admins/management/reusables/custom_dialog.dart';
import 'package:kklivescoreadmin/league_manager/knockout_system/knockout_system_logics.dart';

class LiveUpdaterScreen extends StatefulWidget {
  final String leagueId;
  final String matchId;
  final String? roundName; // optional

  const LiveUpdaterScreen({
    super.key,
    required this.leagueId,
    required this.matchId,
    this.roundName,
  });

  @override
  State<LiveUpdaterScreen> createState() => _LiveUpdaterScreenState();
}

class _LiveUpdaterScreenState extends State<LiveUpdaterScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _teamAId;
  String? _teamBId;
  String? _teamAName;
  String? _teamBName;
  String? _teamALogo;
  String? _teamBLogo;

  List<Map<String, dynamic>> _teamAPlayers = [];
  List<Map<String, dynamic>> _teamBPlayers = [];

  String _selectedEvent = "Goal +1";
  String? _selectedTeamId;
  String? _selectedPlayerId;
  String? _selectedPlayerOutId;
  String? _selectedPlayerInId;

  bool _loading = true;

  StreamSubscription<DocumentSnapshot>? _matchSub;

  @override
  void initState() {
    super.initState();
    _initStreamsAndLoad();
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    super.dispose();
  }

  Future<void> _updateStandings({
    required String leagueId,
    required String teamId,
    required String groupId,
    required int goalsFor,
    required int goalsAgainst,
  }) async {
    final standingsRef = _firestore
        .collection('leagues')
        .doc(leagueId)
        .collection('standings');

    final query = await standingsRef
        .where('teamId', isEqualTo: teamId)
        .where('group', isEqualTo: groupId)
        .limit(1)
        .get();

    DocumentReference docRef;

    if (query.docs.isEmpty) {
      docRef = standingsRef.doc();
      await docRef.set({
        'teamId': teamId,
        'group': groupId,
        'played': 0,
        'won': 0,
        'drawn': 0,
        'lost': 0,
        'goalsFor': 0,
        'goalsAgainst': 0,
        'goalDifference': 0,
        'points': 0,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } else {
      docRef = query.docs.first.reference;
    }

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() as Map<String, dynamic>;

      final played = (data['played'] ?? 0) + 1;
      final gf = (data['goalsFor'] ?? 0) + goalsFor;
      final ga = (data['goalsAgainst'] ?? 0) + goalsAgainst;
      final gd = gf - ga;

      int won = data['won'] ?? 0;
      int drawn = data['drawn'] ?? 0;
      int lost = data['lost'] ?? 0;
      int points = data['points'] ?? 0;

      if (goalsFor > goalsAgainst) {
        won += 1;
        points += 3;
      } else if (goalsFor == goalsAgainst) {
        drawn += 1;
        points += 1;
      } else {
        lost += 1;
      }

      tx.update(docRef, {
        'played': played,
        'won': won,
        'drawn': drawn,
        'lost': lost,
        'goalsFor': gf,
        'goalsAgainst': ga,
        'goalDifference': gd,
        'points': points,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _initStreamsAndLoad() async {
    final matchRef = _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .collection('matches')
        .doc(widget.matchId);

    _matchSub = matchRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final teamAId = data['teamAId'] as String?;
      final teamBId = data['teamBId'] as String?;

      if (teamAId != null && teamAId != _teamAId ||
          teamBId != null && teamBId != _teamBId ||
          _loading) {
        _teamAId = teamAId;
        _teamBId = teamBId;
        await _loadTeamsMetaAndPlayers();
      }

      if (_loading) setState(() => _loading = false);
    });
  }

  Future<void> _goLive(DocumentReference matchRef) async {
    await matchRef.update({'status': 'live'});
  }

  Future<void> _confirmGoLive(
    BuildContext context,
    DocumentReference matchRef,
  ) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Go Live?'),
        content: const Text(
          'Are you sure you want to start this match live?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );
    if (firstConfirm != true) return;

    final secondConfirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: const Text(
          'This action cannot be undone.\nDo you want to continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Go Live'),
          ),
        ],
      ),
    );
    if (secondConfirm == true) await _goLive(matchRef);
  }

  Future<void> _loadTeamsMetaAndPlayers() async {
    if (_teamAId == null || _teamBId == null) {
      setState(() {
        _teamAPlayers = [];
        _teamBPlayers = [];
        _teamAName = null;
        _teamBName = null;
        _teamALogo = null;
        _teamBLogo = null;
      });
      return;
    }

    final teamAFuture = _firestore.collection('teams').doc(_teamAId).get();
    final teamBFuture = _firestore.collection('teams').doc(_teamBId).get();
    final results = await Future.wait([teamAFuture, teamBFuture]);

    final teamADoc = results[0];
    final teamBDoc = results[1];

    _teamAName = teamADoc.data()?['name'] as String?;
    _teamBName = teamBDoc.data()?['name'] as String?;
    _teamALogo = teamADoc.data()?['logo'] as String?;
    _teamBLogo = teamBDoc.data()?['logo'] as String?;

    final lineupDocA = await _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .collection('matches')
        .doc(widget.matchId)
        .collection('lineups')
        .doc(_teamAId)
        .get();

    final lineupDocB = await _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .collection('matches')
        .doc(widget.matchId)
        .collection('lineups')
        .doc(_teamBId)
        .get();

    final playerIdsA = lineupDocA.exists
        ? _extractPlayerIdsFromList(lineupDocA.data()?['players'] ?? [])
        : teamADoc.data()?['players'] ?? [];
    final playerIdsB = lineupDocB.exists
        ? _extractPlayerIdsFromList(lineupDocB.data()?['players'] ?? [])
        : teamBDoc.data()?['players'] ?? [];

    final playersA = await _fetchPlayerDocsByIds(playerIdsA);
    final playersB = await _fetchPlayerDocsByIds(playerIdsB);

    setState(() {
      _teamAPlayers = playersA;
      _teamBPlayers = playersB;
    });
  }

  List<String> _extractPlayerIdsFromList(dynamic raw) {
    final List<String> ids = [];
    if (raw is Iterable) {
      for (final item in raw) {
        if (item is String) ids.add(item);
        else if (item is Map && (item['id'] != null || item['playerId'] != null)) {
          ids.add(item['id']?.toString() ?? item['playerId']?.toString() ?? item.toString());
        } else ids.add(item.toString());
      }
    }
    return ids;
  }

  Future<List<Map<String, dynamic>>> _fetchPlayerDocsByIds(List<dynamic> idsDynamic) async {
    final ids = idsDynamic.whereType<String>().toList();
    if (ids.isEmpty) return [];

    const chunk = 10;
    final List<Map<String, dynamic>> out = [];
    for (var i = 0; i < ids.length; i += chunk) {
      final sub = ids.sublist(i, i + chunk > ids.length ? ids.length : i + chunk);
      final snap = await _firestore.collection('players').where(FieldPath.documentId, whereIn: sub).get();
      out.addAll(snap.docs.map((d) => {'id': d.id, 'name': d.data()['name'] ?? d.id}));
    }
    return out;
  }

  /// ✅ MARK MATCH AS COMPLETED (LEAGUE + KNOCKOUT SEPARATED)
  Future<void> _markMatchCompleted() async {
    if (!mounted) return;

    final doIt = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark Completed'),
        content: const Text(
          'Are you sure you want to mark this match as completed?\nThis will update standings or bracket.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );
    if (doIt != true) return;

    final matchRef = _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .collection('matches')
        .doc(widget.matchId);
    final matchSnap = await matchRef.get();
    if (!matchSnap.exists) return;
    final match = matchSnap.data()!;

if (match['processed'] == true)
 {
  await CustomDialog.show(
    context,
    title: 'Already Completed',
    message: 'This match has already been processed.',
    type: DialogType.error,
  );
  return;
}


    final int scoreA = match['scoreA'] ?? 0;
    final int scoreB = match['scoreB'] ?? 0;
    final String teamAId = match['teamAId'];
    final String teamBId = match['teamBId'];
    final String groupId = match['group'] ?? '';

    final leagueSnap = await _firestore.collection('leagues').doc(widget.leagueId).get();
    final leagueData = leagueSnap.data();
    final String leagueType = leagueData?['MatchesSystem'] ?? 'home_and_away';

if (leagueType == 'Knockout') {
  // ✅ Knockout only
  await handleKnockoutMatch(
    firestore: _firestore,
    match: match,
    scoreA: scoreA,
    scoreB: scoreB,
  );

  await matchRef.update({
  'status': 'completed',
  'processed': true,
  'lastUpdated': FieldValue.serverTimestamp(),
});


} else {
  // ✅ Home & Away (League system)
  await Future.wait([
    _updateStandings(
      leagueId: widget.leagueId,
      teamId: teamAId,
      groupId: groupId,
      goalsFor: scoreA,
      goalsAgainst: scoreB,
    ),
    _updateStandings(
      leagueId: widget.leagueId,
      teamId: teamBId,
      groupId: groupId,
      goalsFor: scoreB,
      goalsAgainst: scoreA,
    ),
matchRef.update({
  'status': 'completed',
  'processed': true,
  'lastUpdated': FieldValue.serverTimestamp(),
}),

  ]);
}


    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// ✅ EVENT RECORDING
  Future<void> _recordEvent() async {
    if (_selectedTeamId == null) {
      await CustomDialog.show(context, title: 'Missing', message: 'Please select a team', type: DialogType.error);
      return;
    }

    final matchRef = _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .collection('matches')
        .doc(widget.matchId);

    final isTeamA = _selectedTeamId == _teamAId;
    final eventId = _firestore.collection('tmp').doc().id;

    final Map<String, dynamic> eventDoc = {
      'id': eventId,
      'type': _selectedEvent,
      'teamId': _selectedTeamId,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (_selectedEvent == 'Substitution') {
      if (_selectedPlayerOutId == null || _selectedPlayerInId == null) {
        await CustomDialog.show(context, title: 'Missing', message: 'Select both player out & in', type: DialogType.error);
        return;
      }
      eventDoc['out'] = _selectedPlayerOutId;
      eventDoc['in'] = _selectedPlayerInId;

      final field = isTeamA ? 'subsA' : 'subsB';
      await _firestore.runTransaction((tx) async {
        tx.set(matchRef.collection('events').doc(eventId), eventDoc);
        tx.update(matchRef, {field: FieldValue.increment(1)});
      });
      if (!mounted) return;
      await CustomDialog.show(context, title: 'Recorded', message: 'Substitution recorded', type: DialogType.success);
      return;
    }

    if (_selectedPlayerId == null) {
      await CustomDialog.show(context, title: 'Missing', message: 'Please select a player', type: DialogType.error);
      return;
    }

    eventDoc['playerId'] = _selectedPlayerId;
    String? counterField;
    Map<String, dynamic> updateMap = {};

    switch (_selectedEvent) {
      case 'Goal +1':
        counterField = isTeamA ? 'scoreA' : 'scoreB';
        updateMap[counterField] = FieldValue.increment(1);
        break;
      case 'Goal -1':
        counterField = isTeamA ? 'scoreA' : 'scoreB';
        updateMap[counterField] = FieldValue.increment(-1);
        break;
      case 'Yellow Card':
        counterField = isTeamA ? 'yellowA' : 'yellowB';
        updateMap[counterField] = FieldValue.increment(1);
        break;
      case 'Red Card':
        counterField = isTeamA ? 'redA' : 'redB';
        updateMap[counterField] = FieldValue.increment(1);
        break;
      default:
        break;
    }

    try {
      await _firestore.runTransaction((tx) async {
        tx.set(matchRef.collection('events').doc(eventId), eventDoc);
        if (updateMap.isNotEmpty) tx.update(matchRef, updateMap);
      });

      if (!mounted) return;
      await CustomDialog.show(context, title: 'Success', message: 'Event recorded', type: DialogType.success);

      setState(() {
        _selectedPlayerId = null;
        _selectedPlayerInId = null;
        _selectedPlayerOutId = null;
      });
    } catch (e) {
      if (!mounted) return;
      await CustomDialog.show(context, title: 'Error', message: 'Failed to record event: $e', type: DialogType.error);
    }
  }

  // ... (UI builder methods remain unchanged: _buildTeamsStatusCard, _statColumn, _buildToolsetCard, build)


  Widget _buildTeamsStatusCard(DocumentSnapshot matchSnapshot) {
    final data = matchSnapshot.data() as Map<String, dynamic>? ?? {};

    final scoreA = data['scoreA'] ?? 0;
    final scoreB = data['scoreB'] ?? 0;
    final yellowA = data['yellowA'] ?? 0;
    final yellowB = data['yellowB'] ?? 0;
    final redA = data['redA'] ?? 0;
    final redB = data['redB'] ?? 0;
    final subsA = data['subsA'] ?? 0;
    final subsB = data['subsB'] ?? 0;

    return Card(
      elevation: 4,
      child: SizedBox(
        width: 900,
        height: 160,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _teamALogo != null && _teamALogo!.isNotEmpty
                            ? Image.network(_teamALogo!, width: 48, height: 48, fit: BoxFit.cover)
                            : const Icon(Icons.shield, size: 48),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _teamAName ?? 'Team A',
                            style: AppTextStyles.subheadingStyle,
                          ),
                        ),
                        Text(
                          scoreA.toString(),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statColumn('Yellow', yellowA.toString()),
                        _statColumn('Red', redA.toString()),
                        _statColumn('Subs', subsA.toString()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _teamBName != null
                            ? Expanded(
                                child: Text(
                                  _teamBName ?? 'Team B',
                                  style: AppTextStyles.subheadingStyle,
                                ),
                              )
                            : const SizedBox.shrink(),
                        const SizedBox(width: 8),
                        Text(
                          scoreB.toString(),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        _teamBLogo != null && _teamBLogo!.isNotEmpty
                            ? Image.network(_teamBLogo!, width: 48, height: 48, fit: BoxFit.cover)
                            : const Icon(Icons.shield, size: 48),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statColumn('Yellow', yellowB.toString()),
                        _statColumn('Red', redB.toString()),
                        _statColumn('Subs', subsB.toString()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String title, String value) {
    return Column(
      children: [
        Text(title, style: AppTextStyles.bodyStyle),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildToolsetCard() {
    final playersForSelectedTeam = _selectedTeamId == _teamAId ? _teamAPlayers : _teamBPlayers;

    return Card(
      elevation: 4,
      child: SizedBox(
        width: 900,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedEvent,
                      items: [
                        'Goal +1',
                        'Goal -1',
                        'Yellow Card',
                        'Red Card',
                        'Substitution',
                      ]
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedEvent = v ?? _selectedEvent;
                        _selectedPlayerId = null;
                        _selectedPlayerInId = null;
                        _selectedPlayerOutId = null;
                      }),
                      decoration: const InputDecoration(label: Text('Select Event')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _selectedTeamId,
                      items: [
                        if (_teamAId != null) DropdownMenuItem(value: _teamAId, child: Text(_teamAName ?? 'Team A')),
                        if (_teamBId != null) DropdownMenuItem(value: _teamBId, child: Text(_teamBName ?? 'Team B')),
                      ],
                      onChanged: (v) => setState(() {
                        _selectedTeamId = v;
                        _selectedPlayerId = null;
                        _selectedPlayerInId = null;
                        _selectedPlayerOutId = null;
                      }),
                      decoration: const InputDecoration(label: Text('Select Team')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_selectedEvent == 'Substitution') ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPlayerOutId,
                        items: playersForSelectedTeam
                            .map((p) => DropdownMenuItem<String>(
                                  value: p['id'] as String,
                                  child: Text(p['name'] as String),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedPlayerOutId = v),
                        decoration: const InputDecoration(label: Text('Player Out')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPlayerInId,
                        items: playersForSelectedTeam
                            .map((p) => DropdownMenuItem<String>(
                                  value: p['id'] as String,
                                  child: Text(p['name'] as String),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedPlayerInId = v),
                        decoration: const InputDecoration(label: Text('Player In')),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  value: _selectedPlayerId,
                  items: playersForSelectedTeam
                      .map((p) => DropdownMenuItem<String>(
                            value: p['id'] as String,
                            child: Text(p['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPlayerId = v),
                  decoration: const InputDecoration(label: Text('Select Player')),
                ),
              ],

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _recordEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(160, 44),
                  ),
                  child: const Text('Record Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchRef = _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .collection('matches')
        .doc(widget.matchId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Updater'),
        backgroundColor: AppColors.whiteColor,
        actions: [
          IconButton(
            tooltip: 'Mark as Completed',
            icon: const Icon(Icons.check_circle_outline),
            onPressed: _markMatchCompleted,
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),

              StreamBuilder<DocumentSnapshot>(
                stream: matchRef.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final matchData = snapshot.data!.data() as Map<String, dynamic>;
                  final String status = (matchData['status'] ?? 'scheduled').toString();
                  final bool canGoLive = status == 'scheduled';

                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.wifi_tethering),
                          label: const Text('GO LIVE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canGoLive ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: canGoLive ? () => _confirmGoLive(context, matchRef) : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTeamsStatusCard(snapshot.data!),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),
              _buildToolsetCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
