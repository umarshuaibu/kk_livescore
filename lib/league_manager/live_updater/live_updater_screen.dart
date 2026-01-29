// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/admins/management/reusables/custom_dialog.dart';

class LiveUpdaterScreen extends StatefulWidget {
  final String leagueId;
  final String matchId;

  const LiveUpdaterScreen({
    super.key,
    required this.leagueId,
    required this.matchId,
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

  // Toolset state
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

  //if (query.docs.isEmpty) return;






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









  //final docRef = query.docs.first.reference;

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
    // subscribe to match doc stream so UI auto-refreshes (teams status)
    final matchRef = _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .collection('matches')
        .doc(widget.matchId);

    // Listen to match doc and refresh local team/player/meta when needed
    _matchSub = matchRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final teamAId = data['teamAId'] as String?;
      final teamBId = data['teamBId'] as String?;

      // If teams changed or first load, reload teams & players
      if (teamAId != null && teamAId != _teamAId ||
          teamBId != null && teamBId != _teamBId ||
          _loading) {
        _teamAId = teamAId;
        _teamBId = teamBId;
        await _loadTeamsMetaAndPlayers();
      }

      // finished loading when first snapshot arrives
      if (_loading) setState(() => _loading = false);
    });
  }

  Future<void> _goLive(DocumentReference matchRef) async {
    await matchRef.update({
      'status': 'live',
    });
  }

  Future<void> _confirmGoLive(
  BuildContext context,
  DocumentReference matchRef,
) async {
  final bool? firstConfirm = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Go Live?'),
        content: const Text(
          'Are you sure you want to start this match live?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      );
    },
  );

  if (firstConfirm != true) return;

  final bool? secondConfirm = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Final Confirmation'),
        content: const Text(
          'This action cannot be undone.\n\nDo you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Go Live'),
          ),
        ],
      );
    },
  );

  if (secondConfirm == true) {
    await _goLive(matchRef);
  }
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

    // fetch team docs
    final teamAFuture = _firestore.collection('teams').doc(_teamAId).get();
    final teamBFuture = _firestore.collection('teams').doc(_teamBId).get();

    final results = await Future.wait([teamAFuture, teamBFuture]);

    final teamADoc = results[0];
    final teamBDoc = results[1];

    _teamAName = teamADoc.data()?['name'] as String?;
    _teamBName = teamBDoc.data()?['name'] as String?;
    _teamALogo = teamADoc.data()?['logo'] as String?;
    _teamBLogo = teamBDoc.data()?['logo'] as String?;

    // Attempt to fetch lineups first; if no lineup exists, fallback to team players array
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

    List<dynamic> playerIdsA = [];
    List<dynamic> playerIdsB = [];

    if (lineupDocA.exists) {
      // lineup stored as list of {id:, name:} maps or ids; normalize
      final raw = lineupDocA.data()?['players'] ?? [];
      playerIdsA = _extractPlayerIdsFromList(raw);
    } else {
      playerIdsA = teamADoc.data()?['players'] ?? [];
    }

    if (lineupDocB.exists) {
      final raw = lineupDocB.data()?['players'] ?? [];
      playerIdsB = _extractPlayerIdsFromList(raw);
    } else {
      playerIdsB = teamBDoc.data()?['players'] ?? [];
    }

    final playersA = await _fetchPlayerDocsByIds(playerIdsA);
    final playersB = await _fetchPlayerDocsByIds(playerIdsB);

    setState(() {
      _teamAPlayers = playersA;
      _teamBPlayers = playersB;
    });
  }

  /// Normalize possible player lists (ids, maps with id, maps with 'id' key)
  List<String> _extractPlayerIdsFromList(dynamic raw) {
    final List<String> ids = [];
    if (raw is Iterable) {
      for (final item in raw) {
        if (item is String) {
          ids.add(item);
        } else if (item is Map) {
          // accept either { "id": "...", "name": "..." } or { "playerId": "..." }
          if (item.containsKey('id')) {
            ids.add(item['id'].toString());
          } else if (item.containsKey('playerId')) {
            ids.add(item['playerId'].toString());
          }else {
            // fallback - push whole item stringified
            ids.add(item.toString());
          }
        } else {
          ids.add(item.toString());
        }
      }
    }
    return ids;
  }

  Future<List<Map<String, dynamic>>> _fetchPlayerDocsByIds(List<dynamic> idsDynamic) async {
    final ids = idsDynamic.where((e) => e != null).map((e) => e.toString()).toList();
    if (ids.isEmpty) return [];
    // Firestore whereIn requires <= 10 items — chunk if necessary
    const chunk = 10;
    final List<Map<String, dynamic>> out = [];
    for (var i = 0; i < ids.length; i += chunk) {
      final sub = ids.sublist(i, i + chunk > ids.length ? ids.length : i + chunk);
      final snap = await _firestore.collection('players').where(FieldPath.documentId, whereIn: sub).get();
      for (final d in snap.docs) {
        out.add({'id': d.id, 'name': d.data()['name'] ?? d.id});
      }
    }
    return out;
  }

