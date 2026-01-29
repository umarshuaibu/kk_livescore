import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/match_model.dart';
import 'standings_service.dart'; // <-- you must create this

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'matches';
  final StandingService _standingService = StandingService();
  final _uuid = const Uuid();

  // --------------------------------------------------------------------------
  // CRUD
  // --------------------------------------------------------------------------

  /// ✅ Add a single match
  Future<void> addMatch(MatchModel match) async {
    try {
      await _firestore.collection(_collection).doc(match.id).set(match.toMap());
    } catch (e) {
      throw Exception("Failed to add match: $e");
    }
  }

  /// ✅ Bulk add matches (e.g., generated fixtures)
  Future<void> addMatches(List<MatchModel> matches) async {
    final batch = _firestore.batch();
    try {
      for (var match in matches) {
        final docRef = _firestore.collection(_collection).doc(match.id);
        batch.set(docRef, match.toMap());
      }
      await batch.commit();
    } catch (e) {
      throw Exception("Failed to add matches: $e");
    }
  }

  /// ✅ Fetch all matches (optionally filter by leagueId, groupId, or date range)
  Future<List<MatchModel>> fetchMatches({
    String? leagueId,
    String? groupId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (leagueId != null) {
        query = query.where("leagueId", isEqualTo: leagueId);
      }
      if (groupId != null) {
        query = query.where("groupId", isEqualTo: groupId);
      }
      if (from != null) {
        query = query.where("date", isGreaterThanOrEqualTo: from.toIso8601String());
      }
      if (to != null) {
        query = query.where("date", isLessThanOrEqualTo: to.toIso8601String());
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => MatchModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception("Failed to fetch matches: $e");
    }
  }

  /// ✅ Delete a match
  Future<void> deleteMatch(String matchId) async {
    try {
      await _firestore.collection(_collection).doc(matchId).delete();
    } catch (e) {
      throw Exception("Failed to delete match: $e");
    }
  }

  /// ✅ Update a match (also updates standings if scores provided)
  Future<void> updateMatch(MatchModel match) async {
    try {
      await _firestore.collection(_collection).doc(match.id).update(match.toMap());

      if (match.homeScore != null && match.awayScore != null) {
        await _standingService.updateFromMatch(match);
      }
    } catch (e) {
      throw Exception("Failed to update match: $e");
    }
  }

  /// ✅ Stream matches in real-time (supports date range)
  Stream<List<MatchModel>> streamMatches({
    String? leagueId,
    String? groupId,
    DateTime? from,
    DateTime? to,
  }) {
    Query query = _firestore.collection(_collection);

    if (leagueId != null) {
      query = query.where("leagueId", isEqualTo: leagueId);
    }
    if (groupId != null) {
      query = query.where("groupId", isEqualTo: groupId);
    }
    if (from != null) {
      query = query.where("date", isGreaterThanOrEqualTo: from.toIso8601String());
    }
    if (to != null) {
      query = query.where("date", isLessThanOrEqualTo: to.toIso8601String());
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => MatchModel.fromMap(doc.data() as Map<String, dynamic>)).toList());
  }

  // --------------------------------------------------------------------------
  // FIXTURE SCHEDULING
  // --------------------------------------------------------------------------

  /// ✅ Schedule Group A & Group B fixtures and save to Firestore
  Future<void> scheduleLeagueMatches({
    required String leagueId,
    required List<String> teamIds,
    required List<int> matchDays,
    required List<String> matchTimes,
    required DateTime startDate,
  }) async {
    if (teamIds.length < 4) {
      throw Exception("At least 4 teams required to create a league.");
    }

    // Split into groups
    final half = (teamIds.length / 2).ceil();
    final groupA = teamIds.sublist(0, half);
    final groupB = teamIds.sublist(half);

    // Generate fixtures
    final fixturesA = generateFixtures(
      leagueId: leagueId,
      groupId: "GroupA",
      teamIds: groupA,
      matchDays: matchDays,
      matchTimes: matchTimes,
      startDate: startDate,
    );
    final fixturesB = generateFixtures(
      leagueId: leagueId,
      groupId: "GroupB",
      teamIds: groupB,
      matchDays: matchDays,
      matchTimes: matchTimes,
      startDate: startDate,
    );

    // Save to Firestore
    await addMatches([...fixturesA, ...fixturesB]);

        // Initialize standings for both groups
        await _standingService.initializeStandings(
          leagueId: leagueId,
          groupId: "A",
          teamIds: groupA,
        );
        await _standingService.initializeStandings(
          leagueId: leagueId,
          groupId: "B",
          teamIds: groupB,
        );
  }

  /// ✅ Fixture generator (double round robin, no clashes)
  List<MatchModel> generateFixtures({
    required String leagueId,
    required String groupId,
    required List<String> teamIds,
    required List<int> matchDays,
    required List<String> matchTimes,
    required DateTime startDate,
  }) {
    final List<MatchModel> fixtures = [];
    final List<String> teams = List.from(teamIds);

    if (teams.length.isOdd) {
      teams.add("BYE");
    }

    final int n = teams.length;
    final int rounds = (n - 1) * 2;
    final int matchesPerRound = n ~/ 2;

    DateTime currentDate = startDate;

    for (int round = 0; round < rounds; round++) {
      final Set<String> scheduledTeams = {};

      for (int match = 0; match < matchesPerRound; match++) {
        final String home = teams[match];
        final String away = teams[n - 1 - match];

        if (home != "BYE" && away != "BYE") {
          if (scheduledTeams.contains(home) || scheduledTeams.contains(away)) {
            currentDate = _getNextDate(currentDate, matchDays);
          }

          final time = matchTimes[matchesPerRound > 1
              ? match % matchTimes.length
              : 0];

          fixtures.add(
            MatchModel(
              id: _uuid.v4(), // ✅ safer than manual IDs
              leagueId: leagueId,
              groupId: groupId,
              homeTeamId: round.isEven ? home : away,
              awayTeamId: round.isEven ? away : home,
              date: currentDate,
              time: time,
              homeScore: null,
              awayScore: null,
            ),
          );

          scheduledTeams.add(home);
          scheduledTeams.add(away);
        }
      }

      teams.insert(1, teams.removeLast());
      currentDate = _getNextDate(currentDate, matchDays);
    }

    return fixtures;
  }

  /// ✅ Get next valid match day
  DateTime _getNextDate(DateTime current, List<int> matchDays) {
    DateTime next = current.add(const Duration(days: 1));
    while (!matchDays.contains(next.weekday)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }
}
