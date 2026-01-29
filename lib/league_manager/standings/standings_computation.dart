// ignore_for_file: unnecessary_cast

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kklivescoreadmin/league_manager/standings/league_match_model.dart';
import 'package:kklivescoreadmin/league_manager/standings/standings_model.dart';

class StandingsComputation {
  final FirebaseFirestore _firestore;

  StandingsComputation(this._firestore);

  static const int winPoints = 3;
  static const int drawPoints = 1;

  // Process a match: idempotent & supports corrections
  Future<void> processMatch({required String leagueId, required String matchId}) async {
    final matchRef = _firestore.collection('leagues').doc(leagueId).collection('matches').doc(matchId);

    await _firestore.runTransaction((tx) async {
      final matchSnap = await tx.get(matchRef);
      if (!matchSnap.exists) return;
      final match = MatchModel.fromDoc(matchSnap);

      if (match.status != 'completed') {
        // Only process completed matches
        return;
      }

      final currentSnapshot = {'scoreA': match.scoreA, 'scoreB': match.scoreB};
      final prevSnapshot = match.standingsSnapshot;

      // If previous snapshot exists and equals current, nothing to do
      if (prevSnapshot != null &&
          prevSnapshot['scoreA'] == currentSnapshot['scoreA'] &&
          prevSnapshot['scoreB'] == currentSnapshot['scoreB']) {
        return;
      }

      // Read or create standings docs for both teams
      final standingARef = _firestore.collection('leagues').doc(leagueId).collection('standings').doc(match.teamAId);
      final standingBRef = _firestore.collection('leagues').doc(leagueId).collection('standings').doc(match.teamBId);

      final standingASnap = await tx.get(standingARef);
      final standingBSnap = await tx.get(standingBRef);

      StandingModel standingA = standingASnap.exists ? StandingModel.fromDoc(standingASnap) : StandingModel(
          teamId: match.teamAId,
          leagueId: leagueId,
          group: standingASnap.exists ? StandingModel.fromDoc(standingASnap).group : (matchSnap.data()?['group'] ?? 'default'),
          played: 0, won: 0, drawn: 0, lost: 0, goalsFor: 0, goalsAgainst: 0, goalDifference: 0, points: 0);
      StandingModel standingB = standingBSnap.exists ? StandingModel.fromDoc(standingBSnap) : StandingModel(
          teamId: match.teamBId,
          leagueId: leagueId,
          group: standingBSnap.exists ? StandingModel.fromDoc(standingBSnap).group : (matchSnap.data()?['group'] ?? 'default'),
          played: 0, won: 0, drawn: 0, lost: 0, goalsFor: 0, goalsAgainst: 0, goalDifference: 0, points: 0);

      // Helper to compute impact map from a snapshot (scoreA,scoreB)
      Map<String, int> computeImpact(int a, int b) {
        final impactA = <String, int>{'played': 1, 'goalsFor': a, 'goalsAgainst': b};
        final impactB = <String, int>{'played': 1, 'goalsFor': b, 'goalsAgainst': a};
        if (a > b) {
          impactA['won'] = 1;
          impactA['drawn'] = 0;
          impactA['lost'] = 0;
          impactA['points'] = winPoints;

          impactB['won'] = 0;
          impactB['drawn'] = 0;
          impactB['lost'] = 1;
          impactB['points'] = 0;
        } else if (a < b) {
          impactA['won'] = 0;
          impactA['drawn'] = 0;
          impactA['lost'] = 1;
          impactA['points'] = 0;

          impactB['won'] = 1;
          impactB['drawn'] = 0;
          impactB['lost'] = 0;
          impactB['points'] = winPoints;
        } else {
          impactA['won'] = 0;
          impactA['drawn'] = 1;
          impactA['lost'] = 0;
          impactA['points'] = drawPoints;

          impactB['won'] = 0;
          impactB['drawn'] = 1;
          impactB['lost'] = 0;
          impactB['points'] = drawPoints;
        }
        return {
          // flatten for team A and B combined (prefix A_ / B_)
          'A_played': impactA['played']!,
          'A_won': impactA['won']!,
          'A_drawn': impactA['drawn']!,
          'A_lost': impactA['lost']!,
          'A_goalsFor': impactA['goalsFor']!,
          'A_goalsAgainst': impactA['goalsAgainst']!,
          'A_points': impactA['points']!,
          'B_played': impactB['played']!,
          'B_won': impactB['won']!,
          'B_drawn': impactB['drawn']!,
          'B_lost': impactB['lost']!,
          'B_goalsFor': impactB['goalsFor']!,
          'B_goalsAgainst': impactB['goalsAgainst']!,
          'B_points': impactB['points']!,
        };
      }

      // Build delta (remove previous snapshot if exists, then add current)
      final deltaA = <String, int>{
        'played': 0,
        'won': 0,
        'drawn': 0,
        'lost': 0,
        'goalsFor': 0,
        'goalsAgainst': 0,
        'points': 0,
      };
      final deltaB = <String, int>{
        'played': 0,
        'won': 0,
        'drawn': 0,
        'lost': 0,
        'goalsFor': 0,
        'goalsAgainst': 0,
        'points': 0,
      };

      if (prevSnapshot != null) {
        final prevA = (prevSnapshot['scoreA'] ?? 0) as int;
        final prevB = (prevSnapshot['scoreB'] ?? 0) as int;
        final prevImpact = computeImpact(prevA, prevB);
        // subtract previous impact
        deltaA['played'] = deltaA['played']! - prevImpact['A_played']!;
        deltaA['won'] = deltaA['won']! - prevImpact['A_won']!;
        deltaA['drawn'] = deltaA['drawn']! - prevImpact['A_drawn']!;
        deltaA['lost'] = deltaA['lost']! - prevImpact['A_lost']!;
        deltaA['goalsFor'] = deltaA['goalsFor']! - prevImpact['A_goalsFor']!;
        deltaA['goalsAgainst'] = deltaA['goalsAgainst']! - prevImpact['A_goalsAgainst']!;
        deltaA['points'] = deltaA['points']! - prevImpact['A_points']!;

        deltaB['played'] = deltaB['played']! - prevImpact['B_played']!;
        deltaB['won'] = deltaB['won']! - prevImpact['B_won']!;
        deltaB['drawn'] = deltaB['drawn']! - prevImpact['B_drawn']!;
        deltaB['lost'] = deltaB['lost']! - prevImpact['B_lost']!;
        deltaB['goalsFor'] = deltaB['goalsFor']! - prevImpact['B_goalsFor']!;
        deltaB['goalsAgainst'] = deltaB['goalsAgainst']! - prevImpact['B_goalsAgainst']!;
        deltaB['points'] = deltaB['points']! - prevImpact['B_points']!;
      }

      // add current impact
      final curImpact = computeImpact(match.scoreA, match.scoreB);
      deltaA['played'] = deltaA['played']! + curImpact['A_played']!;
      deltaA['won'] = deltaA['won']! + curImpact['A_won']!;
      deltaA['drawn'] = deltaA['drawn']! + curImpact['A_drawn']!;
      deltaA['lost'] = deltaA['lost']! + curImpact['A_lost']!;
      deltaA['goalsFor'] = deltaA['goalsFor']! + curImpact['A_goalsFor']!;
      deltaA['goalsAgainst'] = deltaA['goalsAgainst']! + curImpact['A_goalsAgainst']!;
      deltaA['points'] = deltaA['points']! + curImpact['A_points']!;

      deltaB['played'] = deltaB['played']! + curImpact['B_played']!;
      deltaB['won'] = deltaB['won']! + curImpact['B_won']!;
      deltaB['drawn'] = deltaB['drawn']! + curImpact['B_drawn']!;
      deltaB['lost'] = deltaB['lost']! + curImpact['B_lost']!;
      deltaB['goalsFor'] = deltaB['goalsFor']! + curImpact['B_goalsFor']!;
      deltaB['goalsAgainst'] = deltaB['goalsAgainst']! + curImpact['B_goalsAgainst']!;
      deltaB['points'] = deltaB['points']! + curImpact['B_points']!;

      // Apply deltas ensuring non-negative invariants
      StandingModel applyDelta(StandingModel s, Map<String, int> d) {
        final played = (s.played + d['played']!).clamp(0, 1 << 30);
        final won = (s.won + d['won']!).clamp(0, 1 << 30);
        final drawn = (s.drawn + d['drawn']!).clamp(0, 1 << 30);
        final lost = (s.lost + d['lost']!).clamp(0, 1 << 30);
        final goalsFor = (s.goalsFor + d['goalsFor']!).clamp(0, 1 << 30);
        final goalsAgainst = (s.goalsAgainst + d['goalsAgainst']!).clamp(0, 1 << 30);
        final gd = goalsFor - goalsAgainst;
        final points = (s.points + d['points']!).clamp(0, 1 << 30);
        return s.copyWith(
          played: played as int,
          won: won as int,
          drawn: drawn as int,
          lost: lost as int,
          goalsFor: goalsFor as int,
          goalsAgainst: goalsAgainst as int,
          goalDifference: gd as int,
          points: points as int,
        );
      }

      final newStandingA = applyDelta(standingA, deltaA);
      final newStandingB = applyDelta(standingB, deltaB);

      // Persist new standings
      tx.set(standingARef, newStandingA.toJson(), SetOptions(merge: true));
      tx.set(standingBRef, newStandingB.toJson(), SetOptions(merge: true));

      // Update match doc with standingsSnapshot and processed timestamp
      final snapshotToSave = {'scoreA': match.scoreA, 'scoreB': match.scoreB, 'processedAt': FieldValue.serverTimestamp()};
      tx.update(matchRef, {'standingsSnapshot': snapshotToSave, 'standingsProcessedAt': FieldValue.serverTimestamp()});
    }, timeout: const Duration(seconds: 30));
  }
}