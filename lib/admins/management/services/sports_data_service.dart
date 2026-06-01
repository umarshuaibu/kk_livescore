/*import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ══════════════════════════════════════════════════════════════════
//  API KEYS & BASE URLS
// ══════════════════════════════════════════════════════════════════
const String kFootballDataToken = '8f20a99899cd4b3ba24ceaf629fff3d0';
const String kSportsDbKey = '123'; // free key

const String _fdBase = 'https://api.football-data.org/v4';
const String _sdbBase = 'https://www.thesportsdb.com/api/v1/json/$kSportsDbKey';

// ══════════════════════════════════════════════════════════════════
//  COMPETITION CATALOGUE
//  Maps football-data competition codes → TheSportsDB league IDs
// ══════════════════════════════════════════════════════════════════
class Competition {
  final String code;          // football-data code e.g. "PL"
  final String name;
  final String country;
  final String flag;          // emoji
  final int sdbLeagueId;      // TheSportsDB idLeague
  final Color accentColor;
  final String category;      // "Europe" | "Africa" | "World" | "Americas"

  const Competition({
    required this.code,
    required this.name,
    required this.country,
    required this.flag,
    required this.sdbLeagueId,
    required this.accentColor,
    required this.category,
  });
}

const List<Competition> kCompetitions = [
  Competition(
    code: 'PL',   name: 'Premier League',    country: 'England',
    flag: '🏴󠁧󠁢󠁥󠁮󠁧󠁿', sdbLeagueId: 4328,
    accentColor: Color(0xFF3D195B), category: 'Europe',
  ),
  Competition(
    code: 'PD',   name: 'La Liga',           country: 'Spain',
    flag: '🇪🇸',   sdbLeagueId: 4335,
    accentColor: Color(0xFFFF4B44), category: 'Europe',
  ),
  Competition(
    code: 'SA',   name: 'Serie A',           country: 'Italy',
    flag: '🇮🇹',   sdbLeagueId: 4332,
    accentColor: Color(0xFF0066CC), category: 'Europe',
  ),
  Competition(
    code: 'BL1',  name: 'Bundesliga',        country: 'Germany',
    flag: '🇩🇪',   sdbLeagueId: 4331,
    accentColor: Color(0xFFE30614), category: 'Europe',
  ),
  Competition(
    code: 'FL1',  name: 'Ligue 1',           country: 'France',
    flag: '🇫🇷',   sdbLeagueId: 4334,
    accentColor: Color(0xFF003087), category: 'Europe',
  ),
  Competition(
    code: 'CL',   name: 'Champions League',  country: 'Europe',
    flag: '🇪🇺',   sdbLeagueId: 4480,
    accentColor: Color(0xFF001E62), category: 'Europe',
  ),
  Competition(
    code: 'EL',   name: 'Europa League',     country: 'Europe',
    flag: '🇪🇺',   sdbLeagueId: 4481,
    accentColor: Color(0xFFF05000), category: 'Europe',
  ),
  Competition(
    code: 'EC',   name: 'Euros',             country: 'Europe',
    flag: '🇪🇺',   sdbLeagueId: 4379,
    accentColor: Color(0xFF003087), category: 'World',
  ),
  Competition(
    code: 'WC',   name: 'World Cup',         country: 'World',
    flag: '🌍',   sdbLeagueId: 4429,
    accentColor: Color(0xFF003087), category: 'World',
  ),
  Competition(
    code: 'PPL',  name: 'Primeira Liga',     country: 'Portugal',
    flag: '🇵🇹',   sdbLeagueId: 4344,
    accentColor: Color(0xFF006600), category: 'Europe',
  ),
  Competition(
    code: 'DED',  name: 'Eredivisie',        country: 'Netherlands',
    flag: '🇳🇱',   sdbLeagueId: 4337,
    accentColor: Color(0xFFFF6600), category: 'Europe',
  ),
  Competition(
    code: 'BSA',  name: 'Brasileirao',       country: 'Brazil',
    flag: '🇧🇷',   sdbLeagueId: 4351,
    accentColor: Color(0xFF009C3B), category: 'Americas',
  ),
];

// ══════════════════════════════════════════════════════════════════
//  MODELS
// ══════════════════════════════════════════════════════════════════

class FdMatch {
  final int id;
  final DateTime utcDate;
  final String status; // SCHEDULED | LIVE | IN_PLAY | PAUSED | FINISHED | POSTPONED
  final int? minute;
  final int? matchday;
  final String? stage;
  final String? group;
  final FdTeam home;
  final FdTeam away;
  final int? homeScore;
  final int? awayScore;
  final int? homeHT;
  final int? awayHT;
  final String? refereeNames;
  final String? venue;

  bool get isLive =>
      status == 'IN_PLAY' || status == 'PAUSED' || status == 'LIVE';
  bool get isFinished => status == 'FINISHED';
  bool get isScheduled =>
      status == 'SCHEDULED' || status == 'TIMED';
  bool get isPostponed =>
      status == 'POSTPONED' || status == 'CANCELLED' || status == 'SUSPENDED';

  const FdMatch({
    required this.id,
    required this.utcDate,
    required this.status,
    this.minute,
    this.matchday,
    this.stage,
    this.group,
    required this.home,
    required this.away,
    this.homeScore,
    this.awayScore,
    this.homeHT,
    this.awayHT,
    this.refereeNames,
    this.venue,
  });

  factory FdMatch.fromJson(Map<String, dynamic> j) {
    final score = j['score'] as Map<String, dynamic>? ?? {};
    final ft = score['fullTime'] as Map<String, dynamic>? ?? {};
    final ht = score['halfTime'] as Map<String, dynamic>? ?? {};
    final refs = (j['referees'] as List?)
        ?.map((r) => r['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    return FdMatch(
      id: j['id'] as int,
      utcDate: DateTime.parse(j['utcDate'] as String).toLocal(),
      status: j['status'] as String? ?? 'SCHEDULED',
      minute: (j['minute'] as int?),
      matchday: (j['matchday'] as int?),
      stage: j['stage'] as String?,
      group: j['group'] as String?,
      home: FdTeam.fromJson(j['homeTeam'] as Map<String, dynamic>),
      away: FdTeam.fromJson(j['awayTeam'] as Map<String, dynamic>),
      homeScore: ft['home'] as int?,
      awayScore: ft['away'] as int?,
      homeHT: ht['home'] as int?,
      awayHT: ht['away'] as int?,
      refereeNames: refs?.isNotEmpty == true ? refs : null,
    );
  }
}

class FdTeam {
  final int id;
  final String name;
  final String shortName;
  final String? crest; // from football-data (SVG)
  String? badge;       // from TheSportsDB (PNG)

  FdTeam({
    required this.id,
    required this.name,
    required this.shortName,
    this.crest,
    this.badge,
  });

  factory FdTeam.fromJson(Map<String, dynamic> j) {
    return FdTeam(
      id: (j['id'] as int?) ?? 0,
      name: j['name'] as String? ?? 'TBD',
      shortName: j['shortName'] as String? ??
          j['tla'] as String? ??
          (j['name'] as String? ?? 'TBD'),
      crest: j['crest'] as String?,
    );
  }
}

class FdStanding {
  final int position;
  final FdTeam team;
  final int playedGames;
  final int won;
  final int draw;
  final int lost;
  final int points;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final String? form; // "W,W,D,L,W"

  const FdStanding({
    required this.position,
    required this.team,
    required this.playedGames,
    required this.won,
    required this.draw,
    required this.lost,
    required this.points,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    this.form,
  });

  factory FdStanding.fromJson(Map<String, dynamic> j) {
    return FdStanding(
      position: j['position'] as int,
      team: FdTeam.fromJson(j['team'] as Map<String, dynamic>),
      playedGames: j['playedGames'] as int? ?? 0,
      won: j['won'] as int? ?? 0,
      draw: j['draw'] as int? ?? 0,
      lost: j['lost'] as int? ?? 0,
      points: j['points'] as int? ?? 0,
      goalsFor: j['goalsFor'] as int? ?? 0,
      goalsAgainst: j['goalsAgainst'] as int? ?? 0,
      goalDifference: j['goalDifference'] as int? ?? 0,
      form: j['form'] as String?,
    );
  }
}

class FdStandingsGroup {
  final String stage;
  final String? group;
  final List<FdStanding> rows;

  const FdStandingsGroup({
    required this.stage,
    this.group,
    required this.rows,
  });
}

class FdCompetitionInfo {
  final int id;
  final String name;
  final String? emblem;
  final String? currentSeason;

  const FdCompetitionInfo({
    required this.id,
    required this.name,
    this.emblem,
    this.currentSeason,
  });
}

// ══════════════════════════════════════════════════════════════════
//  SPORTS DATA SERVICE
// ══════════════════════════════════════════════════════════════════
class SportsDataService {
  // ── In-memory cache ──
  static final Map<String, dynamic> _cache = {};

  static Map<String, String> get _fdHeaders => {
        'X-Auth-Token': kFootballDataToken,
        'Content-Type': 'application/json',
      };

  // ── football-data.org GET ──
  static Future<Map<String, dynamic>?> _fdGet(String path) async {
    if (_cache.containsKey(path)) return _cache[path];
    try {
      final res = await http
          .get(Uri.parse('$_fdBase$path'), headers: _fdHeaders)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _cache[path] = data;
        return data;
      }
      debugPrint('[FD] ${res.statusCode} $path');
    } catch (e) {
      debugPrint('[FD] error $path: $e');
    }
    return null;
  }

  // ── TheSportsDB GET ──
  static Future<Map<String, dynamic>?> _sdbGet(String path) async {
    final url = '$_sdbBase$path';
    if (_cache.containsKey(url)) return _cache[url];
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _cache[url] = data;
        return data;
      }
    } catch (e) {
      debugPrint('[SDB] error $path: $e');
    }
    return null;
  }

  // ══════════════════════════════════════════════════
  //  COMPETITION INFO
  // ══════════════════════════════════════════════════
  static Future<FdCompetitionInfo?> fetchCompetitionInfo(
      String code) async {
    final data = await _fdGet('/competitions/$code');
    if (data == null) return null;
    return FdCompetitionInfo(
      id: data['id'] as int,
      name: data['name'] as String? ?? code,
      emblem: data['emblem'] as String?,
      currentSeason: (data['currentSeason']
              as Map<String, dynamic>?)?['startDate'] as String?,
    );
  }

  // ══════════════════════════════════════════════════
  //  FIXTURES — next + last 10
  // ══════════════════════════════════════════════════
  static Future<List<FdMatch>> fetchNextMatches(String code,
      {int limit = 10}) async {
    final data = await _fdGet(
        '/competitions/$code/matches?status=SCHEDULED&limit=$limit');
    if (data == null) return [];
    return _parseMatches(data);
  }

  static Future<List<FdMatch>> fetchLastMatches(String code,
      {int limit = 10}) async {
    final data = await _fdGet(
        '/competitions/$code/matches?status=FINISHED&limit=$limit');
    if (data == null) return [];
    final matches = _parseMatches(data);
    // reverse so most recent first
    return matches.reversed.toList();
  }

  static Future<List<FdMatch>> fetchLiveMatches(String code) async {
    final data = await _fdGet(
        '/competitions/$code/matches?status=IN_PLAY,PAUSED,LIVE');
    if (data == null) return [];
    return _parseMatches(data);
  }

  static Future<List<FdMatch>> fetchMatchesByMatchday(
      String code, int matchday) async {
    final data = await _fdGet(
        '/competitions/$code/matches?matchday=$matchday');
    if (data == null) return [];
    return _parseMatches(data);
  }

  /// Combined: live first, then next scheduled, then last results
  static Future<Map<String, List<FdMatch>>> fetchAllFixtureGroups(
      String code) async {
    final results = await Future.wait([
      fetchLiveMatches(code),
      fetchNextMatches(code, limit: 10),
      fetchLastMatches(code, limit: 10),
    ]);
    return {
      'live': results[0],
      'upcoming': results[1],
      'results': results[2],
    };
  }

  static List<FdMatch> _parseMatches(Map<String, dynamic> data) {
    final list = data['matches'] as List? ?? [];
    return list.map((e) => FdMatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ══════════════════════════════════════════════════
  //  STANDINGS
  // ══════════════════════════════════════════════════
  static Future<List<FdStandingsGroup>> fetchStandings(
      String code) async {
    final data = await _fdGet('/competitions/$code/standings');
    if (data == null) return [];

    final standingsRaw =
        data['standings'] as List? ?? [];
    return standingsRaw.map((g) {
      final rows = (g['table'] as List? ?? [])
          .map((r) => FdStanding.fromJson(r as Map<String, dynamic>))
          .toList();
      return FdStandingsGroup(
        stage: g['stage'] as String? ?? 'REGULAR_SEASON',
        group: g['group'] as String?,
        rows: rows,
      );
    }).toList();
  }

  // ══════════════════════════════════════════════════
  //  TOP SCORERS
  // ══════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> fetchTopScorers(
      String code, {int limit = 10}) async {
    final data = await _fdGet(
        '/competitions/$code/scorers?limit=$limit');
    if (data == null) return [];
    return ((data['scorers'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
  }

  // ══════════════════════════════════════════════════
  //  TheSportsDB — fetch badge PNG for a team by name
  // ══════════════════════════════════════════════════
  static Future<String?> fetchTeamBadge(String teamName) async {
    final encoded = Uri.encodeComponent(teamName);
    final data = await _sdbGet('/searchteams.php?t=$encoded');
    if (data == null) return null;
    final teams = data['teams'] as List?;
    if (teams == null || teams.isEmpty) return null;
    return teams.first['strTeamBadge'] as String?;
  }

  /// Batch fetch badges for a list of FdTeam — enriches in place
  static Future<void> enrichTeamBadges(List<FdTeam> teams) async {
    // TheSportsDB free key: 30 req/min — use sequential with tiny delay
    for (final team in teams) {
      if (team.badge != null) continue;
      final badge = await fetchTeamBadge(team.name);
      team.badge = badge;
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  // ── fetch league badge from TheSportsDB ──
  static Future<String?> fetchLeagueBadge(int sdbId) async {
    final data = await _sdbGet('/lookupleague.php?id=$sdbId');
    if (data == null) return null;
    final leagues = data['leagues'] as List?;
    if (leagues == null || leagues.isEmpty) return null;
    return leagues.first['strLogo'] as String? ??
        leagues.first['strBadge'] as String?;
  }

  // ── fetch league table (TheSportsDB, for badge-enriched view) ──
  static Future<List<Map<String, dynamic>>?> fetchSdbTable(
      int sdbId) async {
    final data = await _sdbGet('/lookuptable.php?l=$sdbId');
    if (data == null) return null;
    return ((data['table'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  // ── clear cache (call on refresh) ──
  static void clearCache() => _cache.clear();
}*/


