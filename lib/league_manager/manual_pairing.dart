// Manual pairing converter
// pairs: list of {'group': 'A', 'teams': ['team1','team2']}
List<Map<String, dynamic>> generateManualMatches({
  required List<Map<String, dynamic>> pairs,
}) {
  final matches = <Map<String, dynamic>>[];
  for (final p in pairs) {
    final group = p['group'] as String;
    final teams = List<String>.from(p['teams'] as List);
    if (teams.length != 2) continue; // caller should ensure exactly 2
    matches.add({
      'teamAId': teams[0],
      'teamBId': teams[1],
      'group': group,
    });
  }
  return matches;
}