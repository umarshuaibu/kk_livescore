import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/constants/size.dart';

/// BracketViewTab for knockout tournaments
class BracketViewTab extends StatefulWidget {
  final String leagueId;
  const BracketViewTab({super.key, required this.leagueId});

  @override
  State<BracketViewTab> createState() => _BracketViewTabState();
}

class _BracketViewTabState extends State<BracketViewTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Map rounds -> list of matches
  Map<int, List<_KnockoutMatch>> rounds = {};

  @override
  void initState() {
    super.initState();
    _listenMatches();
  }

  void _listenMatches() {
    _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .collection('matches')
        .snapshots()
        .listen((snap) {
      final Map<int, List<_KnockoutMatch>> newRounds = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final round = data['round'] ?? 1;
        newRounds.putIfAbsent(round, () => []);
        newRounds[round]!.add(_KnockoutMatch(
          teamA: data['teamAName'] ?? 'Team A',
          teamB: data['teamBName'] ?? 'Team B',
          scoreA: data['scoreA']?.toString() ?? '-',
          scoreB: data['scoreB']?.toString() ?? '-',
          matchId: doc.id,
        ));
      }
      setState(() => rounds = newRounds);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final sortedRounds = rounds.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sortedRounds.map((roundNumber) {
          final matches = rounds[roundNumber]!;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROUND $roundNumber',
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  children: matches.map((m) => _buildMatchCard(m)).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Individual match card widget
  Widget _buildMatchCard(_KnockoutMatch match) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: kGrey1,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          _teamRow(match.teamA, match.scoreA, isWinner: match.isTeamAWinner()),
          const Divider(color: kPrimaryLight, thickness: 1),
          _teamRow(match.teamB, match.scoreB, isWinner: match.isTeamBWinner()),
        ],
      ),
    );
  }

  Widget _teamRow(String team, String score, {bool isWinner = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            team,
            style: TextStyle(
              color: isWinner ? kPrimaryLight : kPrimaryColor,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isWinner ? kPrimaryLight : kWhiteColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            score,
            style: TextStyle(
              color: isWinner ? kWhiteColor : kPrimaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// Knockout match model
class _KnockoutMatch {
  final String matchId;
  final String teamA;
  final String teamB;
  final String scoreA;
  final String scoreB;

  _KnockoutMatch({
    required this.matchId,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
  });

  bool isTeamAWinner() {
    final a = int.tryParse(scoreA) ?? 0;
    final b = int.tryParse(scoreB) ?? 0;
    return a > b;
  }

  bool isTeamBWinner() {
    final a = int.tryParse(scoreA) ?? 0;
    final b = int.tryParse(scoreB) ?? 0;
    return b > a;
  }
}
