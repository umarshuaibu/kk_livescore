// File: knockout_system/knockout_system_logic.dart

import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kklivescoreadmin/league_manager/match_scheduler.dart';

class KnockoutLeagueManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String leagueId;

  KnockoutLeagueManager({required this.leagueId});

  /// =========================================================
  /// 🏆 MAIN ENTRY: Initialize Knockout League
  /// =========================================================
  Future<void> initializeKnockoutLeague({
    required List<Map<String, dynamic>> manualPairs,
    required List<QueryDocumentSnapshot> availableTeams,
    required DateTime startDate,
  }) async {
    List<Map<String, dynamic>> pairs = [];

    /// =========================
    /// 1️⃣ PAIR TEAMS
    /// =========================
    if (manualPairs.isNotEmpty) {
      pairs = manualPairs
          .map((p) => {
                'teamAId': p['teams'][0],
                'teamBId': p['teams'].length > 1 ? p['teams'][1] : 'BYE',
              })
          .toList();
    } else {
      final teamIds = availableTeams.map((d) => d.id).toList();
      for (int i = 0; i < teamIds.length; i += 2) {
        if (i + 1 < teamIds.length) {
          pairs.add({'teamAId': teamIds[i], 'teamBId': teamIds[i + 1]});
        } else {
          pairs.add({'teamAId': teamIds[i], 'teamBId': 'BYE'});
        }
      }
    }

    /// =========================
    /// 2️⃣ SAVE ONLY USED TEAMS
    /// =========================
    final usedTeamIds = <String>{};
    for (var p in pairs) {
      if (p['teamAId'] != 'BYE') usedTeamIds.add(p['teamAId']);
      if (p['teamBId'] != 'BYE') usedTeamIds.add(p['teamBId']);
    }

    final batch = _firestore.batch();
    for (final teamId in usedTeamIds) {
      final globalTeam = await _firestore.collection('teams').doc(teamId).get();
      if (!globalTeam.exists) continue;

      final leagueTeamRef =
          _firestore.collection('leagues').doc(leagueId).collection('teams').doc(teamId);

      batch.set(leagueTeamRef, {
        ...globalTeam.data()!,
        'teamId': teamId,
      });
    }
    await batch.commit();

    /// =========================
    /// 3️⃣ GET MATCH DAYS
    /// =========================
    final leagueDoc = await _firestore.collection('leagues').doc(leagueId).get();
    final leagueData = leagueDoc.data() ?? {};
    final matchDays = List<String>.from(leagueData['MatchDays'] ?? []);
    if (matchDays.isEmpty) throw Exception('No match days configured for this league.');

    /// =========================
    /// 4️⃣ GENERATE ROUNDS + MATCHES
    /// =========================
    final generated = await _generateRoundsFromPairs(pairs);
    final allMatches = generated['matches'] as List<Map<String, dynamic>>;
    final rounds = generated['rounds'] as List<Map<String, dynamic>>;

    /// =========================
    /// 5️⃣ SCHEDULE MATCHES
    /// =========================
    final scheduledDates = scheduleMatches(
      startDate: startDate,
      matchDays: matchDays,
      totalMatches: allMatches.length,
    );
    if (scheduledDates.length < allMatches.length) {
      throw Exception('Not enough match slots generated.');
    }

    /// =========================
    /// 6️⃣ SAVE MATCHES
    /// =========================
    final matchBatch = _firestore.batch();
    for (int i = 0; i < allMatches.length; i++) {
      final m = allMatches[i];
      final matchRef =
          _firestore.collection('leagues').doc(leagueId).collection('matches').doc(m['matchId']);

      matchBatch.set(matchRef, {
        ...m,
        'leagueId': leagueId,
        'date': scheduledDates[i],
      });
    }
    await matchBatch.commit();

    /// =========================
    /// 7️⃣ SAVE ROUNDS
    /// =========================
    final roundsRef = _firestore.collection('leagues').doc(leagueId).collection('rounds');
    for (final r in rounds) {
      await roundsRef.doc(r['name']).set(r);
    }
  }

  /// =========================================================
  /// 🔁 GENERATE ROUNDS + RETURN MATCH LIST
  /// =========================================================
  Future<Map<String, dynamic>> _generateRoundsFromPairs(
      List<Map<String, dynamic>> initialPairs) async {
    List<Map<String, dynamic>> teams = [];

    for (var p in initialPairs) {
      teams.add({'teamId': p['teamAId']});
      teams.add({'teamId': p['teamBId']});
    }

    // Remove duplicates
    final seen = <String>{};
    teams = teams.where((t) {
      if (seen.contains(t['teamId'])) return false;
      seen.add(t['teamId']);
      return true;
    }).toList();

    teams.shuffle(Random());
    int numTeams = teams.length;
    int numRounds = (log(numTeams) / log(2)).ceil();
    int nextPowerOf2 = pow(2, numRounds).toInt();

    while (teams.length < nextPowerOf2) teams.add({'teamId': 'BYE'});

    List<Map<String, dynamic>> allMatches = [];
    List<Map<String, dynamic>> rounds = [];

    for (int r = 1; r <= numRounds; r++) {
      final roundName = _getRoundName(r, numRounds);
      final matches = _generateMatchesForRound(teams, r);

      final roundData = {
        'name': roundName,
        'roundNumber': r,
        'matches': matches.map((m) => _matchToMap(m)).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      rounds.add(roundData);

      for (var m in matches) {
        allMatches.add({..._matchToMap(m), 'round': r, 'roundName': roundName});
      }

      // Prepare placeholder teams for next round
      teams = List.generate(matches.length, (index) => {'teamId': null});
    }

    return {'matches': allMatches, 'rounds': rounds};
  }

  /// =========================================================
  /// MATCH GENERATOR
  /// =========================================================
  List<_Match> _generateMatchesForRound(List<Map<String, dynamic>> teams, int round) {
    final matches = <_Match>[];

    for (int i = 0; i < teams.length; i += 2) {
      final teamA = teams[i];
      final teamB = teams[i + 1];

      matches.add(_Match(
        matchId: _firestore.collection('leagues').doc().id,
        teamAId: teamA['teamId'],
        teamBId: teamB['teamId'],
        status: teamB['teamId'] == 'BYE' ? 'completed' : 'scheduled',
        winnerTeamId: teamB['teamId'] == 'BYE' ? teamA['teamId'] : null,
      ));
    }

    return matches;
  }

  /// =========================================================
  /// 🔄 UPDATE NEXT ROUND
  /// =========================================================
  Future<void> updateNextRound({
    required String roundName,
    required String matchId,
    required String winnerTeamId,
  }) async {
    final roundsSnap =
        await _firestore.collection('leagues').doc(leagueId).collection('rounds').get();

    final rounds = roundsSnap.docs.toList()
      ..sort((a, b) => (a['roundNumber'] as int).compareTo(b['roundNumber'] as int));

    final currentIndex = rounds.indexWhere((d) => d.id == roundName);
    if (currentIndex == -1 || currentIndex + 1 >= rounds.length) return;

    final currentRound = rounds[currentIndex];
    final nextRound = rounds[currentIndex + 1];

    final currentMatches = List<Map<String, dynamic>>.from(currentRound['matches']);
    final nextMatches = List<Map<String, dynamic>>.from(nextRound['matches']);

    final matchIndex = currentMatches.indexWhere((m) => m['matchId'].toString().trim() == matchId.trim());
    if (matchIndex == -1) return;

    if (winnerTeamId == 'BYE') return;

    final nextMatchIndex = matchIndex ~/ 2;
    if (matchIndex % 2 == 0) {
      nextMatches[nextMatchIndex]['teamAId'] = winnerTeamId;
    } else {
      nextMatches[nextMatchIndex]['teamBId'] = winnerTeamId;
    }

    // Update next round in Firestore
    await nextRound.reference.update({'matches': nextMatches});

    // Also update next round matches collection
    final nextRoundNumber = nextRound['roundNumber'];
    final matchesSnap = await _firestore
        .collection('leagues')
        .doc(leagueId)
        .collection('matches')
        .where('round', isEqualTo: nextRoundNumber)
        .get();

    for (var doc in matchesSnap.docs) {
      final data = doc.data();
      final idx = nextMatches.indexWhere((m) => m['matchId'] == data['matchId']);
      if (idx == -1) continue;

      await doc.reference.update({
        'teamAId': nextMatches[idx]['teamAId'],
        'teamBId': nextMatches[idx]['teamBId'],
      });
    }
  }

  Map<String, dynamic> _matchToMap(_Match m) => {
        'matchId': m.matchId,
        'teamAId': m.teamAId,
        'teamBId': m.teamBId,
        'status': m.status,
        'winnerTeamId': m.winnerTeamId,
      };

  String _getRoundName(int round, int totalRounds) {
    final reverse = totalRounds - round + 1;
    switch (reverse) {
      case 1:
        return 'Final';
      case 2:
        return 'Semifinal';
      case 3:
        return 'Quarterfinal';
      default:
        return 'Round of ${pow(2, reverse).toInt()}';
    }
  }
}

