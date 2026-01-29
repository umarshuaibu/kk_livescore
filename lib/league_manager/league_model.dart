// ignore_for_file: non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';

class League {
  final String? id; // Firestore document ID (nullable for create)
  final String name;
  final String season;
  final String logoUrl;

  /// ⚠️ Keep Firestore field names EXACT (case-sensitive)
  final String MatchesSystem;
  final String TeamsPairing;

  final int NumberOfTeams;
  final int NumberOfGroups;

  /// Stored like ["1|18:00", "2|16:00"]
  final List<String> MatchDays;

  final List<String> groupNames;

  League({
    this.id,
    required this.name,
    required this.season,
    required this.logoUrl,
    required this.MatchesSystem,
    required this.TeamsPairing,
    required this.NumberOfTeams,
    required this.NumberOfGroups,
    required this.MatchDays,
    required this.groupNames,
  });

  /// ✅ Convert League -> Firestore map (WRITE)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'season': season,
      'logoUrl': logoUrl,
      'MatchesSystem': MatchesSystem,
      'TeamsPairing': TeamsPairing,
      'NumberOfTeams': NumberOfTeams,
      'NumberOfGroups': NumberOfGroups,
      'MatchDays': MatchDays,
      'groupNames': groupNames,
    };
  }

  /// ✅ Alias (optional, does NOT break anything)
  Map<String, dynamic> toMap() => toJson();

  /// ✅ Create League from Firestore document (READ)
  factory League.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return League(
      id: doc.id,
      name: data['name'] ?? '',
      season: data['season'] ?? '',
      logoUrl: data['logoUrl'] ?? '',
      MatchesSystem: data['MatchesSystem'] ?? '',
      TeamsPairing: data['TeamsPairing'] ?? '',
      NumberOfTeams: (data['NumberOfTeams'] ?? 0) as int,
      NumberOfGroups: (data['NumberOfGroups'] ?? 0) as int,
      MatchDays: data['MatchDays'] is List
          ? List<String>.from(data['MatchDays'])
          : <String>[],
      groupNames: data['groupNames'] is List
          ? List<String>.from(data['groupNames'])
          : <String>[],
    );
  }

  /// ✅ Useful for edit screens (non-breaking)
  League copyWith({
    String? id,
    String? name,
    String? season,
    String? logoUrl,
    String? MatchesSystem,
    String? TeamsPairing,
    int? NumberOfTeams,
    int? NumberOfGroups,
    List<String>? MatchDays,
    List<String>? groupNames,
  }) {
    return League(
      id: id ?? this.id,
      name: name ?? this.name,
      season: season ?? this.season,
      logoUrl: logoUrl ?? this.logoUrl,
      MatchesSystem: MatchesSystem ?? this.MatchesSystem,
      TeamsPairing: TeamsPairing ?? this.TeamsPairing,
      NumberOfTeams: NumberOfTeams ?? this.NumberOfTeams,
      NumberOfGroups: NumberOfGroups ?? this.NumberOfGroups,
      MatchDays: MatchDays ?? this.MatchDays,
      groupNames: groupNames ?? this.groupNames,
    );
  }
}
