import 'package:flutter/foundation.dart';

/// =======================
/// TEAM FEATURE VIEWS
/// =======================
/// Controls which Team screen is visible inside the dashboard body
enum TeamView {
  list,
  create,
  edit,
  details,
}

/// =======================
/// TEAM MODEL
/// =======================
class Team {
  final String id;
  final String name;
  final String abbr;
  final String? coachId;
  final String? logoUrl;
  final List<String> players; // ✅ Only player IDs
  final String? tmName;       // Nullable team manager name
  final String? tmPhone;      // Nullable team manager phone

  Team({
    required this.id,
    required this.name,
    required this.abbr,
    this.coachId,
    this.logoUrl,
    required this.players,
    this.tmName,
    this.tmPhone,
  });

  /// ✅ Convert Team object to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'abbr': abbr,
      'coachId': coachId,
      'logoUrl': logoUrl,
      'players': players,
      'tmName': tmName,
      'tmPhone': tmPhone,
    };
  }

  /// ✅ Create Team object from Firestore map + document ID
  factory Team.fromMap(Map<String, dynamic> map, String id) {
    return Team(
      id: id, // Always trust Firestore doc.id
      name: (map['name'] ?? '') as String,
      abbr: (map['abbr'] ?? '') as String,
      coachId: map['coachId'] as String?,
      logoUrl: map['logoUrl'] as String?,
      players: (map['players'] is List)
          ? List<String>.from(map['players'])
          : <String>[],
      tmName: map['tmName'] as String?,
      tmPhone: map['tmPhone'] as String?,
    );
  }

  Team copyWith({
    String? id,
    String? name,
    String? abbr,
    String? coachId,
    String? logoUrl,
    List<String>? players,
    String? tmName,
    String? tmPhone,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      abbr: abbr ?? this.abbr,
      coachId: coachId,
      logoUrl: logoUrl ?? this.logoUrl,
      players: players ?? this.players,
      tmName: tmName,
      tmPhone: tmPhone,
    );
  }
}