import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ══════════════════════════════════════════════════════════════════
//  API KEYS & BASE URLS
// ══════════════════════════════════════════════════════════════════
const String kFootballDataToken = '8f20a99899cd4b3ba24ceaf629fff3d0';
const String kSportsDbKey = '123'; // free key

const String _fdBase = 'https://api.football-data.org/v4';
const String _sdbBase = 'https://www.thesportsdb.com/api/v1/json/$kSportsDbKey';

// ══════════════════════════════════════════════════════════════════
//  COMPETITION CATALOGUE
//  Maps football-data competition codes → TheSportsDB league IDs
// ══════════════════════════════════════════════════════════════════
class Competition {
  final String code;          // football-data code e.g. "PL"
  final String name;
  final String country;
  final String flag;          // emoji
  final int sdbLeagueId;      // TheSportsDB idLeague
  final Color accentColor;
  final String category;      // "Europe" | "Africa" | "World" | "Americas"

  const Competition({
    required this.code,
    required this.name,
    required this.country,
    required this.flag,
    required this.sdbLeagueId,
    required this.accentColor,
    required this.category,
  });
}

const List<Competition> kCompetitions = [
  Competition(
    code: 'PL',   name: 'Premier League',    country: 'England',
    flag: '🏴󠁧󠁢󠁥󠁮󠁧󠁿', sdbLeagueId: 4328,
    accentColor: Color(0xFF3D195B), category: 'Europe',
  ),
  Competition(
    code: 'PD',   name: 'La Liga',           country: 'Spain',
    flag: '🇪🇸',   sdbLeagueId: 4335,
    accentColor: Color(0xFFFF4B44), category: 'Europe',
  ),
  Competition(
    code: 'SA',   name: 'Serie A',           country: 'Italy',
    flag: '🇮🇹',   sdbLeagueId: 4332,
    accentColor: Color(0xFF0066CC), category: 'Europe',
  ),
  Competition(
    code: 'BL1',  name: 'Bundesliga',        country: 'Germany',
    flag: '🇩🇪',   sdbLeagueId: 4331,
    accentColor: Color(0xFFE30614), category: 'Europe',
  ),
  Competition(
    code: 'FL1',  name: 'Ligue 1',           country: 'France',
    flag: '🇫🇷',   sdbLeagueId: 4334,
    accentColor: Color(0xFF003087), category: 'Europe',
  ),
  Competition(
    code: 'CL',   name: 'Champions League',  country: 'Europe',
    flag: '🇪🇺',   sdbLeagueId: 4480,
    accentColor: Color(0xFF001E62), category: 'Europe',
  ),
  Competition(
    code: 'EL',   name: 'Europa League',     country: 'Europe',
    flag: '🇪🇺',   sdbLeagueId: 4481,
    accentColor: Color(0xFFF05000), category: 'Europe',
  ),
  Competition(
    code: 'EC',   name: 'Euros',             country: 'Europe',
    flag: '🇪🇺',   sdbLeagueId: 4379,
    accentColor: Color(0xFF003087), category: 'World',
  ),
  Competition(
    code: 'WC',   name: 'World Cup',         country: 'World',
    flag: '🌍',   sdbLeagueId: 4429,
    accentColor: Color(0xFF003087), category: 'World',
  ),
  Competition(
    code: 'PPL',  name: 'Primeira Liga',     country: 'Portugal',
    flag: '🇵🇹',   sdbLeagueId: 4344,
    accentColor: Color(0xFF006600), category: 'Europe',
  ),
  Competition(
    code: 'DED',  name: 'Eredivisie',        country: 'Netherlands',
    flag: '🇳🇱',   sdbLeagueId: 4337,
    accentColor: Color(0xFFFF6600), category: 'Europe',
  ),
  Competition(
    code: 'BSA',  name: 'Brasileirao',       country: 'Brazil',
    flag: '🇧🇷',   sdbLeagueId: 4351,
    accentColor: Color(0xFF009C3B), category: 'Americas',
  ),
];

