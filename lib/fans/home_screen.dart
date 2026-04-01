import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/constants/size.dart';
import 'package:kklivescoreadmin/constants/text_styles.dart';
import 'package:kklivescoreadmin/fans/reusables/coaches_tab.dart';
import 'package:kklivescoreadmin/fans/reusables/matches_tab.dart';
import 'package:kklivescoreadmin/fans/reusables/news_tab.dart';
import 'package:kklivescoreadmin/fans/reusables/teams_tab.dart';
import 'package:kklivescoreadmin/league_manager/knockout_system/knockout_system_ui.dart';
import 'package:kklivescoreadmin/league_manager/standings/standings_tab.dart';

class PublicHomePage extends StatefulWidget {
  const PublicHomePage({super.key});

  @override
  State<PublicHomePage> createState() => _PublicHomePageState();
}

class _PublicHomePageState extends State<PublicHomePage>
    with SingleTickerProviderStateMixin {
  String? selectedLeagueId;
  String? selectedLeagueMatchSystem;

  late TabController _tabController;

  late BannerAd _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 5, vsync: this);

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7769762821516033/3319422467',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() => _isBannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner failed: $error');
        },
      ),
    );

    _bannerAd.load();
  }

  void _exitApp() => SystemNavigator.pop();

  void _openFeedback() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FeedbackPlaceholder()),
    );
  }

  Future<List<QueryDocumentSnapshot>> _fetchLeaguesDocs() async {
    final plural =
        await FirebaseFirestore.instance.collection('leagues').get();
    if (plural.docs.isNotEmpty) return plural.docs;

    final singular =
        await FirebaseFirestore.instance.collection('league').get();
    return singular.docs;
  }

  @override
  Widget build(BuildContext context) {
    final isKnockout = selectedLeagueMatchSystem == 'Knockout';

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
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    color: kPrimaryLight,
                    strokeWidth: 2,
                  ),
                );
              }

              final leagues = snapshot.data!;

              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: kWhiteColor,
                  value: selectedLeagueId,
                  hint: const Text("Switch League"),
                  items: leagues.map((doc) {
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final name = data['name'] ?? 'Unnamed League';

                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(name,
                          style: TextStyle(color: kPrimaryColor)),
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
                          leagueData?['MatchesSystem'] ?? 'Home_and_away';

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
          /// ❌ HIDE OUTER TABS IF KNOCKOUT
          if (!isKnockout)
            Material(
              color: kSecondaryColor,
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

          Expanded(
            child: selectedLeagueId == null
                ? Center(
                    child: Text(
                      "Please select a league",
                      style: kText12White,
                    ),
                  )

                /// 🔴 FULL SWITCH TO KNOCKOUT UI
                : isKnockout
                    ? KnockoutSystemUI(
                        leagueId: selectedLeagueId!,
                      )

                    /// 🟢 NORMAL LEAGUE UI
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
                          StandingsTab(leagueId: selectedLeagueId!),
                          NewsTab(leagueId: selectedLeagueId!),
                        ],
                      ),
          ),

          if (_isBannerAdLoaded)
            SizedBox(
              height: _bannerAd.size.height.toDouble(),
              width: _bannerAd.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd),
            ),
        ],
      ),

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

/// Dummy Feedback Page
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
        child: Text("coming soon", style: kText14White),
      ),
    );
  }
}
