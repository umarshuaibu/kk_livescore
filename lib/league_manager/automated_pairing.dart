import 'match_system.dart';

// Returns list of match pairs per group based on MatchesSystem.
// groupsMap: groupName -> list of teamIds
List<Map<String, dynamic>> generateAutomatedMatches({
  required Map<String, List<String>> groupsMap,
  required String MatchesSystem, // "Home_and_away" or "Away_only"
}) {
  final List<Map<String, dynamic>> matches = [];

  for (final entry in groupsMap.entries) {
    final group = entry.key;
    final teams = entry.value;
    List<List<String>> pairs;
    if (MatchesSystem == 'Home_and_away') {
      pairs = doubleRoundRobin(teams);
    } else {
      // Away_only => single round robin
      pairs = singleRoundRobin(teams);
    }

    for (var i = 0; i < pairs.length; i++) {
      final pair = pairs[i];
      matches.add({
        'teamAId': pair[0],
        'teamBId': pair[1],
        'group': group,
      });
    }
  }

  return matches;
}