// ══════════════════════════════════════════════════════════════════
//  MODELS
// ══════════════════════════════════════════════════════════════════

class FdMatch {
  final int id;
  final DateTime utcDate;
  final String status; // SCHEDULED | LIVE | IN_PLAY | PAUSED | FINISHED | POSTPONED
  final int? minute;
  final int? matchday;
  final String? stage;
  final String? group;
  final FdTeam home;
  final FdTeam away;
  final int? homeScore;
  final int? awayScore;
  final int? homeHT;
  final int? awayHT;
  final String? refereeNames;
  final String? venue;

  bool get isLive =>
      status == 'IN_PLAY' || status == 'PAUSED' || status == 'LIVE';
  bool get isFinished => status == 'FINISHED';
  bool get isScheduled =>
      status == 'SCHEDULED' || status == 'TIMED';
  bool get isPostponed =>
      status == 'POSTPONED' || status == 'CANCELLED' || status == 'SUSPENDED';

  const FdMatch({
    required this.id,
    required this.utcDate,
    required this.status,
    this.minute,
    this.matchday,
    this.stage,
    this.group,
    required this.home,
    required this.away,
    this.homeScore,
    this.awayScore,
    this.homeHT,
    this.awayHT,
    this.refereeNames,
    this.venue,
  });

