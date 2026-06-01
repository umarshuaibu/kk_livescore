import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/admins/management/services/sports_data_service.dart';

// ══════════════════════════════════════════════════════════════════
//  INTERNATIONAL LEAGUE MODEL
// ══════════════════════════════════════════════════════════════════
class IntlLeague {
  final int id;
  final String name;
  final String country;
  final String countryFlag;
  final String logoUrl;
  final Color accentColor;
  final int season;

  const IntlLeague({
    required this.id,
    required this.name,
    required this.country,
    required this.countryFlag,
    required this.logoUrl,
    required this.accentColor,
    required this.season,
  });
}

// ══════════════════════════════════════════════════════════════════
//  API MATCH MODELS (for ApiFootballService)
// ══════════════════════════════════════════════════════════════════
class ApiMatch {
  final int id;
  final DateTime date;
  final String status;
  final int? elapsed;
  final String? round;
  final ApiTeamRef home;
  final ApiTeamRef away;
  final int? homeGoals;
  final int? awayGoals;
  final String? venueName;

  bool get isLive =>
      status == 'IN_PLAY' ||
      status == 'PAUSED' ||
      status == 'LIVE' ||
      status.contains('H');
  bool get isFinished => status == 'FT' || status == 'FINISHED';

  ApiMatch({
    required this.id,
    required this.date,
    required this.status,
    this.elapsed,
    this.round,
    required this.home,
    required this.away,
    this.homeGoals,
    this.awayGoals,
    this.venueName,
  });

  factory ApiMatch.fromJson(Map<String, dynamic> json) {
    final fdMatch = FdMatch.fromJson(json);
    return ApiMatch(
      id: fdMatch.id,
      date: fdMatch.utcDate,
      status: fdMatch.status,
      elapsed: fdMatch.minute,
      round: fdMatch.matchday != null ? 'Matchday ${fdMatch.matchday}' : null,
      home: ApiTeamRef(
        name: fdMatch.home.name,
        logoUrl: fdMatch.home.badge ?? fdMatch.home.crest ?? '',
        winner: fdMatch.homeScore != null &&
            fdMatch.awayScore != null &&
            fdMatch.homeScore! > fdMatch.awayScore!,
      ),
      away: ApiTeamRef(
        name: fdMatch.away.name,
        logoUrl: fdMatch.away.badge ?? fdMatch.away.crest ?? '',
        winner: fdMatch.awayScore != null &&
            fdMatch.homeScore != null &&
            fdMatch.awayScore! > fdMatch.homeScore!,
      ),
      homeGoals: fdMatch.homeScore,
      awayGoals: fdMatch.awayScore,
      venueName: fdMatch.venue,
    );
  }
}

class ApiTeamRef {
  final String name;
  final String logoUrl;
  final bool? winner;

  ApiTeamRef({
    required this.name,
    required this.logoUrl,
    this.winner,
  });
}

// ══════════════════════════════════════════════════════════════════
//  API STANDINGS MODELS
// ══════════════════════════════════════════��═══════════════════════
class ApiStandingGroup {
  final List<ApiStandingRow> rows;

  ApiStandingGroup({required this.rows});

  factory ApiStandingGroup.fromJson(Map<String, dynamic> json) {
    final standingData = json as Map<String, dynamic>;
    final rowList = (standingData['table'] as List? ?? [])
        .map((r) => ApiStandingRow.fromJson(r as Map<String, dynamic>))
        .toList();
    return ApiStandingGroup(rows: rowList);
  }
}

class ApiStandingRow {
  final int rank;
  final ApiTeamRef team;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalDiff;
  final int points;
  final String? form;
  final String? description;

  ApiStandingRow({
    required this.rank,
    required this.team,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalDiff,
    required this.points,
    this.form,
    this.description,
  });

