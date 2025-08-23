import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/team_model.dart';

class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'teams';

  // Add a new team with auto-generated ID
  Future<void> addTeam(Team team) async {
    try {
      final docRef = _firestore.collection(_collection).doc(); // Auto-generates ID
      final newTeam = Team(
        id: docRef.id,
        name: team.name,
        abbr: team.abbr,
        coachId: team.coachId,
        logoUrl: team.logoUrl,
        players: team.players,
      );
      await docRef.set(newTeam.toMap());
    } catch (e) {
      throw Exception('Failed to add team: $e');
    }
  }

  // Fetch all teams with optional limit
  Future<List<Team>> fetchTeams({int limit = 0}) async {
    try {
      QuerySnapshot snapshot = limit > 0
          ? await _firestore.collection(_collection).limit(limit).get()
          : await _firestore.collection(_collection).get();
      return snapshot.docs
          .map((doc) => Team.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch teams: $e');
    }
  }

  // Delete a team by ID
  Future<void> deleteTeam(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete team: $e');
    }
  }

  // Edit a team by ID
  Future<void> editTeam(String id, Team updatedTeam) async {
    try {
      await _firestore.collection(_collection).doc(id).update(updatedTeam.toMap());
    } catch (e) {
      throw Exception('Failed to edit team: $e');
    }
  }

  // Stream teams
  Stream<List<Team>> streamTeams() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Team.fromMap(doc.data()))
            .toList());
  }
}