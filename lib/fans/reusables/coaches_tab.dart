import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/constants/size.dart';
import 'package:kklivescoreadmin/constants/text_styles.dart';

/// CoachesTab
/// - Production-ready improvements:
///   * Friendly, non-technical error messages and retry options
///   * Defensive handling for missing fields and network failures
///   * No raw / sensitive IDs are ever shown in the UI (IDs are used internally only)
///   * Tolerant to variations in field names (teamId, teamid, team)
///   * whereIn batching for Firestore (max 10 per query) with deduplication
class CoachesTab extends StatefulWidget {
  final String leagueId;

  const CoachesTab({super.key, required this.leagueId});

  @override
  State<CoachesTab> createState() => _CoachesTabState();
}

class _CoachesTabState extends State<CoachesTab> {
  // Friendly messages for UI
  static const _networkErrorMessage =
      'Unable to load data. Please check your internet connection and try again.';
  static const _noDataMessage = 'No data available';

  // Helper: tolerant extraction of teamId from league team doc
  String? _extractTeamId(Map<String, dynamic> docData) {
    const candidates = ['teamId', 'teamid', 'teamID', 'team'];
    for (final key in candidates) {
      final value = docData[key];
      if (value != null) {
        final s = value.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  // Fetch team IDs for the league. Try plural 'leagues' path first for compatibility,
  // then fallback to singular 'league' path. Rethrows on error so FutureBuilder can display UI.
  Future<List<String>> _fetchTeamIdsForLeague() async {
    try {
      final pluralSnap = await FirebaseFirestore.instance
          .collection('leagues')
          .doc(widget.leagueId)
          .collection('teams')
          .get();

      if (pluralSnap.docs.isNotEmpty) {
        final ids = pluralSnap.docs
            .map((d) => _extractTeamId(d.data() as Map<String, dynamic>))
            .whereType<String>()
            .toSet()
            .toList();
        return ids;
      }

      final singularSnap = await FirebaseFirestore.instance
          .collection('league')
          .doc(widget.leagueId)
          .collection('teams')
          .get();

      final ids = singularSnap.docs
          .map((d) => _extractTeamId(d.data() as Map<String, dynamic>))
          .whereType<String>()
          .toSet()
          .toList();

      return ids;
    } catch (e) {
      // Developer-only log. Do NOT surface technical details to users.
      debugPrint('[_fetchTeamIdsForLeague] failed for league ${widget.leagueId}: $e');
      rethrow;
    }
  }

  // Firestore 'whereIn' supports max 10 items per query. We chunk and query across likely field names.
  // Deduplicate results by document ID.
  Future<List<QueryDocumentSnapshot>> _fetchCoachesForTeams(List<String> teamIds) async {
    if (teamIds.isEmpty) return [];

    try {
      const chunkSize = 10;
      final Set<String> seen = {};
      final List<QueryDocumentSnapshot> out = [];

      for (var i = 0; i < teamIds.length; i += chunkSize) {
        final end = (i + chunkSize > teamIds.length) ? teamIds.length : i + chunkSize;
        final chunk = teamIds.sublist(i, end);

        // Try multiple possible field names to be tolerant to schema variations.
        final List<String> coachFieldsToTry = ['teamId', 'teamid', 'team'];

        for (final field in coachFieldsToTry) {
          try {
            final snap = await FirebaseFirestore.instance
                .collection('coaches')
                .where(field, whereIn: chunk)
                .get();

            for (final doc in snap.docs) {
              if (!seen.contains(doc.id)) {
                seen.add(doc.id);
                out.add(doc);
              }
            }
          } catch (e) {
            // It's OK if one field name query fails because the collection might not use it.
            // Log for developer debugging; do not expose to user.
            debugPrint('[_fetchCoachesForTeams] query by "$field" failed for chunk: $e');
            // continue trying other field names
          }
        }
      }

      return out;
    } catch (e) {
      debugPrint('[_fetchCoachesForTeams] failed: $e');
      rethrow;
    }
  }

  // Calculate age from dateOfBirth (accepts Timestamp, ISO string or DateTime)
  int? _calculateAge(dynamic dateOfBirth) {
    if (dateOfBirth == null) return null;
    DateTime? dob;
    if (dateOfBirth is Timestamp) {
      dob = dateOfBirth.toDate();
    } else if (dateOfBirth is DateTime) {
      dob = dateOfBirth;
    } else if (dateOfBirth is String) {
      try {
        dob = DateTime.parse(dateOfBirth);
      } catch (_) {
        dob = null;
      }
    }
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  // UI building
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _fetchTeamIdsForLeague(),
      builder: (context, teamIdsSnapshot) {
        if (teamIdsSnapshot.hasError) {
          return _buildErrorView(message: _networkErrorMessage, onRetry: () => setState(() {}));
        }

        if (!teamIdsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final teamIds = teamIdsSnapshot.data!;
        if (teamIds.isEmpty) {
          return Center(child: Text('No teams in this league', style: kText12White));
        }

        // Now fetch coaches for the obtained team IDs
        return FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _fetchCoachesForTeams(teamIds),
          builder: (context, coachesSnapshot) {
            if (coachesSnapshot.hasError) {
              return _buildErrorView(message: _networkErrorMessage, onRetry: () => setState(() {}));
            }

            if (!coachesSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = coachesSnapshot.data!;
            if (docs.isEmpty) {
              return Center(child: Text('No coaches found for this league', style: kText12White));
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {}); // simply rebuild; FutureBuilders will refetch
                // small delay to show the spinner properly
                await Future.delayed(const Duration(milliseconds: 300));
              },
              color: kPrimaryColor,
              child: ListView.builder(
                padding: EdgeInsets.all(eqW(8)),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>? ?? {};
                  final photo = (data['photoUrl'] ?? data['photo'] ?? '').toString();
                  final name = (data['name']?.toString().trim().isNotEmpty == true) ? data['name'].toString() : 'Coach';
                  final teamName = (data['teamName']?.toString().trim().isNotEmpty == true)
                      ? data['teamName'].toString()
                      : (data['team']?.toString().trim().isNotEmpty == true ? data['team'].toString() : 'Team');
                  final dobField = data['dateOfBirth'] ?? data['dob'] ?? data['birthDate'];
                  final age = _calculateAge(dobField);

                  return Container(
                    margin: EdgeInsets.symmetric(vertical: eqW(6)),
                    padding: EdgeInsets.all(eqW(10)),
                    decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(eqW(8))),
                    child: Row(
                      children: [
                        // Coach photo
                        Container(
                          width: eqW(44),
                          height: eqW(44),
                          decoration:
                              BoxDecoration(borderRadius: BorderRadius.circular(eqW(22)), color: kGrey1.withOpacity(0.08)),
                          child: (photo.isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(eqW(22)),
                                  child: Image.network(
                                    photo,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(Icons.person, color: kGrey2),
                                  ),
                                )
                              : Icon(Icons.person, color: kGrey2),
                        ),
                        SizedBox(width: eqW(12)),
                        // Name & team
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: kText12White),
                            SizedBox(height: eqW(4)),
                            Text(teamName, style: kText10GreyR),
                          ]),
                        ),
                        // Age
                        Text(age != null ? '$age yrs' : '-', style: kText12White),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // Reusable friendly error widget (non-technical)
  Widget _buildErrorView({required String message, required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(eqW(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: kText12White, textAlign: TextAlign.center),
            SizedBox(height: eqW(8)),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}