Future<void> _markMatchCompleted() async {
  if (!mounted) return;

  final doIt = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Mark Completed'),
      content: const Text(
        'Are you sure you want to mark this match as completed?\n'
        'This action will update standings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('No'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );

  if (!mounted || doIt != true) return;

  final matchRef = _firestore
      .collection('leagues')
      .doc(widget.leagueId)
      .collection('matches')
      .doc(widget.matchId);

  final matchSnap = await matchRef.get();
  if (!matchSnap.exists) return;

  final match = matchSnap.data() as Map<String, dynamic>;

  final int scoreA = match['scoreA'] ?? 0;
  final int scoreB = match['scoreB'] ?? 0;
  final String teamAId = match['teamAId'];
  final String teamBId = match['teamBId'];
  final String groupId = match['group'];

  // 🔄 Update standings for both teams
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
  ]);

  // ✅ Mark match as completed
  await matchRef.update({'status': 'completed'});

  if (mounted) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}


  /// Record event and update counters
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

    // handle substitution differently
    if (_selectedEvent == 'Substitution') {
      if (_selectedPlayerOutId == null || _selectedPlayerInId == null) {
        await CustomDialog.show(context, title: 'Missing', message: 'Select both player out & player in', type: DialogType.error);
        return;
      }
      eventDoc['out'] = _selectedPlayerOutId;
      eventDoc['in'] = _selectedPlayerInId;

      // increment subsA / subsB
      final field = isTeamA ? 'subsA' : 'subsB';
      await _firestore.runTransaction((tx) async {
        tx.set(matchRef.collection('events').doc(eventId), eventDoc);
        tx.update(matchRef, {field: FieldValue.increment(1)});
      });

      // optionally update any lineup state if needed (not done here)
        if (!mounted) return;
      await CustomDialog.show(context, title: 'Recorded', message: 'Substitution recorded', type: DialogType.success);
      return;
    }

    // non substitution events: player selection required
    if (_selectedPlayerId == null) {
      await CustomDialog.show(context, title: 'Missing', message: 'Please select a player', type: DialogType.error);
      return;
    }

    eventDoc['playerId'] = _selectedPlayerId;

    // Determine which match fields to update
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
        // unknown event
        break;
    }

    // Use transaction to write event and update counters atomically
    try {
      await _firestore.runTransaction((tx) async {
        final matchSnapshot = await tx.get(matchRef);
        // make sure doc exists
        if (!matchSnapshot.exists) {
          throw Exception('Match not found');
        }
        tx.set(matchRef.collection('events').doc(eventId), eventDoc);
        if (updateMap.isNotEmpty) {
          tx.update(matchRef, updateMap);
        }
      });
          if (!mounted) return; // ✅ Prevent using context if widget is disposed
      await CustomDialog.show(context, title: 'Success', message: 'Event recorded', type: DialogType.success);

      // reset selection of players for next event
      setState(() {
        _selectedPlayerId = null;
        _selectedPlayerInId = null;
        _selectedPlayerOutId = null;
      });
    } catch (e) {
        if (!mounted) return; // ✅ Prevent using context if widget is disposed
      await CustomDialog.show(context, title: 'Error', message: 'Failed to record event: $e', type: DialogType.error);
    }
  }

  // Build team status card from live match doc snapshot
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
        width: 900, // keep a reasonable width for desktop/admin
        height: 160,
        child: Row(
          children: [
            // Team A block
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // logo + name + score
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
                    // stats row
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

            // Divider
            const VerticalDivider(width: 1),

            // Team B block
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
    // which players list to show depends on selectedTeamId
    final playersForSelectedTeam = _selectedTeamId == _teamAId ? _teamAPlayers : _teamBPlayers;

    return Card(
      elevation: 4,
      child: SizedBox(
        width: 900,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // event row: event dropdown + team dropdown
              Row(
                children: [
                  // Event dropdown
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
                        // clear player fields when event switches
                        _selectedPlayerId = null;
                        _selectedPlayerInId = null;
                        _selectedPlayerOutId = null;
                      }),
                      decoration: const InputDecoration(label: Text('Select Event')),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Team selector (Team A or B)
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

              // Player selectors
// Player selectors
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



              // Record event button
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

            /// 🔴 STREAMED MATCH DATA
            StreamBuilder<DocumentSnapshot>(
              stream: matchRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final matchData =
                    snapshot.data!.data() as Map<String, dynamic>;

                final String status =
                    (matchData['status'] ?? 'scheduled').toString();

                final bool canGoLive = status == 'scheduled';

                return Column(
                  children: [
                    /// 🟢 GO LIVE BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.wifi_tethering),
                        label: const Text('GO LIVE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canGoLive
                              ? Colors.green
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                        onPressed: canGoLive
                            ? () => _confirmGoLive(context, matchRef)
                            : null, // 🔒 disabled automatically
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// 🟦 TEAMS STATUS CARD (unchanged)
                    _buildTeamsStatusCard(snapshot.data!),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            /// 🛠 TOOLSET CARD (unchanged)
            _buildToolsetCard(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
}
}