import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamInfo {
  final String id;
  final String name;
  final String logoUrl;

  TeamInfo({required this.id, required this.name, required this.logoUrl});
}

class TeamCacheService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache
  final Map<String, TeamInfo> _cache = {};

  // Per-team stream controllers to notify UI of updates
  final Map<String, StreamController<TeamInfo>> _controllers = {};

  // Singleton-like pattern (optional)
  TeamCacheService._privateConstructor();
  static final TeamCacheService instance = TeamCacheService._privateConstructor();

  /// Returns cached info if present, otherwise fetches once and caches.
  Future<TeamInfo?> getTeam(String teamId) async {
    if (_cache.containsKey(teamId)) {
      return _cache[teamId];
    }
    final doc = await _firestore.collection('teams').doc(teamId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    final info = TeamInfo(
      id: teamId,
      name: (data['name'] as String?) ?? teamId,
      logoUrl: (data['logoUrl'] as String?) ?? '',
    );
    _cache[teamId] = info;
    // set up listener to keep cache updated
    _subscribeToTeamDoc(teamId);
    return info;
  }

  /// Prefetch multiple teams in batch (parallel fetch). Useful when standings snapshot arrives.
  Future<void> prefetchTeams(List<String> teamIds) async {
    final toFetch = teamIds.where((id) => !_cache.containsKey(id)).toList();
    if (toFetch.isEmpty) return;
    // Use batched get via future list
    final futures = toFetch.map((id) => _firestore.collection('teams').doc(id).get()).toList();
    final docs = await Future.wait(futures);
    for (final doc in docs) {
      if (!doc.exists) continue;
      final id = doc.id;
      final data = doc.data() as Map<String, dynamic>;
      final info = TeamInfo(
        id: id,
        name: (data['name'] as String?) ?? id,
        logoUrl: (data['logoUrl'] as String?) ?? '',
      );
      _cache[id] = info;
      _subscribeToTeamDoc(id);
      _controllers[id]?.add(info);
    }
  }

  /// Returns a broadcast stream for a team's updates. The stream emits once when data is available,
  /// and subsequently whenever the team's document changes.
  Stream<TeamInfo?> teamStream(String teamId) {
    if (!_controllers.containsKey(teamId)) {
      _controllers[teamId] = StreamController<TeamInfo>.broadcast(onListen: () async {
        final info = await getTeam(teamId);
        if (info != null) _controllers[teamId]!.add(info);
      });
    } else {
      // ensure initial data is emitted
      Future.microtask(() async {
        final info = await getTeam(teamId);
        if (info != null && !_controllers[teamId]!.isClosed) _controllers[teamId]!.add(info);
      });
    }
    return _controllers[teamId]!.stream.map<TeamInfo?>((i) => i);
  }

  void _subscribeToTeamDoc(String teamId) {
    // If already subscribed, skip
    final controller = _controllers.putIfAbsent(teamId, () => StreamController<TeamInfo>.broadcast());
    // Avoid multiple subscriptions
    if (controller.hasListener) return;
    // create a listener on the doc to keep cache up to date and push updates
    _firestore.collection('teams').doc(teamId).snapshots().listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final info = TeamInfo(
        id: teamId,
        name: (data['name'] as String?) ?? teamId,
        logoUrl: (data['logoUrl'] as String?) ?? '',
      );
      _cache[teamId] = info;
      if (!controller.isClosed) controller.add(info);
    });
  }

  /// Dispose controllers when not needed (call during app shutdown if desired).
  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
    _cache.clear();
  }
}