  factory ApiStandingRow.fromJson(Map<String, dynamic> json) {
    final fdStanding = FdStanding.fromJson(json);
    return ApiStandingRow(
      rank: fdStanding.position,
      team: ApiTeamRef(
        name: fdStanding.team.name,
        logoUrl: fdStanding.team.badge ?? fdStanding.team.crest ?? '',
      ),
      played: fdStanding.playedGames,
      won: fdStanding.won,
      drawn: fdStanding.draw,
      lost: fdStanding.lost,
      goalDiff: fdStanding.goalDifference,
      points: fdStanding.points,
      form: fdStanding.form,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  INTERNATIONAL LEAGUES CATALOGUE
// ══════════════════════════════════════════════════════════════════
const List<IntlLeague> kIntlLeagues = [
  IntlLeague(
    id: 4328,
    name: 'Premier League',
    country: 'England',
    countryFlag: '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
    logoUrl: 'https://www.thesportsdb.com/images/media/league/badge/nxtavy1430174508.png',
    accentColor: Color(0xFF3D195B),
    season: 2025,
  ),
  IntlLeague(
    id: 4335,
    name: 'La Liga',
    country: 'Spain',
    countryFlag: '🇪🇸',
    logoUrl: 'https://www.thesportsdb.com/images/media/league/badge/xsv2w21430174426.png',
    accentColor: Color(0xFFFF4B44),
    season: 2025,
  ),
  IntlLeague(
    id: 4332,
    name: 'Serie A',
    country: 'Italy',
    countryFlag: '🇮🇹',
    logoUrl: 'https://www.thesportsdb.com/images/media/league/badge/8s0u2d1430174346.png',
    accentColor: Color(0xFF0066CC),
    season: 2025,
  ),
  IntlLeague(
    id: 4331,
    name: 'Bundesliga',
    country: 'Germany',
    countryFlag: '🇩🇪',
    logoUrl: 'https://www.thesportsdb.com/images/media/league/badge/u0uzvs1430174219.png',
    accentColor: Color(0xFFE30614),
    season: 2025,
  ),
  IntlLeague(
    id: 4334,
    name: 'Ligue 1',
    country: 'France',
    countryFlag: '🇫🇷',
    logoUrl: 'https://www.thesportsdb.com/images/media/league/badge/s7x5wu1430174307.png',
    accentColor: Color(0xFF003087),
    season: 2025,
  ),
  IntlLeague(
    id: 4480,
    name: 'Champions League',
    country: 'Europe',
    countryFlag: '🇪🇺',
    logoUrl: 'https://www.thesportsdb.com/images/media/league/badge/q60xgu1430170598.png',
    accentColor: Color(0xFF001E62),
    season: 2025,
  ),
  IntlLeague(
    id: 4481,
    name: 'Europa League',
    country: 'Europe',
    countryFlag: '🇪🇺',
    logoUrl: 'https://www.thesportsdb.com/images/media/league/badge/5l0dv31430170636.png',
    accentColor: Color(0xFFF05000),
    season: 2025,
  ),
  IntlLeague(
    id: 4429,
    name: 'World Cup',
    country: 'World',
    countryFlag: '🌍',
    logoUrl: 'https://www.thesportsdb.com/images/media/league/badge/worldcup.png',
    accentColor: Color(0xFF003087),
    season: 2022,
  ),
];

// ══════════════════════════════════════════════════════════════════
//  API FOOTBALL SERVICE (wrapper for SportsDataService)
// ══════════════════════════════════════════════════════════════════
class ApiFootballService {
  static Future<List<ApiMatch>> fetchFixtures({
    required int leagueId,
    required int season,
    String? status,
    int? next,
    int? last,
  }) async {
    // Map IntlLeague ID to Competition code
    final comp = _getCompetitionByLeagueId(leagueId);
    if (comp == null) return [];

    List<FdMatch> matches = [];

    if (status != null) {
      // Fetch by status (for live)
      final all = await SportsDataService.fetchAllFixtureGroups(comp.code);
      matches = all['live'] ?? [];
    } else if (next != null) {
      // Fetch next matches
      matches = await SportsDataService.fetchNextMatches(comp.code, limit: next);
    } else if (last != null) {
      // Fetch last matches
      matches = await SportsDataService.fetchLastMatches(comp.code, limit: last);
    }

    return matches.map((m) => ApiMatch.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<List<ApiStandingGroup>> fetchStandings({
    required int leagueId,
    required int season,
  }) async {
    final comp = _getCompetitionByLeagueId(leagueId);
    if (comp == null) return [];

    final standings = await SportsDataService.fetchStandings(comp.code);
    return standings
        .map((g) => ApiStandingGroup(
            rows: g.rows
                .map((r) => ApiStandingRow.fromJson(r as Map<String, dynamic>))
                .toList()))
        .toList();
  }

  static Competition? _getCompetitionByLeagueId(int leagueId) {
    for (final comp in kCompetitions) {
      if (comp.sdbLeagueId == leagueId) return comp;
    }
    return null;
  }
}