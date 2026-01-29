class Standing {
  final String id;
  final String leagueId;
  final String teamId;
  final String teamName;
  final String teamLogo;

  int points;
  int played;
  int wins;
  int draws;
  int losses;
  int goalsScored;
  int goalsAgainst;

  Standing({
    required this.id,
    required this.leagueId,
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    this.points = 0,
    this.played = 0,
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.goalsScored = 0,
    this.goalsAgainst = 0,
  });

  int get goalDifference => goalsScored - goalsAgainst;

  Map<String, dynamic> toMap() {
    return {
      'leagueId': leagueId,
      'teamId': teamId,
      'teamName': teamName,
      'teamLogo': teamLogo,
      'points': points,
      'played': played,
      'wins': wins,
      'draws': draws,
      'losses': losses,
      'goalsScored': goalsScored,
      'goalsAgainst': goalsAgainst,
      'goalDifference': goalDifference,
    };
  }

  factory Standing.fromMap(Map<String, dynamic> map, String docId) {
    return Standing(
      id: docId,
      leagueId: map['leagueId'] ?? '',
      teamId: map['teamId'] ?? '',
      teamName: map['teamName'] ?? '',
      teamLogo: map['teamLogo'] ?? '',
      points: map['points'] ?? 0,
      played: map['played'] ?? 0,
      wins: map['wins'] ?? 0,
      draws: map['draws'] ?? 0,
      losses: map['losses'] ?? 0,
      goalsScored: map['goalsScored'] ?? 0,
      goalsAgainst: map['goalsAgainst'] ?? 0,
    );
  }

  /// ✅ Reset standing stats (useful when re-initializing league)
  void reset() {
    points = 0;
    played = 0;
    wins = 0;
    draws = 0;
    losses = 0;
    goalsScored = 0;
    goalsAgainst = 0;
  }

  /// ✅ Apply a match result to this standing
  void applyMatchResult({
    required int teamGoals,
    required int opponentGoals,
  }) {
    played += 1;
    goalsScored += teamGoals;
    goalsAgainst += opponentGoals;

    if (teamGoals > opponentGoals) {
      wins += 1;
      points += 3;
    } else if (teamGoals == opponentGoals) {
      draws += 1;
      points += 1;
    } else {
      losses += 1;
    }
  }

  /// ✅ Rollback a match result (useful if a match is deleted/edited)
  void rollbackMatchResult({
    required int teamGoals,
    required int opponentGoals,
  }) {
    if (played > 0) played -= 1;
    goalsScored -= teamGoals;
    goalsAgainst -= opponentGoals;

    if (teamGoals > opponentGoals) {
      wins -= 1;
      points -= 3;
    } else if (teamGoals == opponentGoals) {
      draws -= 1;
      points -= 1;
    } else {
      losses -= 1;
    }
  }
}
