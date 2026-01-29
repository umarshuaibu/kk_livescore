import 'package:cloud_firestore/cloud_firestore.dart';

class StandingModel {
  final String teamId;
  final String leagueId;
  final String group;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final int points;
  final Timestamp? lastUpdated;

  StandingModel({
    required this.teamId,
    required this.leagueId,
    required this.group,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    required this.points,
    this.lastUpdated,
  });

  factory StandingModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return StandingModel(
      teamId: doc.id,
      leagueId: (d['leagueId'] ?? '').toString(),
      group: (d['group'] ?? 'default').toString(),
      played: (d['played'] ?? 0) as int,
      won: (d['won'] ?? 0) as int,
      drawn: (d['drawn'] ?? 0) as int,
      lost: (d['lost'] ?? 0) as int,
      goalsFor: (d['goalsFor'] ?? 0) as int,
      goalsAgainst: (d['goalsAgainst'] ?? 0) as int,
      goalDifference: (d['goalDifference'] ?? 0) as int,
      points: (d['points'] ?? 0) as int,
      lastUpdated: d['lastUpdated'] as Timestamp?,
    );
  }

  Map<String, dynamic> toJson() => {
        'leagueId': leagueId,
        'group': group,
        'played': played,
        'won': won,
        'drawn': drawn,
        'lost': lost,
        'goalsFor': goalsFor,
        'goalsAgainst': goalsAgainst,
        'goalDifference': goalDifference,
        'points': points,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

  StandingModel copyWith({
    int? played,
    int? won,
    int? drawn,
    int? lost,
    int? goalsFor,
    int? goalsAgainst,
    int? goalDifference,
    int? points,
    String? group,
  }) {
    return StandingModel(
      teamId: teamId,
      leagueId: leagueId,
      group: group ?? this.group,
      played: played ?? this.played,
      won: won ?? this.won,
      drawn: drawn ?? this.drawn,
      lost: lost ?? this.lost,
      goalsFor: goalsFor ?? this.goalsFor,
      goalsAgainst: goalsAgainst ?? this.goalsAgainst,
      goalDifference: goalDifference ?? this.goalDifference,
      points: points ?? this.points,
      lastUpdated: lastUpdated,
    );
  }
}