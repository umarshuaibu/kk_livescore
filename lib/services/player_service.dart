import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player_model.dart';

class PlayerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'players';

  // Add a new player
  Future<void> addPlayer(Player player) async {
    await _firestore.collection(_collection).doc(player.id).set(player.toMap());
  }

  // Fetch all players
  Future<List<Player>> fetchPlayers() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.map((doc) => Player.fromMap(doc.data())).toList();
  }

  // Delete a player by ID
  Future<void> deletePlayer(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  // Edit a player by ID
  Future<void> editPlayer(String id, Player updatedPlayer) async {
    await _firestore.collection(_collection).doc(id).update(updatedPlayer.toMap());
  }
}