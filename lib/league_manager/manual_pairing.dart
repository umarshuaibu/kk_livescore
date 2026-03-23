// Manual pairing converter

/// Converts manual pairs into match-ready maps.
/// If [isKnockout] is true, group is ignored.
List<Map<String, dynamic>> generateManualMatches({
  required List<Map<String, dynamic>> pairs,
  bool isKnockout = false,
}) {
  final matches = <Map<String, dynamic>>[];

  for (final p in pairs) {
    final teams = List<String>.from(p['teams'] as List);
    if (teams.length != 2) continue; // caller should ensure exactly 2

    final matchMap = {
      'teamAId': teams[0],
      'teamBId': teams[1],
    };

    if (!isKnockout) {
      // Include group if not knockout
      matchMap['group'] = p['group'] as String? ?? '';
    }

    matches.add(matchMap);
  }

  return matches;
}

/// ------------------ NEW: Knockout Tournament GENERATOR ------------------
/// Generates remaining rounds for a knockout tournament.
/// Uses the initial manual pairs as first round.
/// Each subsequent round pairs winners of previous matches.
/// Returns a flat list of maps with teamAId, teamBId, and optional round.
List<Map<String, dynamic>> generateKnockoutRounds(List<Map<String, dynamic>> firstRoundPairs) {
  if (firstRoundPairs.isEmpty) return [];

  final allMatches = <Map<String, dynamic>>[];
  List<String> currentRoundTeams = [];

  // First round: flatten team IDs from manual pairs
  for (final pair in firstRoundPairs) {
    allMatches.add(pair); // add first round matches
    currentRoundTeams.add('WINNER(${pair['teamAId']} vs ${pair['teamBId']})');
  }

  int roundNumber = 2; // next round
  while (currentRoundTeams.length > 1) {
    final nextRound = <String>[];
    for (int i = 0; i < currentRoundTeams.length; i += 2) {
      final teamA = currentRoundTeams[i];
      String teamB;
      if (i + 1 < currentRoundTeams.length) {
        teamB = currentRoundTeams[i + 1];
      } else {
        // Odd team advances automatically
        nextRound.add(teamA);
        continue;
      }

      final match = {
        'teamAId': teamA,
        'teamBId': teamB,
        'round': roundNumber,
      };
      allMatches.add(match);
      nextRound.add('WINNER(${teamA} vs ${teamB})');
    }

    currentRoundTeams = nextRound;
    roundNumber++;
  }

  return allMatches;
}
