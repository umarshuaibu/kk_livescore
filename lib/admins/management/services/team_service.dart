import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_model.dart';

class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _teamsCollection =
      FirebaseFirestore.instance.collection('teams');

  // ✅ Add a new team and return its Document ID
  Future<String> addTeam(Team team) async {
    try {
      final docRef = _teamsCollection.doc(); // Auto-generate ID

      final newTeam = Team(
        id: docRef.id,
        name: team.name,
        abbr: team.abbr,
        coachId: team.coachId,
        logoUrl: team.logoUrl,
        players: team.players,

        // ✅ NEW: Team Manager fields
        tmName: team.tmName,
        tmPhone: team.tmPhone,
      );

      await docRef.set(newTeam.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add team: $e');
    }
  }

  // ✅ Fetch all teams with optional limit
  Future<List<Team>> fetchTeams({int limit = 0}) async {
    try {
      final QuerySnapshot snapshot = limit > 0
          ? await _teamsCollection.limit(limit).get()
          : await _teamsCollection.get();

      return snapshot.docs
          .map((doc) =>
              Team.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch teams: $e');
    }
  }

  // ✅ Fetch a single team by ID
  Future<Team?> fetchTeamById(String teamId) async {
    try {
      final doc = await _teamsCollection.doc(teamId).get();
      if (!doc.exists) return null;

      return Team.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      throw Exception('Failed to fetch team: $e');
    }
  }

  // ✅ Delete a team (with full cleanup & safety)
Future<void> deleteTeam(String id) async {
  try {
    // Step 1: Fetch the team
    final teamRef = _teamsCollection.doc(id);
    final teamDoc = await teamRef.get();

    if (!teamDoc.exists) {
      throw Exception('Team not found');
    }

    final teamData = teamDoc.data() as Map<String, dynamic>;
    final String? coachId = teamData['coachId'];

    // Step 2: Unassign players
    final playersSnapshot = await _firestore
        .collection('players')
        .where('teamId', isEqualTo: id)
        .get();

    if (playersSnapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();

      for (final doc in playersSnapshot.docs) {
        batch.update(doc.reference, {
          'teamId': null,
          'team': null,
        });
      }

      await batch.commit();
    }

    // Step 3: Unassign coach (SAFE)
    if (coachId != null && coachId.isNotEmpty) {
      final coachRef = _firestore.collection('coaches').doc(coachId);
      final coachDoc = await coachRef.get();

      if (coachDoc.exists) {
        await coachRef.update({
          'teamId': null,
          'teamName': null,
        });
      }
      // ❗ If coach doesn't exist → ignore safely
    }

    // Step 4: Delete team
    await teamRef.delete();
  } catch (e) {
    throw Exception('Failed to delete team: $e');
  }
}

  // ✅ Edit a team (full replace)
  Future<void> editTeam(String id, Team updatedTeam) async {
    try {
      await _teamsCollection.doc(id).update(updatedTeam.toMap());
    } catch (e) {
      throw Exception('Failed to edit team: $e');
    }
  }

  // ✅ Stream teams
  Stream<List<Team>> streamTeams() {
    return _teamsCollection.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) =>
                  Team.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList(),
        );
  }

  // ✅ Fetch teams by league
  Future<List<Team>> fetchTeamsByLeague(String leagueId) async {
    try {
      final snapshot = await _teamsCollection
          .where('leagueId', isEqualTo: leagueId)
          .get();

      return snapshot.docs
          .map((doc) =>
              Team.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception(
          'Failed to fetch teams for league $leagueId: $e');
    }
  }

  // ✅ Assign coach to team
  Future<void> assignCoachToTeam(
    String teamId,
    String coachId,
    String coachName,
  ) async {
    try {
      await _teamsCollection.doc(teamId).update({
        'coachId': coachId,
        'coachName': coachName,
      });

      final teamSnap = await _teamsCollection.doc(teamId).get();

      await _firestore.collection('coaches').doc(coachId).update({
        'teamId': teamId,
        'teamName': teamSnap.get('name'),
      });
    } catch (e) {
      throw Exception('Failed to assign coach: $e');
    }
  }

  // ✅ Remove team and its standing (batch)
  Future<void> removeTeamAndStanding(
    String teamId,
    String leagueId,
  ) async {
    final batch = _firestore.batch();

    // delete team
    final teamDoc = _teamsCollection.doc(teamId);
    batch.delete(teamDoc);

    // delete its standing
    final standingQuery = await _firestore
        .collection('standings')
        .where('leagueId', isEqualTo: leagueId)
        .where('teamId', isEqualTo: teamId)
        .get();

    for (final doc in standingQuery.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ✅ Partial update (safe for tmName & tmPhone)
  Future<void> updateTeam(
    String teamId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _teamsCollection.doc(teamId).update(data);
    } catch (e) {
      throw Exception('Failed to update team: $e');
    }
  }
}
