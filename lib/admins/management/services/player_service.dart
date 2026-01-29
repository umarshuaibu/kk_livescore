import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/admins/management/reusables/custom_dialog.dart';
import '../models/player_model.dart';

class PlayerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'players';
  final CollectionReference _playersCollection =
      FirebaseFirestore.instance.collection('players');

  // ✅ Add a new player with a consistent ID
  Future<Player> addPlayer(Player player) async {
    try {
      final docRef = _firestore.collection(_collection).doc(player.id);
      await docRef.set(player.toMap());
      return player; // Return the saved player with the same ID
    } catch (e) {
      throw Exception('Failed to add player: $e');
    }
  }


// ✅ Update player + handle team reassignment safely (PRODUCTION)
Future<void> updatePlayerWithTeam({
  required Player updatedPlayer,
  String? previousTeamId,
}) async {
  try {
    final batch = _firestore.batch();

    // Update player document
    final playerRef =
        _firestore.collection(_collection).doc(updatedPlayer.id);
    batch.update(playerRef, updatedPlayer.toMap());

    // Remove from old team if changed
    if (previousTeamId != null &&
        previousTeamId.isNotEmpty &&
        previousTeamId != updatedPlayer.teamId) {
      final oldTeamRef =
          _firestore.collection('teams').doc(previousTeamId);
      batch.update(oldTeamRef, {
        'players': FieldValue.arrayRemove([updatedPlayer.id]),
      });
    }

    // Add to new team if changed
    if (updatedPlayer.teamId != null &&
        updatedPlayer.teamId!.isNotEmpty &&
        previousTeamId != updatedPlayer.teamId) {
      final newTeamRef =
          _firestore.collection('teams').doc(updatedPlayer.teamId);
      batch.update(newTeamRef, {
        'players': FieldValue.arrayUnion([updatedPlayer.id]),
      });
    }

    await batch.commit();
  } catch (e) {
    throw Exception('Failed to update player with team: $e');
  }
}




  // ✅ Fetch all players with optional limit
  Future<List<Player>> fetchPlayers({int limit = 0}) async {
    try {
      QuerySnapshot snapshot = limit > 0
          ? await _firestore.collection(_collection).limit(limit).get()
          : await _firestore.collection(_collection).get();

      return snapshot.docs
          .map((doc) => Player.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch players: $e');
    }
  }

  // ✅ Delete a player by ID
  Future<void> deletePlayer(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete player: $e');
    }
  }

  // ✅ Edit a player by ID
  Future<void> editPlayer(String id, Player updatedPlayer) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update(updatedPlayer.toMap());
    } catch (e) {
      throw Exception('Failed to edit player: $e');
    }
  }

  // ✅ Stream players in real time
  Stream<List<Player>> streamPlayers() {
    return _firestore.collection(_collection).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Player.fromMap(
                    doc.data(),
                    doc.id,
                  ))
              .toList(),
        );
  }

  // ✅ Update player's team with teamId
  Future<void> updatePlayerTeam(String playerId, String? teamId) async {
    try {
      await _firestore.collection(_collection).doc(playerId).update({
        'team': teamId, // store teamId string
      });
    } catch (e) {
      throw Exception('Failed to update player team: $e');
    }
  }

// ✅ Fetch players by team
Future<List<Player>> fetchPlayersByTeam(String teamId) async {
  try {
    final teamRef = _firestore.collection('teams').doc(teamId);

    // Try string-id query first
    final snapString = await _firestore
        .collection(_collection)
        .where('team', isEqualTo: teamId) // team stored as string id
        .get();

    List<Player> players = snapString.docs
        .map((doc) => Player.fromMap(
              doc.data(),
              doc.id,
            ))
        .toList();

    // If none found, try DocumentReference query (in case team was stored as ref)
    if (players.isEmpty) {
      final snapRef = await _firestore
          .collection(_collection)
          .where('team', isEqualTo: teamRef) // team stored as reference
          .get();

      players = snapRef.docs
          .map((doc) => Player.fromMap(
                doc.data(),
                doc.id,
              ))
          .toList();
    }

    return players;
  } catch (e) {
    throw Exception('Failed to fetch players by team: $e');
  }
}


  // ✅ Fetch a single player by ID
  Future<Player?> fetchPlayerById(
      BuildContext context, String playerId) async {
    try {
      final doc = await _playersCollection.doc(playerId).get();
      if (doc.exists) {
        return Player.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        CustomDialog.show(
          context,
          title: 'Error',
          message: 'Failed to fetch player: $e',
          type: DialogType.error,
          confirmText: 'OK',
        );
      }
      return null;
    }
  }
}
