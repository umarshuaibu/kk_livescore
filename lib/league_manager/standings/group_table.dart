// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/league_manager/standings/match_teams_model.dart';
import 'package:kklivescoreadmin/league_manager/standings/standings_model.dart';
import 'package:kklivescoreadmin/league_manager/standings/standings_service.dart';

class GroupTable extends StatefulWidget {
  final String leagueId;
  final List<StandingModel> standings;
  const GroupTable({
    super.key,
    required this.leagueId,
    required this.standings,
  });

  @override
  State<GroupTable> createState() => _GroupTableState();
}

class _GroupTableState extends State<GroupTable> {
  final StandingsService _service = StandingsService();
  late Future<Map<String, TeamModel>> _teamsFuture;

  static const double _rowHeight = 36.0;
  static const double _headerHeight = 36.0;

  @override
  void initState() {
    super.initState();
    final ids = widget.standings.map((s) => s.teamId).toList();
    _teamsFuture = _service.getTeamsBulk(ids, leagueId: widget.leagueId);
  }

  @override
  void didUpdateWidget(covariant GroupTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.standings != widget.standings) {
      final ids = widget.standings.map((s) => s.teamId).toList();
      _teamsFuture = _service.getTeamsBulk(ids, leagueId: widget.leagueId);
    }
  }

  // Deterministic comparator: points → GD → GF → name
  List<StandingModel> _sortStandings(
    List<StandingModel> list,
    Map<String, TeamModel> teams,
  ) {
    final copy = List<StandingModel>.from(list);
    copy.sort((a, b) {
      if (a.points != b.points) return b.points - a.points;
      if (a.goalDifference != b.goalDifference) {
        return b.goalDifference - a.goalDifference;
      }
      if (a.goalsFor != b.goalsFor) return b.goalsFor - a.goalsFor;
      final aName = teams[a.teamId]?.name ?? a.teamId;
      final bName = teams[b.teamId]?.name ?? b.teamId;
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, TeamModel>>(
      future: _teamsFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            height:
                _headerHeight + (widget.standings.length * _rowHeight),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context)
                    .dividerColor
                    .withOpacity(0.08),
              ),
            ),
            child: const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final teams = snap.data!;
        final sorted = _sortStandings(widget.standings, teams);

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                 // Theme.of(context).dividerColor.withOpacity(0.06),
                 kGrey1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // HEADER
              Container(
                height: _headerHeight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0),
                child: 
                const Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'TEAM',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: kWhiteColor),
                            
                          
                      ),
                    ),
                    Expanded(child: Center(child: Text('P', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,   color: kWhiteColor)))) ,
                    Expanded(child: Center(child: Text('W', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,   color: kWhiteColor)))) ,
                    Expanded(child: Center(child: Text('D', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,   color: kWhiteColor)))) ,
                    Expanded(child: Center(child: Text('L', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,   color: kWhiteColor)))) ,
                    Expanded(child: Center(child: Text('GF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,   color: kWhiteColor)))) ,
                    Expanded(child: Center(child: Text('GA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,   color: kWhiteColor)))) ,
                    Expanded(child: Center(child: Text('GD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,   color: kWhiteColor)))) ,
                    Expanded(child: Center(child: Text('PTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,   color: kWhiteColor)))) ,
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5),

              // ROWS (NO SCROLL HERE)
              Column(
                children: List.generate(sorted.length, (index) {
                  TextStyle(
                    color: kGrey1,
                  );
                  final s = sorted[index];
                  final team = teams[s.teamId];

                  final isTop4 = index < 4;
                  final relegationZoneSize =
                      (sorted.length / 4).ceil();
                  final isRelegation =
                      index >= (sorted.length - relegationZoneSize);

                  Color rowColor;
                  if (isTop4) {
                    rowColor =
                        Colors.greenAccent.withOpacity(0.1);
                  } else if (isRelegation) {
                    rowColor =
                        Colors.redAccent.withOpacity(0.1);
                  } else {
                    rowColor = Colors.transparent;
                  }

                  return Column(
                    children: [
                      Container(
                        height: _rowHeight,
                       color: rowColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: DefaultTextStyle(
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white, // 👈 global white
        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor:
                                        Colors.grey.shade200,
                                    backgroundImage:
                                        (team?.logoUrl.isNotEmpty ??
                                                false)
                                            ? CachedNetworkImageProvider(
                                                team!.logoUrl)
                                            : null,
                                    child: (team == null ||
                                            team.logoUrl.isEmpty)
                                        ? Text(
                                            s.teamId
                                                .substring(
                                                    0,
                                                    math.min(
                                                        2,
                                                        s.teamId
                                                            .length))
                                                .toUpperCase(),
                                            style: const TextStyle(
                                                fontSize: 9),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      team?.name ?? s.teamId,
                                      style: const TextStyle(
                                          fontSize: 10),
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(child: Center(child: Text('${s.played}', style: const TextStyle(fontSize: 10)))) ,
                            Expanded(child: Center(child: Text('${s.won}', style: const TextStyle(fontSize: 10)))) ,
                            Expanded(child: Center(child: Text('${s.drawn}', style: const TextStyle(fontSize: 10)))) ,
                            Expanded(child: Center(child: Text('${s.lost}', style: const TextStyle(fontSize: 10)))) ,
                            Expanded(child: Center(child: Text('${s.goalsFor}', style: const TextStyle(fontSize: 10)))) ,
                            Expanded(child: Center(child: Text('${s.goalsAgainst}', style: const TextStyle(fontSize: 10)))) ,
                            Expanded(child: Center(child: Text('${s.goalDifference}', style: const TextStyle(fontSize: 10)))) ,
                            Expanded(child: Center(child: Text('${s.points}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)))) ,
                          ],
                        ),
                      ),
                      ),
                      if (index != sorted.length - 1)
                        const Divider(
                            height: 0.5, thickness: 0.4),
                    ],
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
