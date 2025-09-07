class MatchModel {
  final String id;
  final String leagueId;
  final String group; // e.g. "A" or "B"
  final String homeTeamId;
  final String awayTeamId;
  final DateTime dateTime;
  final String location;
  final String status; // upcoming, live, finished
  final int homeScore;
  final int awayScore;

  MatchModel({
    required this.id,
    required this.leagueId,
    required this.group,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.dateTime,
    required this.location,
    required this.status,
    this.homeScore = 0,
    this.awayScore = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leagueId': leagueId,
      'group': group,
      'homeTeamId': homeTeamId,
      'awayTeamId': awayTeamId,
      'dateTime': dateTime.toIso8601String(),
      'location': location,
      'status': status,
      'homeScore': homeScore,
      'awayScore': awayScore,
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: map['id'],
      leagueId: map['leagueId'],
      group: map['group'],
      homeTeamId: map['homeTeamId'],
      awayTeamId: map['awayTeamId'],
      dateTime: DateTime.parse(map['dateTime']),
      location: map['location'],
      status: map['status'],
      homeScore: map['homeScore'] ?? 0,
      awayScore: map['awayScore'] ?? 0,
    );
  }
}