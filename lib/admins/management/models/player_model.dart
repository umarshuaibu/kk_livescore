import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// =======================
/// PLAYER FEATURE VIEWS
/// =======================
/// Controls which Player screen is visible inside the dashboard body
enum PlayerView {
  list,
  create,
  edit,
  details,
}

/// =======================
/// PLAYER MODEL
/// =======================
class Player {
  final String id; // Firestore document ID
  final String name;
  final String position;
  final int jerseyNo;
  final String? team;   // Nullable because a player might not belong to a team
  final String? teamId; // Nullable because a player might not belong to a team
  final String playerPhoto;
  final DateTime dateOfBirth;
  final String state;
  final String town;

  Player({
    required this.id,
    required this.name,
    required this.position,
    required this.jerseyNo,
    this.team,
    this.teamId,
    required this.playerPhoto,
    required this.dateOfBirth,
    required this.state,
    required this.town,
  });

  Player copyWith({
  String? id,
  String? name,
  String? position,
  int? jerseyNo,
  String? team,
  String? teamId,
  String? playerPhoto,
  DateTime? dateOfBirth,
  String? state,
  String? town,
}) {
  return Player(
    id: id ?? this.id,
    name: name ?? this.name,
    position: position ?? this.position,
    jerseyNo: jerseyNo ?? this.jerseyNo,
    team: team ?? this.team,
    teamId: teamId ?? this.teamId,
    playerPhoto: playerPhoto ?? this.playerPhoto,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    state: state ?? this.state,
    town: town ?? this.town,
  );
}


  /// Factory constructor: create Player from Firestore data + docId
  factory Player.fromMap(Map<String, dynamic> map, String id) {
    return Player(
      id: id, // Firestore document ID
      name: map['name'] ?? '',
      position: map['position'] ?? '',
      jerseyNo: (map['jerseyNo'] ?? 0) as int,
      team: map['team'],     // Nullable
      teamId: map['teamId'], // Nullable
      playerPhoto: map['playerPhoto'] ?? '',
      dateOfBirth: map['dateOfBirth'] != null
          ? DateTime.parse(map['dateOfBirth'])
          : DateTime(2000), // fallback default
      state: map['state'] ?? '',
      town: map['town'] ?? '',
    );
  }

  /// Convert Player object into Firestore-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'jerseyNo': jerseyNo,
      'team': team,
      'teamId': teamId,
      'playerPhoto': playerPhoto,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'state': state,
      'town': town,
    };
  }

  factory Player.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;

  return Player(
    id: doc.id,
    name: data['name'] ?? '',
    jerseyNo: data['jerseyNo'] ?? 0,
    position: data['position'] ?? '',
    teamId: data['teamId'],
    team: data['team'],
    state: data['state'] ?? '',
    town: data['town'] ?? '',
    playerPhoto: data['playerPhoto'] ?? '',
    dateOfBirth: (data['dateOfBirth'] as Timestamp).toDate(),
  );
}

}
