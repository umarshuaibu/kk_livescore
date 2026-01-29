class MatchModel {
  final String id;
  final String leagueId;
  final String groupId;
  final String homeTeamId;
  final String awayTeamId;
  final DateTime date;
  final String time;
  final int? homeScore; // nullable
  final int? awayScore; // nullable

  MatchModel({
    required this.id,
    required this.leagueId,
    required this.groupId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.date,
    required this.time,
    this.homeScore, // optional
    this.awayScore, // optional
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leagueId': leagueId,
      'groupId': groupId,
      'homeTeamId': homeTeamId,
      'awayTeamId': awayTeamId,
      'date': date.toIso8601String(),
      'time': time,
      'homeScore': homeScore,
      'awayScore': awayScore,
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: map['id'],
      leagueId: map['leagueId'],
      groupId: map['groupId'],
      homeTeamId: map['homeTeamId'],
      awayTeamId: map['awayTeamId'],
      date: DateTime.parse(map['date']),
      time: map['time'],
      homeScore: map['homeScore'], // null if not set
      awayScore: map['awayScore'],
    );
  }
}
