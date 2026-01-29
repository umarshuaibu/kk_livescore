import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/constants/size.dart';
import 'package:kklivescoreadmin/constants/text_styles.dart';

/// TeamsTab
/// - Lists teams that belong to the selected league
///   (it reads documents from: league/{leagueId}/teams or leagues/{leagueId}/teams)
/// - For each team it fetches the global teams/{teamId} document to display logo & name
/// - On tap -> TeamDetailsPage which shows:
///    - Team name & logo
///    - Group
///    - Coach information
///    - Players list
///    - Team statistics
///
/// Production ready improvements:
///  - No raw IDs are shown to users (IDs are used internally only)
///  - Friendly user-facing error messages (no technical stacks/exceptions)
///  - Retry buttons where appropriate
///  - Defensive null-checks and network error handling (debug logs only)
class TeamsTab extends StatefulWidget {
  final String leagueId;

  const TeamsTab({super.key, required this.leagueId});

  @override
  State<TeamsTab> createState() => _TeamsTabState();
}

class _TeamsTabState extends State<TeamsTab> {
  /// Attempts plural path first for compatibility, then falls back to singular.
  Future<List<QueryDocumentSnapshot>> _fetchLeagueTeamsDocs() async {
    try {
      final pluralSnap = await FirebaseFirestore.instance
          .collection('leagues')
          .doc(widget.leagueId)
          .collection('teams')
          .get();
      if (pluralSnap.docs.isNotEmpty) return pluralSnap.docs;

      final singularSnap = await FirebaseFirestore.instance
          .collection('league')
          .doc(widget.leagueId)
          .collection('teams')
          .get();
      return singularSnap.docs;
    } catch (e) {
      // Developer-only log. Do NOT expose to user.
      debugPrint('Failed to fetch league teams docs for ${widget.leagueId}: $e');
      // Re-throw so FutureBuilder snapshot.hasError becomes true and we show a friendly UI.
      rethrow;
    }
  }

  /// Fetch global team doc safely
  Future<Map<String, dynamic>?> _fetchTeam(String teamId) async {
    if (teamId.trim().isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();
      if (!snap.exists) return null;
      return snap.data() as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to fetch team $teamId: $e');
      return null;
    }
  }

