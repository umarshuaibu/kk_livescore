import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player_model.dart';

class PlayerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'players';

  // Add a new player with auto-generated ID
  Future<void> addPlayer(Player player) async {
    try {
      final docRef = _firestore.collection(_collection).doc(); // Auto-generates ID
      final newPlayer = Player(
        id: docRef.id,
        name: player.name,
        position: player.position,
        jerseyNo: player.jerseyNo, // Ensure this is an int
        team: player.team,
        playerPhoto: player.playerPhoto,
        dateOfBirth: player.dateOfBirth, // include DOB
      );
      await docRef.set(newPlayer.toMap());
    } catch (e) {
      throw Exception('Failed to add player: $e');
    }
  }

  // Fetch all players with optional limit
  Future<List<Player>> fetchPlayers({int limit = 0}) async {
    try {
      QuerySnapshot snapshot = limit > 0
          ? await _firestore.collection(_collection).limit(limit).get()
          : await _firestore.collection(_collection).get();
      return snapshot.docs
          .map((doc) => Player.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch players: $e');
    }
  }

  // Delete a player by ID
  Future<void> deletePlayer(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete player: $e');
    }
  }

  // Edit a player by ID
  Future<void> editPlayer(String id, Player updatedPlayer) async {
    try {
      await _firestore.collection(_collection).doc(id).update(updatedPlayer.toMap());
    } catch (e) {
      throw Exception('Failed to edit player: $e');
    }
  }

  // Stream players
  Stream<List<Player>> streamPlayers() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Player.fromMap(doc.data()))
            .toList());
  }
}