  factory FdMatch.fromJson(Map<String, dynamic> j) {
    final score = j['score'] as Map<String, dynamic>? ?? {};
    final ft = score['fullTime'] as Map<String, dynamic>? ?? {};
    final ht = score['halfTime'] as Map<String, dynamic>? ?? {};
    final refs = (j['referees'] as List?)
        ?.map((r) => r['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    return FdMatch(
      id: j['id'] as int,
      utcDate: DateTime.parse(j['utcDate'] as String).toLocal(),
      status: j['status'] as String? ?? 'SCHEDULED',
      minute: (j['minute'] as int?),
      matchday: (j['matchday'] as int?),
      stage: j['stage'] as String?,
      group: j['group'] as String?,
      home: FdTeam.fromJson(j['homeTeam'] as Map<String, dynamic>),
      away: FdTeam.fromJson(j['awayTeam'] as Map<String, dynamic>),
      homeScore: ft['home'] as int?,
      awayScore: ft['away'] as int?,
      homeHT: ht['home'] as int?,
      awayHT: ht['away'] as int?,
      refereeNames: refs?.isNotEmpty == true ? refs : null,
    );
  }
}

class FdTeam {
  final int id;
  final String name;
  final String shortName;
  final String? crest; // from football-data (SVG)
  String? badge;       // from TheSportsDB (PNG)

