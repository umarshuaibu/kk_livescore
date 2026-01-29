// ignore_for_file: unused_element

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kklivescoreadmin/league_manager/standings/match_teams_model.dart';
import 'package:kklivescoreadmin/league_manager/standings/standings_computation.dart';
import 'package:kklivescoreadmin/league_manager/standings/standings_model.dart';
// StandingsCache is no longer used, so you can remove this import
// import 'standings_cache.dart';

class StandingsService {
  final FirebaseFirestore _firestore;

  // Removed in-memory cache
  // final Map<String, TeamModel> _teamCache = {};
  // Removed disk cache
  // final StandingsCache _cache = StandingsCache();

  StandingsService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  // Stream: UI must only read from standings collection. This returns a stream of QuerySnapshot
  Stream<QuerySnapshot> streamStandingsQuery(String leagueId) {
    return _firestore
        .collection('leagues')
        .doc(leagueId)
        .collection('standings')
        .snapshots();
  }

  // Convenience: reads all standings once (for admin / snapshot)
  Future<List<StandingModel>> fetchStandingsOnce(String leagueId) async {
    final snap = await _firestore.collection('leagues').doc(leagueId).collection('standings').get();
    return snap.docs.map((d) => StandingModel.fromDoc(d)).toList();
  }

  // 🔥 Live fetch of teams from Firestore; no caching
  Future<Map<String, TeamModel>> getTeamsBulk(List<String> teamIds, {String? leagueId}) async {
    final Map<String, TeamModel> result = {};

    if (teamIds.isEmpty) return result;

    // Fetch all teams from Firestore in parallel
    final futures = teamIds.map((id) => _firestore.collection('teams').doc(id).get()).toList();
    final snaps = await Future.wait(futures);

    for (final s in snaps) {
      if (s.exists) {
        final tm = TeamModel.fromDoc(s);
        result[tm.id] = tm;
      }
    }

    return result;
  }

  // Helper to ensure a standings doc exists; used in transaction context
  Future<DocumentReference> _standingDocRef(String leagueId, String teamId) async {
    return _firestore.collection('leagues').doc(leagueId).collection('standings').doc(teamId);
  }

  // Return a Map of standings doc snapshots (used by computation)
  Future<Map<String, DocumentSnapshot>> _readStandingsDocsInTransaction(
      Transaction tx, String leagueId, List<String> teamIds) async {
    final out = <String, DocumentSnapshot>{};
    for (final id in teamIds) {
      final ref = _firestore.collection('leagues').doc(leagueId).collection('standings').doc(id);
      final snap = await tx.get(ref);
      out[id] = snap;
    }
    return out;
  }

  // Public function used by UI/admin code to trigger processing for a completed match.
  // This method delegates to computation layer (which uses transactions).
  Future<void> processCompletedMatch(String leagueId, String matchId) async {
    final comp = StandingsComputation(_firestore);
    await comp.processMatch(leagueId: leagueId, matchId: matchId);
  }
}
