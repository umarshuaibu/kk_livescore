import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kklivescoreadmin/admins/management/models/match_model.dart';

class StandingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'standings';

  /// ✅ Initialize standings for all teams in a league
  Future<void> initializeStandings({
    required String leagueId,
    required String groupId,
    required List<String> teamIds,
  }) async {
    final batch = _firestore.batch();

    for (var teamId in teamIds) {
      final docRef = _firestore
          .collection(_collection)
          .doc("${leagueId}_${groupId}_$teamId");

      batch.set(docRef, {
        "leagueId": leagueId,
        "groupId": groupId,
        "teamId": teamId,
        "played": 0,
        "won": 0,
        "drawn": 0,
        "lost": 0,
        "goalsFor": 0,
        "goalsAgainst": 0,
        "goalDifference": 0,
        "points": 0,
      });
    }

    await batch.commit();
  }

  /// ✅ Update standings when a match score is updated
  Future<void> updateStandingsAfterMatch({
    required String leagueId,
    required String groupId,
    required String homeTeamId,
    required String awayTeamId,
    required int homeScore,
    required int awayScore,
  }) async {
    final homeRef =
        _firestore.collection(_collection).doc("${leagueId}_${groupId}_$homeTeamId");
    final awayRef =
        _firestore.collection(_collection).doc("${leagueId}_${groupId}_$awayTeamId");

    await _firestore.runTransaction((transaction) async {
      final homeSnap = await transaction.get(homeRef);
      final awaySnap = await transaction.get(awayRef);

      if (!homeSnap.exists || !awaySnap.exists) {
        throw Exception("Standings not initialized for one or both teams.");
      }

      final homeData = Map<String, dynamic>.from(homeSnap.data()!);
      final awayData = Map<String, dynamic>.from(awaySnap.data()!);

      // Update matches played
      homeData["played"] += 1;
      awayData["played"] += 1;

      // Goals
      homeData["goalsFor"] += homeScore;
      homeData["goalsAgainst"] += awayScore;
      awayData["goalsFor"] += awayScore;
      awayData["goalsAgainst"] += homeScore;

      homeData["goalDifference"] =
          homeData["goalsFor"] - homeData["goalsAgainst"];
      awayData["goalDifference"] =
          awayData["goalsFor"] - awayData["goalsAgainst"];

      // Results
      if (homeScore > awayScore) {
        homeData["won"] += 1;
        awayData["lost"] += 1;
        homeData["points"] += 3;
      } else if (awayScore > homeScore) {
        awayData["won"] += 1;
        homeData["lost"] += 1;
        awayData["points"] += 3;
      } else {
        homeData["drawn"] += 1;
        awayData["drawn"] += 1;
        homeData["points"] += 1;
        awayData["points"] += 1;
      }

      transaction.update(homeRef, homeData);
      transaction.update(awayRef, awayData);
    });
  }

  /// ✅ Reset standings for a league group
  Future<void> resetStandings(String leagueId, String groupId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where("leagueId", isEqualTo: leagueId)
        .where("groupId", isEqualTo: groupId)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {
        "played": 0,
        "won": 0,
        "drawn": 0,
        "lost": 0,
        "goalsFor": 0,
        "goalsAgainst": 0,
        "goalDifference": 0,
        "points": 0,
      });
    }
    await batch.commit();
  }

  /// ✅ Fetch standings (sorted by points & goal difference)
  Future<List<Map<String, dynamic>>> fetchStandings({
    required String leagueId,
    required String groupId,
  }) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where("leagueId", isEqualTo: leagueId)
        .where("groupId", isEqualTo: groupId)
        .get();

    final standings =
        snapshot.docs.map((doc) => doc.data()).toList();

    standings.sort((a, b) {
      if (b["points"] != a["points"]) {
        return b["points"].compareTo(a["points"]);
      }
      return b["goalDifference"].compareTo(a["goalDifference"]);
    });

    return standings;
  }

  /// ✅ Stream standings in real-time
  Stream<List<Map<String, dynamic>>> streamStandings({
    required String leagueId,
    required String groupId,
  }) {
    return _firestore
        .collection(_collection)
        .where("leagueId", isEqualTo: leagueId)
        .where("groupId", isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
      final standings =
          snapshot.docs.map((doc) => doc.data()).toList();

      standings.sort((a, b) {
        if (b["points"] != a["points"]) {
          return b["points"].compareTo(a["points"]);
        }
        return b["goalDifference"].compareTo(a["goalDifference"]);
      });

      return standings;
    });
  }
  Future<void> updateFromMatch(MatchModel match) async {
  if (match.homeScore == null || match.awayScore == null) return;

  await updateStandingsAfterMatch(
    leagueId: match.leagueId,
    groupId: match.groupId,
    homeTeamId: match.homeTeamId,
    awayTeamId: match.awayTeamId,
    homeScore: match.homeScore!,
    awayScore: match.awayScore!,
  );
}

}