  FdTeam({
    required this.id,
    required this.name,
    required this.shortName,
    this.crest,
    this.badge,
  });

  factory FdTeam.fromJson(Map<String, dynamic> j) {
    return FdTeam(
      id: (j['id'] as int?) ?? 0,
      name: j['name'] as String? ?? 'TBD',
      shortName: j['shortName'] as String? ??
          j['tla'] as String? ??
          (j['name'] as String? ?? 'TBD'),
      crest: j['crest'] as String?,
    );
  }
}

class FdStanding {
  final int position;
  final FdTeam team;
  final int playedGames;
  final int won;
  final int draw;
  final int lost;
  final int points;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDifference;
  final String? form; // "W,W,D,L,W"

  const FdStanding({
    required this.position,
    required this.team,
    required this.playedGames,
    required this.won,
    required this.draw,
    required this.lost,
    required this.points,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDifference,
    this.form,
  });

  factory FdStanding.fromJson(Map<String, dynamic> j) {
    return FdStanding(
      position: j['position'] as int,
      team: FdTeam.fromJson(j['team'] as Map<String, dynamic>),
      playedGames: j['playedGames'] as int? ?? 0,
      won: j['won'] as int? ?? 0,
      draw: j['draw'] as int? ?? 0,
      lost: j['lost'] as int? ?? 0,
      points: j['points'] as int? ?? 0,
      goalsFor: j['goalsFor'] as int? ?? 0,
      goalsAgainst: j['goalsAgainst'] as int? ?? 0,
      goalDifference: j['goalDifference'] as int? ?? 0,
      form: j['form'] as String?,
    );
  }
}

class FdStandingsGroup {
  final String stage;
  final String? group;
  final List<FdStanding> rows;