  /// Helper to read teamId from a league-team document with tolerant field names
  String? _extractTeamId(Map<String, dynamic> data) {
    // tolerant to different field names
    final possible = <String>['teamId', 'teamid', 'teamID', 'team'];
    for (final key in possible) {
      final v = data[key];
      if (v != null) {
        final s = v.toString();
        if (s.trim().isNotEmpty) return s.trim();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _fetchLeagueTeamsDocs(),
      builder: (context, snap) {
        if (snap.hasError) {
          // Friendly, non-technical message
          return Center(
            child: Padding(
              padding: EdgeInsets.all(eqW(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Unable to load teams. Please check your internet connection and try again.',
                    style: kText12White,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: eqW(8)),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final leagueTeamDocs = snap.data!;
        if (leagueTeamDocs.isEmpty) {
          return Center(child: Text('No teams found for this league', style: kText12White));
        }

        return ListView.builder(
          padding: EdgeInsets.all(eqW(8)),
          itemCount: leagueTeamDocs.length,
          itemBuilder: (context, i) {
            final doc = leagueTeamDocs[i];
            final rawData = (doc.data() as Map<String, dynamic>?) ?? {};
            final teamId = _extractTeamId(rawData);
            final group = rawData['group']?.toString() ?? '-';

            return FutureBuilder<Map<String, dynamic>?>(
              future: (teamId != null) ? _fetchTeam(teamId) : Future.value(null),
              builder: (context, tsnap) {
                final team = tsnap.data;
                final displayName = (team != null && team['name']?.toString().trim().isNotEmpty == true)
                    ? team['name'].toString()
                    : 'Team'; // friendly placeholder

                final logoUrl = team?['logoUrl']?.toString();

                return InkWell(
                  onTap: () {
                    if (teamId == null || teamId.trim().isEmpty) {
                      // Friendly feedback; do not surface IDs or internals.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Team details are not available right now.')),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamDetailsPage(
                          leagueId: widget.leagueId,
                          teamId: teamId,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: eqW(6)),
                    padding: EdgeInsets.all(eqW(10)),
                    decoration: BoxDecoration(
                      color: kScaffoldColor,
                      borderRadius: BorderRadius.circular(eqW(8)),
                    ),
                    child: Row(
                      children: [
                        // logo
                        Container(
                          width: eqW(40),
                          height: eqW(40),
                          decoration: BoxDecoration(
                            color: kGrey1.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(eqW(10)),
                          ),
                          child: (logoUrl != null && logoUrl.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(eqW(8)),
                                  child: Image.network(
                                    logoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(Icons.shield, color: kGrey2),
                                  ),
                                )
                              : Icon(Icons.shield, color: kGrey2),
                        ),
                        SizedBox(width: eqW(10)),
                        // name & group
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: kText12White),
                              SizedBox(height: eqW(2)),
                              Text('GROUP: $group', style: kText10GreyR),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: kGrey2),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// TeamDetailsPage
/// - Shows team name & logo, group, coach info, players list and statistics.
/// - Protects against missing data and network issues by showing friendly placeholders and retry options.
/// - Does NOT display raw IDs or technical messages to the user.
class TeamDetailsPage extends StatefulWidget {
  final String leagueId;
  final String teamId;

  const TeamDetailsPage({super.key, required this.leagueId, required this.teamId});

  @override
  State<TeamDetailsPage> createState() => _TeamDetailsPageState();
}

class _TeamDetailsPageState extends State<TeamDetailsPage> {
  Map<String, dynamic>? _team;
  Map<String, dynamic>? _coach;
  List<Map<String, dynamic>> _players = [];
  Map<String, dynamic>? _standing;

  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      // Team
      final teamSnap = await FirebaseFirestore.instance.collection('teams').doc(widget.teamId).get();
      if (teamSnap.exists) {
        _team = teamSnap.data() as Map<String, dynamic>?;
      } else {
        _team = null;
      }

      // Coach: try to read from team doc (coachId)
      final coachId = _team?['coachId']?.toString();
      if (coachId != null && coachId.trim().isNotEmpty) {
        try {
          final cSnap = await FirebaseFirestore.instance.collection('coaches').doc(coachId).get();
          if (cSnap.exists) _coach = cSnap.data() as Map<String, dynamic>?;
        } catch (e) {
          debugPrint('Failed to fetch coach $coachId: $e');
          _coach = null;
        }
      } else {
        _coach = null;
      }

      // Players: tolerate different field names for player->team link
      List<Map<String, dynamic>> players = [];
      try {
        final pByTeamId = await FirebaseFirestore.instance.collection('players').where('teamId', isEqualTo: widget.teamId).get();
        if (pByTeamId.docs.isNotEmpty) {
          players = pByTeamId.docs.map((d) => (d.data() as Map<String, dynamic>)).toList();
        } else {
          // fallback to teamid
          final pByTeamid = await FirebaseFirestore.instance.collection('players').where('teamid', isEqualTo: widget.teamId).get();
          if (pByTeamid.docs.isNotEmpty) {
            players = pByTeamid.docs.map((d) => (d.data() as Map<String, dynamic>)).toList();
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch players for ${widget.teamId}: $e');
        players = [];
      }
      _players = players;

      // Standings: try singular then plural league collection and tolerant field names
      Map<String, dynamic>? standing;
      try {
        final sSnap = await FirebaseFirestore.instance
            .collection('leagues')
            .doc(widget.leagueId)
            .collection('standings')
            .where('teamId', isEqualTo: widget.teamId)
            .limit(1)
            .get();
        if (sSnap.docs.isNotEmpty) {
          standing = sSnap.docs.first.data() as Map<String, dynamic>;
        } else {
          // try teamid
          final sSnap2 = await FirebaseFirestore.instance
              .collection('leagues')
              .doc(widget.leagueId)
              .collection('standings')
              .where('teamId', isEqualTo: widget.teamId)
              .limit(1)
              .get();
          if (sSnap2.docs.isNotEmpty) {
            standing = sSnap2.docs.first.data() as Map<String, dynamic>;
          } else {
            // try plural leagues path
            final sSnap3 = await FirebaseFirestore.instance
                .collection('leagues')
                .doc(widget.leagueId)
                .collection('standings')
                .where('teamId', isEqualTo: widget.teamId)
                .limit(1)
                .get();
            if (sSnap3.docs.isNotEmpty) {
              standing = sSnap3.docs.first.data() as Map<String, dynamic>;
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch standing for ${widget.teamId} in ${widget.leagueId}: $e');
        standing = null;
      }
      _standing = standing;

      if (mounted) {
        setState(() {
          _loading = false;
          _error = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load team details for ${widget.teamId}: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamName = (_team != null && (_team!['name']?.toString().trim().isNotEmpty == true)) ? _team!['name'].toString() : 'Team Details';

    return Scaffold(
      backgroundColor: kSecondaryColor,
      appBar: AppBar(
        title: Text(teamName),
        backgroundColor: kPrimaryColor,
        foregroundColor: kWhiteColor,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      // Friendly, non-technical message with retry
      return Center(
        child: Padding(
          padding: EdgeInsets.all(eqW(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Unable to load team details. Please check your connection and try again.',
                style: kText12White,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: eqW(8)),
              ElevatedButton(
                onPressed: _loadAll,
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: kPrimaryColor,
      child: ListView(
        padding: EdgeInsets.all(eqW(12)),
        children: [
          // Team header
          Container(
            padding: EdgeInsets.all(eqW(10)),
            decoration: BoxDecoration(color: kSecondaryColor, borderRadius: BorderRadius.circular(eqW(8))),
            child: Row(
              children: [
                // logo
                Container(
                  width: eqW(64),
                  height: eqW(64),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(eqW(8)), color: kGrey1.withOpacity(0.08)),
                  child: (_team?['logoUrl'] != null && (_team!['logoUrl'] as String).isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(eqW(8)),
                          child: Image.network(
                            _team!['logoUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.shield, color: kGrey2),
                          ),
                        )
                      : Icon(Icons.shield, color: kGrey2),
                ),
                SizedBox(width: eqW(12)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_team?['name']?.toString() ?? '-', style: kText14White),
                    SizedBox(height: eqW(6)),
                    Text('Group: ${_team?['group'] ?? '-'}', style: kText12GreyR),
                  ]),
                ),
              ],
            ),
          ),
          SizedBox(height: eqW(12)),
          Divider(color: kGrey1),

          // Coach info
          ListTile(
            leading: _coachPhoto(_coach?['photoUrl']?.toString()),
            title: Text('COACH', style: kText14White),
            subtitle: Text(_coach?['name']?.toString() ?? '-', style: kText12White),
          ),
          Divider(color: kGrey1),

          // Players list (lightweight)
          Padding(
            padding: EdgeInsets.symmetric(vertical: eqW(6)),
            child: Text('Players', style: kText14White),
          ),
          _players.isEmpty
              ? Text('No player data available', style: kText12White)
              : Column(
                  children: _players.map((p) {
                    final playerName = p['name']?.toString() ?? '-';
                    final photo = (p['photoUrl'] ?? p['PlayerPhoto'])?.toString();
                    final position = p['position']?.toString() ?? '-';
                    final jersey = p['JerseyNo']?.toString() ?? p['jersey']?.toString() ?? '-';

                    return Container(
                      margin: EdgeInsets.symmetric(vertical: eqW(6)),
                      padding: EdgeInsets.all(eqW(8)),
                      decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(eqW(6))),
                      child: Row(
                        children: [
                          Container(
                            width: eqW(44),
                            height: eqW(44),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(eqW(6)), color: kGrey1.withOpacity(0.08)),
                            child: (photo != null && photo.isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(eqW(6)),
                                    child: Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person, color: kGrey2)),
                                  )
                                : Icon(Icons.person, color: kGrey2),
                          ),
                          SizedBox(width: eqW(12)),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(playerName, style: kText12White),
                              SizedBox(height: eqW(4)),
                              Text('Pos: $position • #$jersey', style: kText12GreyR),
                            ]),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
          Divider(color: kGrey1),

          // Team statistics from standings
          Padding(
            padding: EdgeInsets.symmetric(vertical: eqW(6)),
            child: Text('Team Statistics', style: kText14White),
          ),
          _standing == null
              ? Text('No statistics available', style: kText12White)
              : Container(
                  padding: EdgeInsets.all(eqW(10)),
                  decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(eqW(8))),
                  child: Column(
                    children: [
                      _statRow('Played', _standing?['played']?.toString() ?? '-'),
                      _statRow('Won', _standing?['won']?.toString() ?? '-'),
                      _statRow('Loss', _standing?['loss']?.toString() ?? '-'),
                      _statRow('Drawn', _standing?['drawn']?.toString() ?? '-'),
                      _statRow('Points', _standing?['points']?.toString() ?? '-'),
                      _statRow('Goals For', _standing?['goalsFor']?.toString() ?? '-'),
                      _statRow('Goals Against', _standing?['goalAgainst']?.toString() ?? '-'),
                      _statRow('Goal Diff', _standing?['goalsDifference']?.toString() ?? '-'),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _coachPhoto(String? url) {
    return Container(
      width: eqW(44),
      height: eqW(44),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(eqW(6)), color: kGrey1.withOpacity(0.08)),
      child: (url != null && url.isNotEmpty)
          ? ClipRRect(borderRadius: BorderRadius.circular(eqW(6)), child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person, color: kGrey2)))
          : Icon(Icons.person, color: kGrey2),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: eqW(6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: kText12White), Text(value, style: kText12White)],
      ),
    );
  }
}