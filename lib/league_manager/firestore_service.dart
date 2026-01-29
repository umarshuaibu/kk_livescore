import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch all leagues (top-level collection 'leagues')
  Future<List<QueryDocumentSnapshot>> fetchLeagues() async {
    final snap = await _firestore.collection('leagues').get();
    return snap.docs;
  }

  /// Create a league document under 'leagues/{leagueId}'
  /// leagueData should contain the exact fields required by the system.
  Future<DocumentReference> createLeague(Map<String, dynamic> leagueData) async {
    final ref = await _firestore.collection('leagues').add(leagueData);
    return ref;
  }

        /// Fetch all leagues (top-level collection 'leagues')
  Future<List<QueryDocumentSnapshot>> getAllLeagues() async {
    final snap = await _firestore.collection('leagues').get();
    return snap.docs;
  }

  /// Read a single league document
  Future<DocumentSnapshot> getLeague(String leagueId) async {
    return await _firestore.collection('leagues').doc(leagueId).get();
  }

  /// Update league document fields (e.g., status)
  Future<void> updateLeague(String leagueId, Map<String, dynamic> data) async {
    await _firestore.collection('leagues').doc(leagueId).update(data);
  }

  /// Create a team document under 'leagues/{leagueId}/teams/{teamId}'
  /// Fields written must be: teamId, group, leagueId
  Future<void> createLeagueTeam({
    required String leagueId,
    required String teamId,
    required String group,
  }) async {
    final docRef = _firestore.collection('leagues').doc(leagueId).collection('teams').doc(teamId);
    await docRef.set({
      'teamId': teamId,
      'group': group,
      'leagueId': leagueId,
    });
  }

  /// Alias kept for backward compatibility with earlier code
  Future<void> createTeam({
    required String leagueId,
    required String teamId,
    required String group,
  }) async {
    return createLeagueTeam(leagueId: leagueId, teamId: teamId, group: group);
  }

  /// Fetch teams under a league: 'leagues/{leagueId}/teams'
  Future<List<QueryDocumentSnapshot>> fetchLeagueTeams(String leagueId) async {
    final snap = await _firestore.collection('leagues').doc(leagueId).collection('teams').get();
    return snap.docs;
  }

  /// Fetch top-level available teams from 'teams' collection
  /// Expected team document fields in top-level collection: teamId (optional), name (optional)
  Future<List<QueryDocumentSnapshot>> fetchAvailableTeams() async {
    final snap = await _firestore.collection('teams').get();
    return snap.docs;
  }

  /// Create a match under 'leagues/{leagueId}/matches/{matchId}'
  /// Fields must match schema: id, teamAId, teamBId, status, group, leagueId, date
  Future<void> createMatch({
    required String leagueId,
    required String matchId,
    required Map<String, dynamic> matchData,
  }) async {
    final docRef =
        _firestore.collection('leagues').doc(leagueId).collection('matches').doc(matchId);
    await docRef.set(matchData);
  }

  /// Fetch matches under a league: 'leagues/{leagueId}/matches'
  Future<List<QueryDocumentSnapshot>> fetchMatches(String leagueId) async {
    final snap = await _firestore.collection('leagues').doc(leagueId).collection('matches').get();
    return snap.docs;
  }

  /// Create a standings entry under 'leagues/{leagueId}/standings/{teamId}'
  /// Fields must match schema: teamId, leagueId, group, played, won, drawn, lost,
  /// goalsFor, goalsAgainst, goalDifference, points, lastUpdated
  Future<void> createStanding({
    required String leagueId,
    required String teamId,
    required Map<String, dynamic> standingData,
  }) async {
    final docRef =
        _firestore.collection('leagues').doc(leagueId).collection('standings').doc(teamId);
    await docRef.set(standingData);
  }

  /// Fetch standings under a league: 'leagues/{leagueId}/standings'
  Future<List<QueryDocumentSnapshot>> fetchStandings(String leagueId) async {
    final snap =
        await _firestore.collection('leagues').doc(leagueId).collection('standings').get();
    return snap.docs;
  }

  /// Check if a league exists
  Future<bool> leagueExists(String leagueId) async {
    final doc = await _firestore.collection('leagues').doc(leagueId).get();
    return doc.exists;
  }
}