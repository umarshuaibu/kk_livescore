// Helpers to generate round-robin pairings

import 'package:kklivescoreadmin/league_manager/league_initialization_screen.dart';
import 'package:kklivescoreadmin/league_manager/manual_pairing.dart';

List<List<String>> singleRoundRobin(List<String> teams) {
  // Standard circle method
  final n = teams.length;
  if (n < 2) return [];
  final List<String> list = List.from(teams);
  final bool hasBye = n % 2 == 1;
  if (hasBye) {
    list.add('BYE');
  }
  final rounds = <List<String>>[];
  final int m = list.length;
  for (int round = 0; round < m - 1; round++) {
    for (int i = 0; i < m / 2; i++) {
      final a = list[i];
      final b = list[m - 1 - i];
      if (a != 'BYE' && b != 'BYE') {
        rounds.add([a, b]);
      }
    }
    // rotate except first
    final last = list.removeLast();
    list.insert(1, last);
  }
  return rounds;
}

List<List<String>> doubleRoundRobin(List<String> teams) {
  final first = singleRoundRobin(teams);
  final reversed = first.map((pair) => [pair[1], pair[0]]).toList();
  return [...first, ...reversed];
}

/// ------------------ UPDATED: Knockout Tournament ------------------
/// Accepts initial manual pairs instead of randomizing.
/// Returns a flat list of matches ready for scheduling.
List<PlannedMatch> knockoutTournamentFromManual(List<Map<String, dynamic>> manualPairs) {
  final allMatches = generateKnockoutRounds(manualPairs);
  final List<PlannedMatch> planned = [];

  for (final m in allMatches) {
    planned.add(PlannedMatch(
      group: '', // No group in knockout
      teamAId: m['teamAId'] as String,
      teamBId: m['teamBId'] as String,
    ));
  }

  return planned;
}