  const FdStandingsGroup({
    required this.stage,
    this.group,
    required this.rows,
  });
}

class FdCompetitionInfo {
  final int id;
  final String name;
  final String? emblem;
  final String? currentSeason;

  const FdCompetitionInfo({
    required this.id,
    required this.name,
    this.emblem,
    this.currentSeason,
  });
}

// ══════════════════════════════════════════════════════════════════
//  SPORTS DATA SERVICE (ENHANCED WITH DEBUG LOGGING)
// ══════════════════════════════════════════════════════════════════
class SportsDataService {
  // ── In-memory cache ──
  static final Map<String, dynamic> _cache = {};

  static Map<String, String> get _fdHeaders => {
        'X-Auth-Token': kFootballDataToken,
        'Content-Type': 'application/json',
      };

  // ── football-data.org GET (with enhanced error logging) ──
 // ── football-data.org GET (with retry & longer timeout) ──
static Future<Map<String, dynamic>?> _fdGet(String path) async {
  if (_cache.containsKey(path)) {
    debugPrint('✅ [FD CACHE HIT] $path');
    return _cache[path];
  }

  int retries = 0;
  const maxRetries = 2;
  const timeoutDuration = Duration(seconds: 30); // Increased from 15 to 30

  while (retries <= maxRetries) {
    try {
      debugPrint('🔄 [FD REQUEST ATTEMPT ${retries + 1}/$maxRetries] GET $_fdBase$path');
      
      final res = await http
          .get(
            Uri.parse('$_fdBase$path'),
            headers: _fdHeaders,
          )
          .timeout(
            timeoutDuration,
            onTimeout: () {
              debugPrint('⏱️ [FD TIMEOUT on attempt ${retries + 1}] $path');
              throw TimeoutException('API call timed out after $timeoutDuration');
            },
          );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _cache[path] = data;
        debugPrint('✅ [FD SUCCESS] ${res.statusCode} $path');
        return data;
      } else if (res.statusCode == 429) {
        // Rate limited - wait and retry
        debugPrint('🚫 [FD RATE LIMITED] Waiting 60 seconds before retry...');
        await Future.delayed(const Duration(seconds: 60));
        retries++;
        continue;
      } else {
        debugPrint('❌ [FD ERROR ${res.statusCode}] $path');
        return null;
      }
    } on TimeoutException catch (e) {
      retries++;
      if (retries > maxRetries) {
        debugPrint('❌ [FD TIMEOUT - FINAL] $path: $e');
        return null;
      }
      // Wait before retrying
      await Future.delayed(Duration(seconds: 5 * retries));
    } catch (e) {
      debugPrint('❌ [FD EXCEPTION] $path: $e');
      return null;
    }
  }

