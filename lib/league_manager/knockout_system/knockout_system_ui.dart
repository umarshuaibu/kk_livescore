// File: fans/knockout/knockout_system_ui.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class KnockoutSystemUI extends StatefulWidget {
  final String leagueId;

  const KnockoutSystemUI({super.key, required this.leagueId});

  @override
  State<KnockoutSystemUI> createState() => _KnockoutSystemUIState();
}

class _KnockoutSystemUIState extends State<KnockoutSystemUI>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;

  /// teamId -> {name, logo, coachId}
  Map<String, Map<String, String>> _teams = {};

  // ================= AdMob Interstitial =================
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  String _lastMatchId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTeams();
    _loadInterstitialAd();
  }

  Future<void> _loadTeams() async {
    final snap = await _firestore
        .collection('leagues')
        .doc(widget.leagueId)
        .collection('teams')
        .get();

    final map = <String, Map<String, String>>{};

    for (var d in snap.docs) {
      final data = d.data();
      map[data['teamId']] = {
        'name': data['name'] ?? 'Unknown',
        'logoUrl': data['logoUrl'] ?? '',
        'coachId': data['coachId'] ?? '',
      };
    }

    if (mounted) setState(() => _teams = map);
  }

  Map<String, String> _teamData(String? id) {
    if (id == null || id == 'BYE') {
      return {'name': 'Upcoming', 'logoUrl': ''};
    }
    return _teams[id] ?? {'name': '...', 'logoUrl': ''};
  }

  // ================== LOAD INTERSTITIAL ==================
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-7769762821516033/6429485665',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Interstitial failed to load: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  // ================== SHOW INTERSTITIAL ==================
  void _showInterstitialAd() {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitialAd(); // reload for next time
      }, onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _loadInterstitialAd();
      });

      _interstitialAd!.show();
      _interstitialAd = null;
      _isAdLoaded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: kPrimaryColor,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: kWhiteColor,
            unselectedLabelColor: Colors.white70,
            indicatorColor: kPrimaryLight,
            tabs: const [
              Tab(text: "MATCHES"),
              Tab(text: "TEAMS"),
              Tab(text: "COACHES"),
              Tab(text: "ROUNDS"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _matchesTab(),
              _teamsTab(),
              _coachesTab(),
              _roundsTab(),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================
  // MATCHES TAB
  // =========================================================
  Widget _matchesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('leagues')
          .doc(widget.leagueId)
          .collection('matches')
          .orderBy('date')
          .snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final matches = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: matches.length,
          itemBuilder: (_, i) {
            final m = matches[i].data() as Map<String, dynamic>;

            final teamA = _teamData(m['teamAId']);
            final teamB = _teamData(m['teamBId']);

            final date = m['date'] != null
                ? (m['date'] as Timestamp).toDate()
                : null;

            final status = m['status'] ?? '';
            final matchId = m['matchId'] ?? i.toString();

            // 🔹 Show Ad if match status changed
            if (_lastMatchId != matchId) {
              _lastMatchId = matchId;
              _showInterstitialAd();
            }

            final isCompleted = status == 'completed';
            final isLive = status == 'live';
            final isScheduled = status == 'scheduled';

            final scoreA = m['scoreA'] ?? 0;
            final scoreB = m['scoreB'] ?? 0;

            return Card(
              color: isLive
                  ? Colors.red.withOpacity(0.2)
                  : kSecondaryColor,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: isLive
                    ? const BorderSide(color: Colors.red, width: 1)
                    : BorderSide.none,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // 🔴 LIVE BADGE
                    if (isLive)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.circle,
                              color: Colors.green, size: 8),
                          SizedBox(width: 4),
                          Text(
                            "LIVE",
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),

                    if (isLive) const SizedBox(height: 6),

                    // ================= MATCH ROW =================
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        // TEAM A
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                teamA['name']!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              _logo(teamA['logoUrl']),
                            ],
                          ),
                        ),

                        // CENTER (SCORE / VS)
                        Expanded(
                          child: Column(
                            children: [
                              if (isCompleted || isLive)
                                Text(
                                  "$scoreA - $scoreB",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              else
                                const Text(
                                  "VS",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // TEAM B
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                teamB['name']!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              _logo(teamB['logoUrl']),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ================= FOOTER =================
                    if (isScheduled && date != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          DateFormat('EEE, MMM d • HH:mm')
                              .format(date),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ),

                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Full Time",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================
  // TEAMS TAB
  // =========================================================
  Widget _teamsTab() {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: _teams.entries.map((e) {
        return Card(
          color: kSecondaryColor,
          child: ListTile(
            leading: _logo(e.value['logoUrl']),
            title: Text(
              e.value['name']!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // =========================================================
  // COACHES TAB
  // =========================================================
Widget _coachesTab() {
  return ListView(
    padding: const EdgeInsets.all(10),
    children: _teams.entries.map((entry) {
      final coachId = entry.value['coachId'];

      // ✅ Handle missing or empty coachId
      if (coachId == null || coachId.isEmpty) {
        return Card(
          color: kSecondaryColor,
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person, size: 12),
            ),
            title: const Text(
              'No Coach Assigned',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
            subtitle: Text(
              entry.value['name']!,
              style: const TextStyle(color: Colors.white70, fontSize: 8),
            ),
          ),
        );
      }

      return FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('coaches').doc(coachId).get(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const ListTile(
              title: Text('Loading...',
                  style: TextStyle(color: Colors.white)),
            );
          }

          final coach = snap.data!.data() as Map<String, dynamic>?;

          return Card(
            color: kSecondaryColor,
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(coach?['photoUrl'] ?? ''),
              ),
              title: Text(
                coach?['name'] ?? 'Unknown Coach',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              subtitle: Text(
                entry.value['name']!,
                style: const TextStyle(color: Colors.white70, fontSize: 8),
              ),
            ),
          );
        },
      );
    }).toList(),
  );
}


  // =========================================================
  // ROUNDS TAB
  // =========================================================
  Widget _roundsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('leagues')
          .doc(widget.leagueId)
          .collection('rounds')
          .orderBy('roundNumber')
          .snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rounds = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(10),
          children: rounds.map((round) {
            final matches =
                List<Map<String, dynamic>>.from(round['matches'] ?? []);

            return ExpansionTile(
              title: Text(
                round['name'],
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              children: matches.map((m) {
                final teamA = _teamData(m['teamAId']);
                final teamB = _teamData(m['teamBId']);

                final status = m['status'] ?? '';
                final isCompleted = status == 'completed';
                final isLive = status == 'live';
                final isScheduled = status == 'scheduled';

                final scoreA = m['scoreA'] ?? 0;
                final scoreB = m['scoreB'] ?? 0;

                final date = m['date'] != null
                    ? (m['date'] as Timestamp).toDate()
                    : null;

                return Card(
                  color: isLive
                      ? Colors.red.withOpacity(0.2)
                      : kSecondaryColor,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: isLive
                        ? const BorderSide(color: Colors.red, width: 1)
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        if (isLive)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.circle,
                                  color: Colors.green, size: 8),
                              SizedBox(width: 4),
                              Text(
                                "LIVE",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 6),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    teamA['name']!,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  _logo(teamA['logoUrl']),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  if (isCompleted || isLive)
                                    Text(
                                      "$scoreA - $scoreB",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                  else
                                    const Text(
                                      "VS",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    teamB['name']!,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  _logo(teamB['logoUrl']),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        if (isScheduled && date != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              DateFormat('EEE, MMM d • HH:mm').format(date),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        );
      },
    );
  }

  // =========================================================
  // COMMON
  // =========================================================
  Widget _logo(String? url) {
    if (url == null || url.isEmpty) {
      return const CircleAvatar(
        radius: 10,
        child: Icon(Icons.sports, size: 12),
      );
    }

    return CircleAvatar(
      radius: 10,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: NetworkImage(url),
      onBackgroundImageError: (exception, stackTrace) {
        debugPrint("❌ Image failed: $url");
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
