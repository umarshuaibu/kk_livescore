import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StandingsCache {
  // Simple file cache: writes JSON files per league
  Future<Directory> _cacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final cdir = Directory('${dir.path}/standings_cache');
    if (!await cdir.exists()) await cdir.create(recursive: true);
    return cdir;
  }

  Future<File> _fileForLeague(String leagueId) async {
    final d = await _cacheDir();
    return File('${d.path}/$leagueId.json');
  }

  Future<void> write(String leagueId, Map<String, dynamic> json) async {
    try {
      final f = await _fileForLeague(leagueId);
      await f.writeAsString(jsonEncode(json), flush: true);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> read(String leagueId) async {
    try {
      final f = await _fileForLeague(leagueId);
      if (!await f.exists()) return null;
      final s = await f.readAsString();
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}