  return null;
}
  // ── TheSportsDB GET ──
  static Future<Map<String, dynamic>?> _sdbGet(String path) async {
    final url = '$_sdbBase$path';
    if (_cache.containsKey(url)) {
      debugPrint('✓ [SDB CACHE HIT] $path');
      return _cache[url];
    }
    try {
      debugPrint('🔄 [SDB REQUEST] GET $url');
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _cache[url] = data;
        debugPrint('✅ [SDB SUCCESS] Cached: $path');
        return data;
      } else {
        debugPrint('❌ [SDB ERROR ${res.statusCode}] $path');
      }
    } catch (e) {
      debugPrint('❌ [SDB EXCEPTION] $path: $e');
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════
  //  COMPETITION INFO
  // ══════════════════════════════════════════════════════════════════
  static Future<FdCompetitionInfo?> fetchCompetitionInfo(
      String code) async {
    debugPrint('📊 Fetching competition info for: $code');
    final data = await _fdGet('/competitions/$code');
    if (data == null) return null;
    return FdCompetitionInfo(
      id: data['id'] as int,
      name: data['name'] as String? ?? code,
      emblem: data['emblem'] as String?,
      currentSeason: (data['currentSeason']
              as Map<String, dynamic>?)?['startDate'] as String?,
    );
  }

  // ══════════════════════════════════════════════════════════════════
  //  FIXTURES — next + last 10
  // ══════════════════════════════════════════════════════════════════
  static Future<List<FdMatch>> fetchNextMatches(String code,
      {int limit = 10}) async {
    debugPrint('🔮 Fetching next $limit matches for: $code');
    final data = await _fdGet(
        '/competitions/$code/matches?status=SCHEDULED&limit=$limit');
    if (data == null) return [];
    return _parseMatches(data);
  }

  static Future<List<FdMatch>> fetchLastMatches(String code,
      {int limit = 10}) async {
    debugPrint('📜 Fetching last $limit matches for: $code');
    final data = await _fdGet(
        '/competitions/$code/matches?status=FINISHED&limit=$limit');
    if (data == null) return [];
    final matches = _parseMatches(data);
    return matches.reversed.toList();
  }

  static Future<List<FdMatch>> fetchLiveMatches(String code) async {
    debugPrint('🔴 Fetching live matches for: $code');
    final data = await _fdGet(
        '/competitions/$code/matches?status=IN_PLAY,PAUSED,LIVE');
    if (data == null) return [];
    return _parseMatches(data);
  }

  static Future<List<FdMatch>> fetchMatchesByMatchday(
      String code, int matchday) async {
    debugPrint('📅 Fetching matchday $matchday for: $code');
    final data = await _fdGet(
        '/competitions/$code/matches?matchday=$matchday');
    if (data == null) return [];
    return _parseMatches(data);
  }

  /// Combined: live first, then next scheduled, then last results
  static Future<Map<String, List<FdMatch>>> fetchAllFixtureGroups(
      String code) async {
    debugPrint('🎯 Fetching all fixture groups for: $code');
    final results = await Future.wait([
      fetchLiveMatches(code),
      fetchNextMatches(code, limit: 10),
      fetchLastMatches(code, limit: 10),
    ]);
    return {
      'live': results[0],
      'upcoming': results[1],
      'results': results[2],
    };
  }

  static List<FdMatch> _parseMatches(Map<String, dynamic> data) {
    final list = data['matches'] as List? ?? [];
    debugPrint('   → Parsed ${list.length} matches');
    return list.map((e) => FdMatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ══════════════════════════════════════════════════════════════════
  //  STANDINGS
  // ══════════════════════════════════════════════════════════════════
  static Future<List<FdStandingsGroup>> fetchStandings(
      String code) async {
    debugPrint('🏆 Fetching standings for: $code');
    final data = await _fdGet('/competitions/$code/standings');
    if (data == null) return [];

    final standingsRaw =
        data['standings'] as List? ?? [];
    debugPrint('   → Parsed ${standingsRaw.length} standing groups');
    return standingsRaw.map((g) {
      final rows = (g['table'] as List? ?? [])
          .map((r) => FdStanding.fromJson(r as Map<String, dynamic>))
          .toList();
      return FdStandingsGroup(
        stage: g['stage'] as String? ?? 'REGULAR_SEASON',
        group: g['group'] as String?,
        rows: rows,
      );
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════
  //  TOP SCORERS
  // ══════════════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> fetchTopScorers(
      String code, {int limit = 10}) async {
    debugPrint('⚽ Fetching top $limit scorers for: $code');
    final data = await _fdGet(
        '/competitions/$code/scorers?limit=$limit');
    if (data == null) return [];
    return ((data['scorers'] as List?) ?? [])
        .cast<Map<String, dynamic>>();
  }

  // ══════════════════════════════════════════════════════════════════
  //  TheSportsDB — fetch badge PNG for a team by name
  // ══════════════════════════════════════════════════════════════════
  static Future<String?> fetchTeamBadge(String teamName) async {
    final encoded = Uri.encodeComponent(teamName);
    final data = await _sdbGet('/searchteams.php?t=$encoded');
    if (data == null) return null;
    final teams = data['teams'] as List?;
    if (teams == null || teams.isEmpty) return null;
    return teams.first['strTeamBadge'] as String?;
  }

  /// Batch fetch badges for a list of FdTeam — enriches in place
  static Future<void> enrichTeamBadges(List<FdTeam> teams) async {
    debugPrint('🎫 Enriching ${teams.length} team badges from TheSportsDB');
    for (final team in teams) {
      if (team.badge != null) continue;
      final badge = await fetchTeamBadge(team.name);
      team.badge = badge;
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  // ── fetch league badge from TheSportsDB ──
  static Future<String?> fetchLeagueBadge(int sdbId) async {
    debugPrint('🏅 Fetching league badge from TheSportsDB (ID: $sdbId)');
    final data = await _sdbGet('/lookupleague.php?id=$sdbId');
    if (data == null) return null;
    final leagues = data['leagues'] as List?;
    if (leagues == null || leagues.isEmpty) return null;
    return leagues.first['strLogo'] as String? ??
        leagues.first['strBadge'] as String?;
  }

  // ── fetch league table (TheSportsDB, for badge-enriched view) ──
  static Future<List<Map<String, dynamic>>?> fetchSdbTable(
      int sdbId) async {
    debugPrint('📋 Fetching league table from TheSportsDB (ID: $sdbId)');
    final data = await _sdbGet('/lookuptable.php?l=$sdbId');
    if (data == null) return null;
    return ((data['table'] as List?) ?? []).cast<Map<String, dynamic>>();
  }

  // ── clear cache (call on refresh) ──
  static void clearCache() {
    debugPrint('🗑️ Clearing API cache (${_cache.length} entries)');
    _cache.clear();
  }
}