/// =========================================================
/// 🔄 HANDLE MATCH UPDATE (FOR LIVE UPDATER)
/// =========================================================
Future<void> handleKnockoutMatch({
  required FirebaseFirestore firestore,
  required Map<String, dynamic> match,
  required int scoreA,
  required int scoreB,
}) async {
  final String matchId = match['matchId'];
  final String roundName = match['roundName'];
  final String leagueId = match['leagueId'];

  final String teamAId = match['teamAId'] ?? '';
  final String teamBId = match['teamBId'] ?? '';

  final String winnerId =
      scoreA > scoreB ? teamAId : (scoreA == scoreB ? '' : teamBId);

  final matchRef = firestore
      .collection('leagues')
      .doc(leagueId)
      .collection('matches')
      .doc(matchId);

  final roundRef = firestore
      .collection('leagues')
      .doc(leagueId)
      .collection('rounds')
      .doc(roundName);

  /// =========================================================
  /// ✅ USE TRANSACTION (CRITICAL FIX)
  /// =========================================================
await firestore.runTransaction((transaction) async {
  final roundSnap = await transaction.get(roundRef);

  if (!roundSnap.exists) {
    throw Exception('Round not found: $roundName');
  }

  final List<dynamic> rawMatches = roundSnap['matches'];

  final List<Map<String, dynamic>> matches =
      rawMatches.map((e) => Map<String, dynamic>.from(e)).toList();

  /*print("🔥 ROUND MATCHES:");
  for (var m in matches) {
    print("➡️ ${m['matchId']} vs $matchId");
  }*/

  final idx = matches.indexWhere(
    (m) => m['matchId'].toString().trim() == matchId.trim(),
  );

  if (idx == -1) {
    print("❌ MATCH NOT FOUND IN ROUND ARRAY");
    return;
  }

  /// ✅ UPDATE ARRAY
  matches[idx]['status'] = 'completed';
  matches[idx]['winnerTeamId'] = winnerId;
  matches[idx]['scoreA'] = scoreA;
  matches[idx]['scoreB'] = scoreB;

  /// ✅ UPDATE ROUND
  transaction.update(roundRef, {
    'matches': matches,
  });

  /// ✅ UPDATE MATCH DOC
  transaction.update(matchRef, {
    'status': 'completed',
    'winnerTeamId': winnerId,
    'scoreA': scoreA,
    'scoreB': scoreB,
    'lastUpdated': FieldValue.serverTimestamp(),
  });
});

  /// =========================================================
  /// 🔄 MOVE TO NEXT ROUND (OUTSIDE TRANSACTION)
  /// =========================================================
  if (winnerId.isNotEmpty && winnerId != 'BYE') {
    final manager = KnockoutLeagueManager(leagueId: leagueId);

    await manager.updateNextRound(
      roundName: roundName,
      matchId: matchId,
      winnerTeamId: winnerId,
    );
  }
}

class _Match {
  final String matchId;
  final String? teamAId;
  final String? teamBId;
  final String status;
  final String? winnerTeamId;

  _Match({
    required this.matchId,
    this.teamAId,
    this.teamBId,
    required this.status,
    this.winnerTeamId,
  });
}
