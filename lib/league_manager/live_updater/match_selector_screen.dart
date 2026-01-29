// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kklivescoreadmin/league_manager/live_updater/live_updater_screen.dart';
import 'package:kklivescoreadmin/firebase_options.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';

/// ✅ Global Navigator Key (Fix)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// ✅ Initialize Firebase BEFORE using Firestore
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

/// Wrapper App to attach navigatorKey
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KK LiveScore Admin',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primaryColor: AppColors.primaryColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.whiteColor,
          foregroundColor: Colors.black,
        ),
      ),
      home: const MatchSelectorScreen(),
      scrollBehavior: kIsWeb ? const MaterialScrollBehavior().copyWith(scrollbars: true) : null,
    );
  }
}

class MatchSelectorScreen extends StatefulWidget {
  const MatchSelectorScreen({super.key});

  @override
  State<MatchSelectorScreen> createState() => _MatchSelectorScreenState();
}

class _MatchDateBadge extends StatelessWidget {
  final DateTime date;
  final bool compact;

  const _MatchDateBadge(this.date, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        DateFormat.MMMd().format(date),
        style: TextStyle(
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

const int _pageSize = 8;

DocumentSnapshot? _lastMatchDoc;
bool _isLoadingMore = false;
bool _hasMore = true;

final Map<String, String> _teamNameCache = {};

class _MatchSelectorScreenState extends State<MatchSelectorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedLeagueId;
  String? _selectedMatchId;
  String? _teamAId;
  String? _teamBId;
  String? _teamAName;
  String? _teamBName;

  List<Map<String, dynamic>> _teamAPlayers = [];
  List<Map<String, dynamic>> _teamBPlayers = [];

  List<Map<String, dynamic>> _selectedTeamAPlayers = [];
  List<Map<String, dynamic>> _selectedTeamBPlayers = [];

  bool _loading = false;

  // Manual paging state for matches
  final List<QueryDocumentSnapshot> _matchDocs = [];
  StreamSubscription<QuerySnapshot>? _matchesSubscription;
  bool _matchesLoading = false;
  bool _matchesError = false;
  String? _matchesErrorMessage;

  Future<List<Map<String, dynamic>>> _fetchPlayersByIds(List<dynamic> ids) async {
    if (ids.isEmpty) return [];
    // Firestore 'whereIn' supports up to 10 elements. If your players list can be larger,
    // you should split into batches. For now we keep original behavior.
    final snapshot = await _firestore
        .collection("players")
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    return snapshot.docs
        .map((doc) => {"id": doc.id, "name": doc["name"]})
        .toList();
  }

  Future<String> _getTeamName(String teamId) async {
    if (_teamNameCache.containsKey(teamId)) {
      return _teamNameCache[teamId]!;
    }

    final doc = await _firestore.collection("teams").doc(teamId).get();
    final name = doc.data()?["name"] ?? "Unknown";

    _teamNameCache[teamId] = name;
    return name;
  }

  Future<void> _loadMatchDetails(String leagueId, String matchId) async {
    try {
      final matchDoc = await _firestore
          .collection("leagues")
          .doc(leagueId)
          .collection("matches")
          .doc(matchId)
          .get();

      if (matchDoc.exists) {
        final data = matchDoc.data()!;
        _teamAId = data["teamAId"];
        _teamBId = data["teamBId"];

        // Safely handle missing team docs
        final teamADocSnapshot =
            await _firestore.collection("teams").doc(_teamAId).get();
        final teamBDocSnapshot =
            await _firestore.collection("teams").doc(_teamBId).get();

        _teamAName = teamADocSnapshot.data()?["name"] ?? "Unknown";
        _teamBName = teamBDocSnapshot.data()?["name"] ?? "Unknown";

        final List<dynamic> playersAIds = teamADocSnapshot.data()?["players"] ?? [];
        final List<dynamic> playersBIds = teamBDocSnapshot.data()?["players"] ?? [];

        final playersA = await _fetchPlayersByIds(playersAIds);
        final playersB = await _fetchPlayersByIds(playersBIds);

        if (mounted) {
          setState(() {
            _teamAPlayers = playersA;
            _teamBPlayers = playersB;
          });
        }
      } else {
        // If match doc doesn't exist, clear state
        if (mounted) {
          setState(() {
            _teamAId = null;
            _teamBId = null;
            _teamAName = null;
            _teamBName = null;
            _teamAPlayers = [];
            _teamBPlayers = [];
          });
        }
      }
    } catch (e, st) {
      // Log and show error safely
      debugPrint("Error loading match details: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load match details.')),
        );
      }
    }
  }

  Future<void> _saveLineups() async {
    if (_selectedLeagueId == null || _selectedMatchId == null) return;

    setState(() => _loading = true);

    final matchRef = _firestore
        .collection("leagues")
        .doc(_selectedLeagueId)
        .collection("matches")
        .doc(_selectedMatchId);

    try {
      if (_selectedTeamAPlayers.isNotEmpty && _teamAId != null) {
        await matchRef
            .collection("lineups")
            .doc(_teamAId)
            .set({"teamId": _teamAId, "players": _selectedTeamAPlayers});
      }
      if (_selectedTeamBPlayers.isNotEmpty && _teamBId != null) {
        await matchRef
            .collection("lineups")
            .doc(_teamBId)
            .set({"teamId": _teamBId, "players": _selectedTeamBPlayers});
      }
    } catch (e) {
      debugPrint("Error saving lineups: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save lineups.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (mounted) {
      // Use navigatorKey to ensure proper navigation on web
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LiveUpdaterScreen(
            leagueId: _selectedLeagueId!,
            matchId: _selectedMatchId!,
          ),
        ),
      );
    }
  }

