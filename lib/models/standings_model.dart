class StandingsModel {
  final String teamId;
  final String teamLogoUrl;
  final String teamName;
  final int points;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;

  StandingsModel({
    required this.teamId,
    required this.teamLogoUrl,
    required this.teamName,
    required this.points,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
  });

  int get goalDifference => goalsFor - goalsAgainst;

  factory StandingsModel.fromMap(Map<String, dynamic> map) {
    return StandingsModel(
      teamId: map['teamId'] ?? '',
      teamLogoUrl: map['teamLogoUrl'] ?? '',
      teamName: map['teamName'] ?? '',
      points: map['points'] ?? 0,
      played: map['played'] ?? 0,
      won: map['won'] ?? 0,
      drawn: map['drawn'] ?? 0,
      lost: map['lost'] ?? 0,
      goalsFor: map['goalsFor'] ?? 0,
      goalsAgainst: map['goalsAgainst'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teamId': teamId,
      'teamName': teamName,
      'teamLogoUrl': teamLogoUrl,
      'played': played,
      'won': won,
      'drawn': drawn,
      'lost': lost,
      'goalsFor': goalsFor,
      'goalsAgainst': goalsAgainst,
      'points': points,
    };
  }
}