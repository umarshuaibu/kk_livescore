// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/admins/management/reusables/custom_dialog.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/league_manager/knockout_system/knockout_system_logics.dart';

// ── Design tokens ──
const _kBg = Color(0xFF0F1117);
const _kSurface = Color(0xFF161A23);
const _kSurface2 = Color(0xFF1A1F2E);
const _kGreen = Color(0xFF81C784);
const _kAmber = Color(0xFFFFB74D);
const _kBlue = Color(0xFF4FC3F7);
const _kRed = Color(0xFFE57373);
const _kPurple = Color(0xFFBA68C8);
const _kCyan = Color(0xFF4DD0E1);

class LiveUpdaterScreen extends StatefulWidget {
  final String leagueId;
  final String matchId;
  final String? roundName;

  const LiveUpdaterScreen({
    super.key,
    required this.leagueId,
    required this.matchId,
    this.roundName,
  });

  @override
  State<LiveUpdaterScreen> createState() => _LiveUpdaterScreenState();
}

class _LiveUpdaterScreenState extends State<LiveUpdaterScreen>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _teamAId;
  String? _teamBId;
  String? _teamAName;
  String? _teamBName;
  String? _teamALogo;
  String? _teamBLogo;

  List<Map<String, dynamic>> _teamAPlayers = [];
  List<Map<String, dynamic>> _teamBPlayers = [];

  String _selectedEvent = 'Goal +1';
  String? _selectedTeamId;
  String? _selectedPlayerId;
  String? _selectedPlayerOutId;
  String? _selectedPlayerInId;

  bool _loading = true;
  bool _recordingEvent = false;

  StreamSubscription<DocumentSnapshot>? _matchSub;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _scoreCtrl;

  // Event options with metadata
  final List<_EventOption> _eventOptions = const [
    _EventOption('Goal +1', Icons.sports_soccer_rounded, _kGreen),
    _EventOption('Goal -1', Icons.remove_circle_outline_rounded, _kRed),
    _EventOption('Yellow Card', Icons.square_rounded, _kAmber),
    _EventOption('Red Card', Icons.square_rounded, _kRed),
    _EventOption('Substitution', Icons.swap_horiz_rounded, _kCyan),
  ];

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _scoreCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    _initStreamsAndLoad();
  }

  @override
  void dispose() {
    _matchSub?.cancel();
    _fadeCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════
  //   ORIGINAL LOGIC — UNTOUCHED
  // ════════════════════════════════════════

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

      if (_loading) {
        setState(() => _loading = false);
        _fadeCtrl.forward();
      }
    });
  }

  Future<void> _goLive(DocumentReference matchRef) async {
    await matchRef.update({'status': 'live'});
  }

  Future<void> _confirmGoLive(
    BuildContext context,
    DocumentReference matchRef,
  ) async {
    final firstConfirm = await _showConfirmDialog(
      title: 'Go Live?',
      message: 'Are you sure you want to start this match live?',
      confirmLabel: 'Yes, Go Live',
      confirmColor: _kGreen,
      icon: Icons.wifi_tethering_rounded,
      iconColor: _kGreen,
    );
    if (firstConfirm != true) return;

    final secondConfirm = await _showConfirmDialog(
      title: 'Final Confirmation',
      message: 'This action cannot be undone.\nDo you want to continue?',
      confirmLabel: 'Go Live Now',
      confirmColor: _kRed,
      icon: Icons.warning_amber_rounded,
      iconColor: _kAmber,
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

    final teamAFuture =
        _firestore.collection('teams').doc(_teamAId).get();
    final teamBFuture =
        _firestore.collection('teams').doc(_teamBId).get();
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
        if (item is String) {
          ids.add(item);
        } else if (item is Map &&
            (item['id'] != null || item['playerId'] != null)) {
          ids.add(item['id']?.toString() ??
              item['playerId']?.toString() ??
              item.toString());
        } else {
          ids.add(item.toString());
        }
      }
    }
    return ids;
  }

  Future<List<Map<String, dynamic>>> _fetchPlayerDocsByIds(
      List<dynamic> idsDynamic) async {
    final ids = idsDynamic.whereType<String>().toList();
    if (ids.isEmpty) return [];

    const chunk = 10;
    final List<Map<String, dynamic>> out = [];
    for (var i = 0; i < ids.length; i += chunk) {
      final sub =
          ids.sublist(i, i + chunk > ids.length ? ids.length : i + chunk);
      final snap = await _firestore
          .collection('players')
          .where(FieldPath.documentId, whereIn: sub)
          .get();
      out.addAll(snap.docs
          .map((d) => {'id': d.id, 'name': d.data()['name'] ?? d.id}));
    }
    return out;
  }

  Future<void> _markMatchCompleted() async {
    if (!mounted) return;

    final doIt = await _showConfirmDialog(
      title: 'Mark Completed',
      message:
          'Mark this match as completed?\nThis will update standings or bracket.',
      confirmLabel: 'Mark Complete',
      confirmColor: _kGreen,
      icon: Icons.check_circle_rounded,
      iconColor: _kGreen,
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

    if (match['processed'] == true) {
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

    final leagueSnap = await _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .get();
    final leagueData = leagueSnap.data();
    final String leagueType =
        leagueData?['MatchesSystem'] ?? 'home_and_away';

    if (leagueType == 'Knockout') {
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

  Future<void> _recordEvent() async {
    if (_selectedTeamId == null) {
      await CustomDialog.show(context,
          title: 'Missing',
          message: 'Please select a team',
          type: DialogType.error);
      return;
    }

    setState(() => _recordingEvent = true);

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

    try {
      if (_selectedEvent == 'Substitution') {
        if (_selectedPlayerOutId == null || _selectedPlayerInId == null) {
          await CustomDialog.show(context,
              title: 'Missing',
              message: 'Select both player out & in',
              type: DialogType.error);
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
        await CustomDialog.show(context,
            title: 'Recorded',
            message: 'Substitution recorded',
            type: DialogType.success);
        setState(() {
          _selectedPlayerId = null;
          _selectedPlayerInId = null;
          _selectedPlayerOutId = null;
        });
        return;
      }

      if (_selectedPlayerId == null) {
        await CustomDialog.show(context,
            title: 'Missing',
            message: 'Please select a player',
            type: DialogType.error);
        return;
      }

      eventDoc['playerId'] = _selectedPlayerId;
      Map<String, dynamic> updateMap = {};

      switch (_selectedEvent) {
        case 'Goal +1':
          updateMap[isTeamA ? 'scoreA' : 'scoreB'] =
              FieldValue.increment(1);
          break;
        case 'Goal -1':
          updateMap[isTeamA ? 'scoreA' : 'scoreB'] =
              FieldValue.increment(-1);
          break;
        case 'Yellow Card':
          updateMap[isTeamA ? 'yellowA' : 'yellowB'] =
              FieldValue.increment(1);
          break;
        case 'Red Card':
          updateMap[isTeamA ? 'redA' : 'redB'] =
              FieldValue.increment(1);
          break;
      }

      await _firestore.runTransaction((tx) async {
        tx.set(matchRef.collection('events').doc(eventId), eventDoc);
        if (updateMap.isNotEmpty) tx.update(matchRef, updateMap);
      });

      if (!mounted) return;
      await CustomDialog.show(context,
          title: 'Success',
          message: 'Event recorded',
          type: DialogType.success);

      setState(() {
        _selectedPlayerId = null;
        _selectedPlayerInId = null;
        _selectedPlayerOutId = null;
      });
    } catch (e) {
      if (!mounted) return;
      await CustomDialog.show(context,
          title: 'Error',
          message: 'Failed to record event: $e',
          type: DialogType.error);
    } finally {
      if (mounted) setState(() => _recordingEvent = false);
    }
  }

  // ════════════════════════════════════════
  //   BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final matchRef = _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .collection('matches')
        .doc(widget.matchId);

    return Scaffold(
      backgroundColor: _kBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  _buildHeader(context, matchRef),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: matchRef.snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData ||
                            !snapshot.data!.exists) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final matchData = snapshot.data!.data()
                            as Map<String, dynamic>;
                        final String status =
                            (matchData['status'] ?? 'scheduled')
                                .toString();

                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                              16, 16, 16, 32),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Go Live Banner
                              _buildGoLiveBanner(
                                  context, matchRef, status),
                              const SizedBox(height: 16),

                              // Scoreboard
                              _buildScoreboard(matchData),
                              const SizedBox(height: 16),

                              // Event Stats Row
                              _buildEventStatsRow(matchData),
                              const SizedBox(height: 20),

                              // Record Event Section
                              _sectionLabel('Record Event'),
                              const SizedBox(height: 12),
                              _buildEventRecorder(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── HEADER ──
  Widget _buildHeader(
      BuildContext context, DocumentReference matchRef) {
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
          _iconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live Updater',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4)),
                const SizedBox(height: 2),
                Text(
                  widget.roundName ?? 'Match Management',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          // Complete button
          GestureDetector(
            onTap: _markMatchCompleted,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: _kGreen.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: _kGreen, size: 15),
                  const SizedBox(width: 6),
                  const Text('Complete',
                      style: TextStyle(
                          color: _kGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── GO LIVE BANNER ──
  Widget _buildGoLiveBanner(BuildContext context,
      DocumentReference matchRef, String status) {
    final isLive = status == 'live';
    final isScheduled = status == 'scheduled';
    final isCompleted = status == 'completed';

    Color color;
    IconData icon;
    String label;

    if (isLive) {
      color = _kGreen;
      icon = Icons.wifi_tethering_rounded;
      label = 'LIVE NOW';
    } else if (isCompleted) {
      color = Colors.grey.shade700;
      icon = Icons.check_circle_rounded;
      label = 'COMPLETED';
    } else {
      color = _kAmber;
      icon = Icons.schedule_rounded;
      label = 'SCHEDULED';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLive
                      ? 'Match is Live'
                      : isCompleted
                          ? 'Match Completed'
                          : 'Match Not Started',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isLive)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _kGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(label,
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8)),
                  ],
                ),
              ],
            ),
          ),
          if (isScheduled)
            GestureDetector(
              onTap: () => _confirmGoLive(context, matchRef),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _kGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: _kGreen.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_tethering_rounded,
                        color: _kGreen, size: 16),
                    SizedBox(width: 6),
                    Text('Go Live',
                        style: TextStyle(
                            color: _kGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── SCOREBOARD ──
  Widget _buildScoreboard(Map<String, dynamic> matchData) {
    final scoreA = matchData['scoreA'] ?? 0;
    final scoreB = matchData['scoreB'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Team A
          Expanded(
            child: Column(
              children: [
                _teamLogo(_teamALogo, _teamAName ?? 'Team A',
                    const Color(0xFF4FC3F7)),
                const SizedBox(height: 10),
                Text(
                  _teamAName ?? 'Team A',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Score
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _scoreBox(scoreA.toString()),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10),
                      child: Text(':',
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 28,
                              fontWeight: FontWeight.w300)),
                    ),
                    _scoreBox(scoreB.toString()),
                  ],
                ),
                const SizedBox(height: 6),
                _buildMatchStatusChip(
                    (matchData['status'] ?? 'scheduled')
                        .toString()),
              ],
            ),
          ),

          // Team B
          Expanded(
            child: Column(
              children: [
                _teamLogo(_teamBLogo, _teamBName ?? 'Team B',
                    const Color(0xFFBA68C8)),
                const SizedBox(height: 10),
                Text(
                  _teamBName ?? 'Team B',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBox(String score) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Center(
        child: Text(
          score,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  Widget _teamLogo(
      String? logoUrl, String name, Color fallbackColor) {
    final initials = name.trim().split(' ').length >= 2
        ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'
            .toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';

    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(logoUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _initialsAvatar(initials, fallbackColor)),
      );
    }
    return _initialsAvatar(initials, fallbackColor);
  }

  Widget _initialsAvatar(String initials, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Center(
        child: Text(initials,
            style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildMatchStatusChip(String status) {
    Color c;
    switch (status.toLowerCase()) {
      case 'live':
        c = _kGreen;
        break;
      case 'completed':
        c = Colors.grey.shade600;
        break;
      default:
        c = _kAmber;
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
            color: c, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ── EVENT STATS ROW ──
  Widget _buildEventStatsRow(Map<String, dynamic> matchData) {
    return Row(
      children: [
        Expanded(
          child: _buildStatsColumn(
            label: _teamAName ?? 'Team A',
            yellow: matchData['yellowA'] ?? 0,
            red: matchData['redA'] ?? 0,
            subs: matchData['subsA'] ?? 0,
            isLeft: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatsColumn(
            label: _teamBName ?? 'Team B',
            yellow: matchData['yellowB'] ?? 0,
            red: matchData['redB'] ?? 0,
            subs: matchData['subsB'] ?? 0,
            isLeft: false,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsColumn({
    required String label,
    required int yellow,
    required int red,
    required int subs,
    required bool isLeft,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statBubble('🟨', yellow.toString(), _kAmber),
              _statBubble('🟥', red.toString(), _kRed),
              _statBubble('🔄', subs.toString(), _kCyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBubble(String emoji, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(emoji,
                style: const TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  // ── EVENT RECORDER ──
  Widget _buildEventRecorder() {
    final playersForSelectedTeam =
        _selectedTeamId == _teamAId ? _teamAPlayers : _teamBPlayers;

    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event type chips
          _subLabel('Event Type'),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _eventOptions.map((opt) {
                final isActive = _selectedEvent == opt.label;
                return _EventChip(
                  option: opt,
                  isActive: isActive,
                  onTap: () => setState(() {
                    _selectedEvent = opt.label;
                    _selectedPlayerId = null;
                    _selectedPlayerInId = null;
                    _selectedPlayerOutId = null;
                  }),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 18),

          // Team selector
          _subLabel('Team'),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_teamAId != null)
                Expanded(
                  child: _TeamToggleBtn(
                    label: _teamAName ?? 'Team A',
                    isSelected: _selectedTeamId == _teamAId,
                    color: _kBlue,
                    onTap: () => setState(() {
                      _selectedTeamId = _teamAId;
                      _selectedPlayerId = null;
                      _selectedPlayerInId = null;
                      _selectedPlayerOutId = null;
                    }),
                  ),
                ),
              if (_teamAId != null && _teamBId != null)
                const SizedBox(width: 10),
              if (_teamBId != null)
                Expanded(
                  child: _TeamToggleBtn(
                    label: _teamBName ?? 'Team B',
                    isSelected: _selectedTeamId == _teamBId,
                    color: _kPurple,
                    onTap: () => setState(() {
                      _selectedTeamId = _teamBId;
                      _selectedPlayerId = null;
                      _selectedPlayerInId = null;
                      _selectedPlayerOutId = null;
                    }),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 18),

          // Player selector(s)
          if (_selectedTeamId != null) ...[
            if (_selectedEvent == 'Substitution') ...[
              _subLabel('Player Out'),
              const SizedBox(height: 8),
              _buildPlayerDropdown(
                value: _selectedPlayerOutId,
                players: playersForSelectedTeam,
                hint: 'Select player going off',
                onChanged: (v) =>
                    setState(() => _selectedPlayerOutId = v),
              ),
              const SizedBox(height: 14),
              _subLabel('Player In'),
              const SizedBox(height: 8),
              _buildPlayerDropdown(
                value: _selectedPlayerInId,
                players: playersForSelectedTeam,
                hint: 'Select player coming on',
                onChanged: (v) =>
                    setState(() => _selectedPlayerInId = v),
              ),
            ] else ...[
              _subLabel('Player'),
              const SizedBox(height: 8),
              _buildPlayerDropdown(
                value: _selectedPlayerId,
                players: playersForSelectedTeam,
                hint: 'Select player',
                onChanged: (v) =>
                    setState(() => _selectedPlayerId = v),
              ),
            ],
            const SizedBox(height: 20),
          ],

          // Record button
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (_recordingEvent || _selectedTeamId == null)
                      ? null
                      : _recordEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                disabledBackgroundColor:
                    AppColors.primaryColor.withOpacity(0.3),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              child: _recordingEvent
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            _eventOptions
                                .firstWhere(
                                    (e) => e.label == _selectedEvent,
                                    orElse: () => _eventOptions.first)
                                .icon,
                            size: 18),
                        const SizedBox(width: 10),
                        const Text('Record Event',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerDropdown({
    required String? value,
    required List<Map<String, dynamic>> players,
    required String hint,
    required void Function(String?) onChanged,
  }) {
    // Ensure value is valid in current player list
    final validValue = players.any((p) => p['id'] == value)
        ? value
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: validValue,
          isExpanded: true,
          dropdownColor: _kSurface2,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade500, size: 18),
          hint: Text(hint,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13)),
          items: players
              .map((p) => DropdownMenuItem<String>(
                    value: p['id'] as String,
                    child: Text(p['name'] as String),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── CONFIRM DIALOG (replaces AlertDialog) ──
  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required IconData icon,
    required Color iconColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child:
                        Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(message,
                  style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      height: 1.5)),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Center(
                            child: Text('Cancel',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: confirmColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: confirmColor.withOpacity(0.35)),
                        ),
                        child: Center(
                            child: Text(confirmLabel,
                                style: TextStyle(
                                    color: confirmColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600))),
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

  // ── UTILITY WIDGETS ──
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

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6)),
      ],
    );
  }

  Widget _subLabel(String label) {
    return Text(label,
        style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3));
  }
}

// ════════════════════════════════════════════════════════════════════
//   EVENT OPTION MODEL
// ════════════════════════════════════════════════════════════════════
class _EventOption {
  final String label;
  final IconData icon;
  final Color color;

  const _EventOption(this.label, this.icon, this.color);
}

// ════════════════════════════════════════════════════════════════════
//   EVENT CHIP
// ════════════════════════════════════════════════════════════════════
class _EventChip extends StatefulWidget {
  final _EventOption option;
  final bool isActive;
  final VoidCallback onTap;

  const _EventChip({
    required this.option,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_EventChip> createState() => _EventChipState();
}

class _EventChipState extends State<_EventChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.option.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isActive
                ? c.withOpacity(0.15)
                : _hovered
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isActive
                  ? c.withOpacity(0.45)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.option.icon,
                  size: 15,
                  color: widget.isActive
                      ? c
                      : Colors.grey.shade600),
              const SizedBox(width: 7),
              Text(widget.option.label,
                  style: TextStyle(
                      color: widget.isActive
                          ? c
                          : Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: widget.isActive
                          ? FontWeight.w600
                          : FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   TEAM TOGGLE BUTTON
// ════════════════════════════════════════════════════════════════════
class _TeamToggleBtn extends StatefulWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TeamToggleBtn({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  State<_TeamToggleBtn> createState() => _TeamToggleBtnState();
}

class _TeamToggleBtnState extends State<_TeamToggleBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.color.withOpacity(0.15)
                : _hovered
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: widget.isSelected
                  ? widget.color.withOpacity(0.4)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isSelected) ...[
                Icon(Icons.check_rounded,
                    size: 14, color: widget.color),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.isSelected
                        ? widget.color
                        : Colors.grey.shade500,
                    fontSize: 13,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}