  // ------ Manual paging & realtime subscription helpers ------

  Query _matchesBaseQuery(String leagueId) {
    return _firestore
        .collection("leagues")
        .doc(leagueId)
        .collection("matches")
        .where("status", isNotEqualTo: "completed")
        .orderBy("status")
        .orderBy("date");
  }

  Future<void> _resetAndFetchMatches() async {
    // Cancel any existing subscription
    await _matchesSubscription?.cancel();
    _matchesSubscription = null;

    _matchDocs.clear();
    _lastMatchDoc = null;
    _hasMore = true;
    _isLoadingMore = false;
    _matchesError = false;
    _matchesErrorMessage = null;

    if (_selectedLeagueId != null) {
      await _fetchInitialMatches();
    } else {
      setState(() {});
    }
  }

  Future<void> _fetchInitialMatches() async {
    if (_selectedLeagueId == null) return;

    setState(() {
      _matchesLoading = true;
      _matchesError = false;
      _matchesErrorMessage = null;
    });

    try {
      final base = _matchesBaseQuery(_selectedLeagueId!);
      final snapshot = await base.limit(_pageSize).get();

      _matchDocs.clear();
      _matchDocs.addAll(snapshot.docs);

      _lastMatchDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMore = snapshot.docs.length == _pageSize;

      // subscribe to realtime updates for the currently loaded set
      _subscribeToMatches();
    } catch (e, st) {
      debugPrint("Error fetching initial matches: $e\n$st");
      _matchesError = true;
      _matchesErrorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _matchesLoading = false);
    }
  }

  Future<void> _loadMoreMatches() async {
    if (_selectedLeagueId == null) return;
    if (!_hasMore) return;
    if (_isLoadingMore) return;
    if (_lastMatchDoc == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final base = _matchesBaseQuery(_selectedLeagueId!);
      final more = await base.startAfterDocument(_lastMatchDoc!).limit(_pageSize).get();

      if (more.docs.isNotEmpty) {
        _matchDocs.addAll(more.docs);
        _lastMatchDoc = more.docs.last;
      }

      _hasMore = more.docs.length == _pageSize;

      // Re-subscribe to include new items in realtime listener
      _subscribeToMatches();
    } catch (e, st) {
      debugPrint("Error loading more matches: $e\n$st");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load more matches.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _subscribeToMatches() {
    // Cancel previous subscription
    _matchesSubscription?.cancel();
    _matchesSubscription = null;

    if (_selectedLeagueId == null) return;
    if (_matchDocs.isEmpty) return;

    final base = _matchesBaseQuery(_selectedLeagueId!);

    // Limit the subscription to the number of docs currently loaded so we get realtime updates
    final limit = _matchDocs.length;

    _matchesSubscription = base.limit(limit).snapshots().listen(
      (snapshot) {
        // Replace the top "limit" docs with the realtime snapshot docs.
        // Any additional docs (beyond limit) remain as-is in _matchDocs.
        final realtimeDocs = snapshot.docs;
        final remaining = _matchDocs.length > realtimeDocs.length ? _matchDocs.sublist(realtimeDocs.length) : <QueryDocumentSnapshot>[];
        _matchDocs
          ..clear()
          ..addAll(realtimeDocs)
          ..addAll(remaining);

        setState(() {
          // Updated _matchDocs will rebuild UI.
        });
      },
      onError: (e) {
        debugPrint("Matches subscription error: $e");
        setState(() {
          _matchesError = true;
          _matchesErrorMessage = e.toString();
        });
      },
    );
  }

  @override
  void dispose() {
    _matchesSubscription?.cancel();
    super.dispose();
  }

  // ------ Build UI ------
  // Web-first responsive layout: left column = leagues & matches (scrollable),
  // right column = match details & lineup selectors with action button pinned.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Match"),
        backgroundColor: AppColors.whiteColor,
        elevation: 1,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              Widget leaguesDropdown() {
                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection("leagues").snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        "Error loading leagues: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Text("No leagues available");
                    }

                    final leagues = snapshot.data!.docs;

                    return DropdownButtonFormField<String>(
                      value: _selectedLeagueId,
                      hint: const Text("Select a league"),
                      isExpanded: true,
                      items: leagues.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(data["name"] ?? "Unnamed League"),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedLeagueId = val;
                          _selectedMatchId = null;
                          _teamAPlayers = [];
                          _teamBPlayers = [];
                          _selectedTeamAPlayers = [];
                          _selectedTeamBPlayers = [];
                        });

                        // Reset pagination and fetch matches for the new league
                        _resetAndFetchMatches();
                      },
                    );
                  },
                );
              }

              Widget matchesList() {
                return Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leaguesDropdown(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: _selectedLeagueId == null
                                ? const Center(child: Text("Select a league to load matches."))
                                : _matchesLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : _matchesError
                                        ? Column(
                                            children: [
                                              Text(
                                                "Error loading matches: ${_matchesErrorMessage ?? 'Unknown error'}",
                                                style: const TextStyle(color: Colors.red),
                                              ),
                                              const SizedBox(height: 8),
                                              ElevatedButton(
                                                onPressed: _fetchInitialMatches,
                                                child: const Text("Retry"),
                                              ),
                                            ],
                                          )
                                        : _matchDocs.isEmpty
                                            ? const Center(child: Text("No matches available"))
                                            : Scrollbar(
                                                thumbVisibility: true,
                                                child: ListView.separated(
                                                  shrinkWrap: true,
                                                  physics: const ClampingScrollPhysics(),
                                                  itemCount: _matchDocs.length + (_hasMore ? 1 : 0),
                                                  separatorBuilder: (_, __) => const Divider(height: 0.5),
                                                  itemBuilder: (context, index) {
                                                    if (index == _matchDocs.length) {
                                                      // Load more button row
                                                      return Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                                        child: Center(
                                                          child: TextButton(
                                                            onPressed: _isLoadingMore ? null : _loadMoreMatches,
                                                            child: _isLoadingMore
                                                                ? const SizedBox(
                                                                    height: 16,
                                                                    width: 16,
                                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                                  )
                                                                : const Text("Load more"),
                                                          ),
                                                        ),
                                                      );
                                                    }

                                                    final doc = _matchDocs[index];
                                                    final data = doc.data() as Map<String, dynamic>;

                                                    final teamAId = data["teamAId"] as String?;
                                                    final teamBId = data["teamBId"] as String?;
                                                    final Timestamp? dateTs = data["date"];

                                                    final bool isSelected = doc.id == _selectedMatchId;

                                                    return InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          _selectedMatchId = doc.id;
                                                          _selectedTeamAPlayers.clear();
                                                          _selectedTeamBPlayers.clear();
                                                          _teamAPlayers.clear();
                                                          _teamBPlayers.clear();
                                                        });

                                                        if (_selectedLeagueId != null) {
                                                          _loadMatchDetails(_selectedLeagueId!, doc.id);
                                                        }

                                                        // On narrow screens, scroll to top of page so details are visible
                                                        if (!isWide) {
                                                          // no-op: content naturally scrolls on mobile layout
                                                        }
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                        color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.06) : null,
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: FutureBuilder<List<String>>(
                                                                future: Future.wait([
                                                                  if (teamAId != null) _getTeamName(teamAId) else Future.value("Unknown"),
                                                                  if (teamBId != null) _getTeamName(teamBId) else Future.value("Unknown"),
                                                                ]),
                                                                builder: (context, snap) {
                                                                  if (snap.connectionState == ConnectionState.waiting) {
                                                                    return const Text(
                                                                      "Loading...",
                                                                      style: TextStyle(fontSize: 12),
                                                                    );
                                                                  }
                                                                  if (snap.hasError) {
                                                                    return const Text(
                                                                      "Failed to load teams",
                                                                      style: TextStyle(fontSize: 12, color: Colors.red),
                                                                    );
                                                                  }

                                                                  return Text(
                                                                    "${snap.data![0]}  vs  ${snap.data![1]}",
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                    style: TextStyle(
                                                                      fontSize: 13,
                                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                            if (dateTs != null)
                                                              Padding(
                                                                padding: const EdgeInsets.only(left: 8),
                                                                child: _MatchDateBadge(dateTs.toDate(), compact: true),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              Widget detailsPane() {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Header
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedMatchId == null ? "No match selected" : "Selected Match",
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      if (_selectedMatchId != null)
                                        Text(
                                          "${_teamAName ?? ''}  vs  ${_teamBName ?? ''}",
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                    ],
                                  ),
                                ),
                                // Small action area for web: quick clear / refresh
                                IconButton(
                                  tooltip: "Refresh match details",
                                  onPressed: _selectedMatchId != null && _selectedLeagueId != null
                                      ? () => _loadMatchDetails(_selectedLeagueId!, _selectedMatchId!)
                                      : null,
                                  icon: const Icon(Icons.refresh),
                                ),
                                IconButton(
                                  tooltip: "Clear selection",
                                  onPressed: () {
                                    setState(() {
                                      _selectedMatchId = null;
                                      _teamAPlayers = [];
                                      _teamBPlayers = [];
                                      _selectedTeamAPlayers = [];
                                      _selectedTeamBPlayers = [];
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Main content (lineup selectors)
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_teamAPlayers.isNotEmpty) ...[
                                      Text("Select lineup for ${_teamAName ?? ''}"),
                                      const SizedBox(height: 8),
                                      MultiSelectDialogField<Map<String, dynamic>>(
                                        items: _teamAPlayers.map((p) => MultiSelectItem(p, p["name"])).toList(),
                                        title: Text("${_teamAName ?? ''} Players"),
                                        buttonText: const Text("Choose players"),
                                        chipDisplay: MultiSelectChipDisplay(
                                          chipColor: Colors.grey.shade200,
                                          textStyle: const TextStyle(color: Colors.black87),
                                        ),
                                        onConfirm: (values) {
                                          _selectedTeamAPlayers = values.cast<Map<String, dynamic>>();
                                        },
                                      ),
                                    ] else if (_selectedMatchId != null) ...[
                                      const Text("No players available for Team A"),
                                      const SizedBox(height: 8),
                                    ],

                                    const SizedBox(height: 16),

                                    if (_teamBPlayers.isNotEmpty) ...[
                                      Text("Select lineup for ${_teamBName ?? ''}"),
                                      const SizedBox(height: 8),
                                      MultiSelectDialogField<Map<String, dynamic>>(
                                        items: _teamBPlayers.map((p) => MultiSelectItem(p, p["name"])).toList(),
                                        title: Text("${_teamBName ?? ''} Players"),
                                        buttonText: const Text("Choose players"),
                                        chipDisplay: MultiSelectChipDisplay(
                                          chipColor: Colors.grey.shade200,
                                          textStyle: const TextStyle(color: Colors.black87),
                                        ),
                                        onConfirm: (values) {
                                          _selectedTeamBPlayers = values.cast<Map<String, dynamic>>();
                                        },
                                      ),
                                    ] else if (_selectedMatchId != null) ...[
                                      const Text("No players available for Team B"),
                                      const SizedBox(height: 8),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // Action bar pinned to bottom of details card
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _selectedMatchId == null || _loading ? null : _saveLineups,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryColor,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 48),
                                    ),
                                    child: _loading
                                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text("Continue to Live Updater"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              // Responsive composition
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: leagues + matches
                    SizedBox(
                      width: 380,
                      child: matchesList(),
                    ),

                    // Middle/Right: match details and action
                    detailsPane(),
                  ],
                );
              } else {
                // Narrow/mobile layout: stack vertically (keeps original behavior)
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      leaguesDropdown(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: _selectedLeagueId == null
                                ? const Center(child: Text("Select a league to load matches."))
                                : _matchesLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : _matchesError
                                        ? Column(
                                            children: [
                                              Text(
                                                "Error loading matches: ${_matchesErrorMessage ?? 'Unknown error'}",
                                                style: const TextStyle(color: Colors.red),
                                              ),
                                              const SizedBox(height: 8),
                                              ElevatedButton(
                                                onPressed: _fetchInitialMatches,
                                                child: const Text("Retry"),
                                              ),
                                            ],
                                          )
                                        : _matchDocs.isEmpty
                                            ? const Center(child: Text("No matches available"))
                                            : ListView.separated(
                                                itemCount: _matchDocs.length + (_hasMore ? 1 : 0),
                                                separatorBuilder: (_, __) => const Divider(height: 0.5),
                                                itemBuilder: (context, index) {
                                                  if (index == _matchDocs.length) {
                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      child: Center(
                                                        child: TextButton(
                                                          onPressed: _isLoadingMore ? null : _loadMoreMatches,
                                                          child: _isLoadingMore
                                                              ? const SizedBox(
                                                                  height: 16,
                                                                  width: 16,
                                                                  child: CircularProgressIndicator(strokeWidth: 2),
                                                                )
                                                              : const Text("Load more"),
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  final doc = _matchDocs[index];
                                                  final data = doc.data() as Map<String, dynamic>;

                                                  final teamAId = data["teamAId"] as String?;
                                                  final teamBId = data["teamBId"] as String?;
                                                  final Timestamp? dateTs = data["date"];

                                                  final bool isSelected = doc.id == _selectedMatchId;

                                                  return ListTile(
                                                    onTap: () {
                                                      setState(() {
                                                        _selectedMatchId = doc.id;
                                                        _selectedTeamAPlayers.clear();
                                                        _selectedTeamBPlayers.clear();
                                                        _teamAPlayers.clear();
                                                        _teamBPlayers.clear();
                                                      });

                                                      if (_selectedLeagueId != null) {
                                                        _loadMatchDetails(_selectedLeagueId!, doc.id);
                                                      }
                                                    },
                                                    title: FutureBuilder<List<String>>(
                                                      future: Future.wait([
                                                        if (teamAId != null) _getTeamName(teamAId) else Future.value("Unknown"),
                                                        if (teamBId != null) _getTeamName(teamBId) else Future.value("Unknown"),
                                                      ]),
                                                      builder: (context, snap) {
                                                        if (snap.connectionState == ConnectionState.waiting) {
                                                          return const Text("Loading...");
                                                        }
                                                        if (snap.hasError) {
                                                          return const Text("Failed to load teams", style: TextStyle(color: Colors.red));
                                                        }
                                                        return Text("${snap.data![0]}  vs  ${snap.data![1]}",
                                                            maxLines: 1, overflow: TextOverflow.ellipsis);
                                                      },
                                                    ),
                                                    trailing: dateTs != null ? _MatchDateBadge(dateTs.toDate(), compact: true) : null,
                                                    selected: isSelected,
                                                  );
                                                },
                                              ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Details + continue button below matches
                      Card(
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              if (_selectedMatchId == null)
                                const Text("No match selected")
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${_teamAName ?? ''}  vs  ${_teamBName ?? ''}",
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    if (_teamAPlayers.isNotEmpty) ...[
                                      Text("Select lineup for ${_teamAName ?? ''}"),
                                      const SizedBox(height: 8),
                                      MultiSelectDialogField<Map<String, dynamic>>(
                                        items: _teamAPlayers.map((p) => MultiSelectItem(p, p["name"])).toList(),
                                        title: Text("${_teamAName ?? ''} Players"),
                                        buttonText: const Text("Choose players"),
                                        onConfirm: (values) {
                                          _selectedTeamAPlayers = values.cast<Map<String, dynamic>>();
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    if (_teamBPlayers.isNotEmpty) ...[
                                      Text("Select lineup for ${_teamBName ?? ''}"),
                                      const SizedBox(height: 8),
                                      MultiSelectDialogField<Map<String, dynamic>>(
                                        items: _teamBPlayers.map((p) => MultiSelectItem(p, p["name"])).toList(),
                                        title: Text("${_teamBName ?? ''} Players"),
                                        buttonText: const Text("Choose players"),
                                        onConfirm: (values) {
                                          _selectedTeamBPlayers = values.cast<Map<String, dynamic>>();
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _selectedMatchId == null || _loading ? null : _saveLineups,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                                child: _loading
                                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text("Continue to Live Updater"),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            }),
    );
  }
}