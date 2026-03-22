import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/constants/size.dart';
import 'package:kklivescoreadmin/constants/text_styles.dart';
import 'package:kklivescoreadmin/fans/reusables/bracket_view_tab.dart';
import 'package:kklivescoreadmin/fans/reusables/coaches_tab.dart';
import 'package:kklivescoreadmin/fans/reusables/matches_tab.dart';
import 'package:kklivescoreadmin/fans/reusables/news_tab.dart';
import 'package:kklivescoreadmin/fans/reusables/teams_tab.dart';
import 'package:kklivescoreadmin/league_manager/standings/standings_tab.dart';

class PublicHomePage extends StatefulWidget {
  const PublicHomePage({super.key});

  @override
  State<PublicHomePage> createState() => _PublicHomePageState();
}

class _PublicHomePageState extends State<PublicHomePage>
    with SingleTickerProviderStateMixin {
  String? selectedLeagueId;
  String? selectedLeagueMatchSystem; // Tracks "Knockout" or other
  late TabController _tabController;
  late BannerAd _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7769762821516033/3319422467', // Banner ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner failed to load: $error');
        },
      ),
    );

    _bannerAd.load();
  }

  // ------------------ EXIT APP ------------------ //
  void _exitApp() {
    SystemNavigator.pop();
  }

  // ------------------ FEEDBACK PAGE ------------------ //
  void _openFeedback() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FeedbackPlaceholder()),
    );
  }

  // ------------------ FETCH LEAGUES (plural then singular fallback) ------------------ //
  Future<List<QueryDocumentSnapshot>> _fetchLeaguesDocs() async {
    try {
      final pluralSnap =
          await FirebaseFirestore.instance.collection('leagues').get();
      if (pluralSnap.docs.isNotEmpty) return pluralSnap.docs;

      final singularSnap =
          await FirebaseFirestore.instance.collection('league').get();
      return singularSnap.docs;
    } catch (e) {
      debugPrint('[PublicHomePage] _fetchLeaguesDocs failed: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("KK LIVESCORE"),
        titleTextStyle: kAppBarTitleText,
        backgroundColor: kPrimaryColor,
        foregroundColor: kWhiteColor,
        actions: [
          FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _fetchLeaguesDocs(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: eqW(8)),
                  child: Row(
                    children: [
                      Text(
                        'Unable to load leagues',
                        style: kText12White,
                      ),
                      SizedBox(width: eqW(8)),
                      IconButton(
                        onPressed: () => setState(() {}),
                        icon: Icon(Icons.refresh, color: kPrimaryLight),
                        tooltip: 'Retry',
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: kPrimaryLight,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                );
              }

              final leagues = snapshot.data!;

              // Clear selection if league no longer exists
              final bool selectedStillPresent = selectedLeagueId != null &&
                  leagues.any((d) => d.id == selectedLeagueId);
              if (!selectedStillPresent && selectedLeagueId != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      selectedLeagueId = null;
                      selectedLeagueMatchSystem = null;
                    });
                  }
                });
              }

              if (leagues.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: eqW(12)),
                  child:
                      Center(child: Text('No leagues available', style: kText12White)),
                );
              }

              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: kWhiteColor,
                  value: selectedStillPresent ? selectedLeagueId : null,
                  hint: const Text(
                    "Switch League",
                    style: TextStyle(
                      color: kGrey1,
                      fontSize: 12,
                    ),
                  ),
                  items: leagues.map((doc) {
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final displayName =
                        (data['name']?.toString().trim().isNotEmpty == true)
                            ? data['name'].toString()
                            : 'Unnamed League';
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(
                        displayName,
                        style: TextStyle(color: kPrimaryColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final leagueData = leagues
                        .firstWhere((d) => d.id == val)
                        .data() as Map<String, dynamic>?;

                    setState(() {
                      selectedLeagueId = val;
                      selectedLeagueMatchSystem =
                          leagueData?['MatchesSystem']?.toString() ?? 'Home_and_away';
                      _tabController.animateTo(0);
                    });
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),

      body: Column(
        children: [
          // Tabs
          Material(
            color: kSecondaryColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: kWhiteColor,
                unselectedLabelColor: kGrey2,
                indicatorColor: kPrimaryLight,
                tabs: const [
                  Tab(text: "MATCHES"),
                  Tab(text: "TEAMS"),
                  Tab(text: "COACHES"),
                  Tab(text: "STANDINGS"),
                  Tab(text: "NEWS"),
                ],
              ),
            ),
          ),

          // Main content
          Expanded(
            child: selectedLeagueId == null
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(eqW(12)),
                      child: Text(
                        "Please select a league above",
                        style: kText12White,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      MatchesTab(
                        leagueId: selectedLeagueId!,
                        matchesStream: FirebaseFirestore.instance
                            .collection('leagues')
                            .doc(selectedLeagueId)
                            .collection('matches')
                            .snapshots(),
                      ),
                      TeamsTab(leagueId: selectedLeagueId!),
                      CoachesTab(leagueId: selectedLeagueId!),

                      /// ------------------ STANDINGS OR BRACKET ------------------ ///
                      if (selectedLeagueMatchSystem == 'Knockout')
                        BracketViewTab(leagueId: selectedLeagueId!)
                      else
                        StandingsTab(leagueId: selectedLeagueId!),

                      NewsTab(leagueId: selectedLeagueId!),
                    ],
                  ),
          ),

          // 🔥 BANNER AD
          if (_isBannerAdLoaded)
            SizedBox(
              height: _bannerAd.size.height.toDouble(),
              width: _bannerAd.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd),
            ),
        ],
      ),

      // ============= Bottom Navigation ============= //
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: kScaffoldColor,
        selectedItemColor: kPrimaryLight,
        unselectedItemColor: kGrey2,
        onTap: (i) {
          if (i == 1) _openFeedback();
          if (i == 2) _exitApp();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.feedback), label: "Feedback"),
          BottomNavigationBarItem(icon: Icon(Icons.exit_to_app), label: "Exit"),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

// ----------------------------------------------
// Dummy Feedback Page
// ----------------------------------------------
class FeedbackPlaceholder extends StatelessWidget {
  const FeedbackPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Feedback"),
        backgroundColor: kPrimaryColor,
        foregroundColor: kWhiteColor,
      ),
      body: Center(
        child: Text(
          "coming soon",
          style: kText14White,
        ),
      ),
    );
  }
}
