import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kklivescoreadmin/admins/management/models/api_model.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/fans/reusables/coaches_tab.dart';
import 'package:kklivescoreadmin/fans/reusables/matches_tab.dart';
import 'package:kklivescoreadmin/fans/reusables/news_tab.dart';
import 'package:kklivescoreadmin/fans/reusables/teams_tab.dart';
import 'package:kklivescoreadmin/league_manager/knockout_system/knockout_system_ui.dart';
import 'package:kklivescoreadmin/league_manager/standings/standings_tab.dart';


// ── Design tokens ──
const _kBg = Color(0xFF0F1117);
const _kSurface = Color(0xFF161A23);
const _kSurface2 = Color(0xFF1A1F2E);
const _kBorder = Color(0xFF252B38);
const _kGreen = Color(0xFF81C784);
const _kAmber = Color(0xFFFFB74D);
const _kBlue = Color(0xFF4FC3F7);
const _kRed = Color(0xFFE57373);

class PublicHomePage extends StatefulWidget {
  const PublicHomePage({super.key});

  @override
  State<PublicHomePage> createState() => _PublicHomePageState();
}

class _PublicHomePageState extends State<PublicHomePage>
    with TickerProviderStateMixin {
  // ── Main tab (My Leagues | International) ──
  late TabController _mainTabCtrl;

  // ── My Leagues (Firestore) state ──
  String? selectedLeagueId;
  String? selectedLeagueMatchSystem;
  late TabController _myLeagueTabCtrl;

  // ── International state ──
  IntlLeague _selectedIntlLeague = kIntlLeagues.first;

  // ── Ads ──
  late BannerAd _bannerAd;
  bool _isBannerAdLoaded = false;

  // ── Fade animation ──
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _mainTabCtrl = TabController(length: 2, vsync: this);
    _myLeagueTabCtrl = TabController(length: 5, vsync: this);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7769762821516033/3319422467',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner failed: $error');
        },
      ),
    );
    _bannerAd.load();
  }

  @override
  void dispose() {
    _mainTabCtrl.dispose();
    _myLeagueTabCtrl.dispose();
    _fadeCtrl.dispose();
    _bannerAd.dispose();
    super.dispose();
  }

  // ── UNCHANGED original logic ──
  Future<List<QueryDocumentSnapshot>> _fetchLeaguesDocs() async {
    final plural =
        await FirebaseFirestore.instance.collection('leagues').get();
    if (plural.docs.isNotEmpty) return plural.docs;
    final singular =
        await FirebaseFirestore.instance.collection('league').get();
    return singular.docs;
  }

  // ════════════════════════════════════════
  //   BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            // ── HEADER ──
            _buildHeader(),

            // ── MAIN TABS: My Leagues | International ──
            _buildMainTabBar(),

            // ── CONTENT ──
            Expanded(
              child: TabBarView(
                controller: _mainTabCtrl,
                children: [
                  _MyLeaguesView(
                    fetchLeaguesDocs: _fetchLeaguesDocs,
                    selectedLeagueId: selectedLeagueId,
                    selectedLeagueMatchSystem: selectedLeagueMatchSystem,
                    tabController: _myLeagueTabCtrl,
                    onLeagueChanged: (id, system) {
                      setState(() {
                        selectedLeagueId = id;
                        selectedLeagueMatchSystem = system;
                        _myLeagueTabCtrl.animateTo(0);
                      });
                    },
                  ),
                  _InternationalView(
                    selectedLeague: _selectedIntlLeague,
                    onLeagueChanged: (league) {
                      setState(() => _selectedIntlLeague = league);
                    },
                  ),
                ],
              ),
            ),

            // ── BANNER AD ──
            if (_isBannerAdLoaded)
              Container(
                color: _kSurface,
                child: SizedBox(
                  height: _bannerAd.size.height.toDouble(),
                  width: _bannerAd.size.width.toDouble(),
                  child: AdWidget(ad: _bannerAd),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ──
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          // Logo + brand
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.sports_soccer_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'KK Livescore',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          // Live indicator
          _LivePulse(),
        ],
      ),
    );
  }

  // ── MAIN TAB BAR ──
  Widget _buildMainTabBar() {
    return Container(
      color: _kSurface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: TabBar(
        controller: _mainTabCtrl,
        labelColor: AppColors.primaryColor,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: AppColors.primaryColor,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        tabs: const [
          Tab(text: 'My Leagues'),
          Tab(text: 'International'),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   MY LEAGUES VIEW (Firestore — original logic untouched)
// ════════════════════════════════════════════════════════════════════
class _MyLeaguesView extends StatelessWidget {
  final Future<List<QueryDocumentSnapshot>> Function() fetchLeaguesDocs;
  final String? selectedLeagueId;
  final String? selectedLeagueMatchSystem;
  final TabController tabController;
  final void Function(String id, String system) onLeagueChanged;

  const _MyLeaguesView({
    required this.fetchLeaguesDocs,
    required this.selectedLeagueId,
    required this.selectedLeagueMatchSystem,
    required this.tabController,
    required this.onLeagueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isKnockout = selectedLeagueMatchSystem == 'Knockout';

    return Column(
      children: [
        // League selector
        _buildLeagueSelector(context),

        // Inner tab bar (only for non-knockout)
        if (selectedLeagueId != null && !isKnockout)
          _buildInnerTabBar(),

        Expanded(
          child: selectedLeagueId == null
              ? _buildEmptyState()
              : isKnockout
                  ? KnockoutSystemUI(leagueId: selectedLeagueId!)
                  : TabBarView(
                      controller: tabController,
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
      ],
    );
  }

  Widget _buildLeagueSelector(BuildContext context) {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: fetchLeaguesDocs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 52,
            color: _kSurface2,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _kBlue),
              ),
            ),
          );
        }

        final leagues = snapshot.data!;
        if (leagues.isEmpty) {
          return Container(
            height: 52,
            color: _kSurface2,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    color: Colors.grey.shade600, size: 18),
                const SizedBox(width: 10),
                Text('No leagues created yet',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          );
        }

        return Container(
          height: 52,
          color: _kSurface2,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.emoji_events_rounded,
                  color: Colors.grey.shade500, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedLeagueId,
                    dropdownColor: _kSurface2,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                    icon: Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey.shade500),
                    hint: Text('Select a league',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                    isExpanded: true,
                    items: leagues.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] as String? ?? 'Unnamed';
                      final status =
                          data['status'] as String? ?? 'inactive';
                      return DropdownMenuItem(
                        value: doc.id,
                        child: Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: status == 'active'
                                    ? _kGreen
                                    : _kAmber,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(name,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final doc =
                          leagues.firstWhere((d) => d.id == val);
                      final data =
                          doc.data() as Map<String, dynamic>;
                      onLeagueChanged(
                        val,
                        data['MatchesSystem'] as String? ??
                            'Home_and_away',
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInnerTabBar() {
    return Container(
      color: _kSurface,
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        labelColor: AppColors.primaryColor,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: AppColors.primaryColor,
        indicatorWeight: 2,
        labelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'MATCHES'),
          Tab(text: 'TEAMS'),
          Tab(text: 'COACHES'),
          Tab(text: 'STANDINGS'),
          Tab(text: 'NEWS'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: _kBlue, size: 30),
          ),
          const SizedBox(height: 16),
          const Text('Select a league',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Choose a league from the dropdown above',
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   INTERNATIONAL VIEW
// ════════════════════════════════════════════════════════════════════
class _InternationalView extends StatefulWidget {
  final IntlLeague selectedLeague;
  final void Function(IntlLeague) onLeagueChanged;

  const _InternationalView({
    required this.selectedLeague,
    required this.onLeagueChanged,
  });

  @override
  State<_InternationalView> createState() => _InternationalViewState();
}

class _InternationalViewState extends State<_InternationalView>
    with SingleTickerProviderStateMixin {
  late TabController _intlTabCtrl;
  bool _showLeaguePicker = false;

  @override
  void initState() {
    super.initState();
    _intlTabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _intlTabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // League header card
        _buildLeagueHeader(),

        // Tabs
        _buildIntlTabBar(),

        // Content
        Expanded(
          child: TabBarView(
            controller: _intlTabCtrl,
            children: [
              _IntlFixturesTab(league: widget.selectedLeague),
              _IntlStandingsTab(league: widget.selectedLeague),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeagueHeader() {
    final league = widget.selectedLeague;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _LeaguePickerSheet(
            selected: league,
            onSelect: (l) {
              widget.onLeagueChanged(l);
              Navigator.pop(context);
              _intlTabCtrl.animateTo(0);
            },
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: league.accentColor.withOpacity(0.12),
          border: Border(
            bottom: BorderSide(
                color: league.accentColor.withOpacity(0.2)),
          ),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // League logo
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                league.logoUrl,
                width: 36,
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: league.accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(league.countryFlag,
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    league.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(league.countryFlag,
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 5),
                      Text(
                        '${league.country}  •  ${league.season}',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Switch',
                      style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade500, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntlTabBar() {
    return Container(
      color: _kSurface,
      child: TabBar(
        controller: _intlTabCtrl,
        labelColor: widget.selectedLeague.accentColor,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: widget.selectedLeague.accentColor,
        indicatorWeight: 2,
        labelStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'FIXTURES'),
          Tab(text: 'STANDINGS'),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   LEAGUE PICKER BOTTOM SHEET
// ════════════════════════════════════════════════════════════════════
class _LeaguePickerSheet extends StatelessWidget {
  final IntlLeague selected;
  final void Function(IntlLeague) onSelect;

  const _LeaguePickerSheet({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Group leagues by category
    final europe = kIntlLeagues
        .where((l) => const {
              'England', 'Spain', 'Italy', 'Germany', 'France', 'Europe'
            }.contains(l.country))
        .toList();
    final world = kIntlLeagues
        .where((l) => l.country == 'World')
        .toList();
    final africa = kIntlLeagues
        .where((l) =>
            l.country == 'Africa' || l.country == 'Nigeria')
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text('Select League',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),

          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55),
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetCategory('🇪🇺  Europe', europe, selected, onSelect),
                  _sheetCategory('🌍  World', world, selected, onSelect),
                  _sheetCategory('🌍  Africa', africa, selected, onSelect),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetCategory(String title, List<IntlLeague> leagues,
      IntlLeague sel, void Function(IntlLeague) onSel) {
    if (leagues.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(title,
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ),
        ...leagues.map((l) {
          final isSelected = l.id == sel.id;
          return GestureDetector(
            onTap: () => onSel(l),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? l.accentColor.withOpacity(0.12)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? l.accentColor.withOpacity(0.35)
                      : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(l.logoUrl,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Text(l.countryFlag,
                                style:
                                    const TextStyle(fontSize: 20))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name,
                            style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                        Text('${l.countryFlag}  ${l.country}  •  ${l.season}',
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded,
                        color: l.accentColor, size: 18),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   INTERNATIONAL FIXTURES TAB
// ════════════════════════════════════════════════════════════════════
class _IntlFixturesTab extends StatefulWidget {
  final IntlLeague league;
  const _IntlFixturesTab({required this.league});

  @override
  State<_IntlFixturesTab> createState() => _IntlFixturesTabState();
}

class _IntlFixturesTabState extends State<_IntlFixturesTab> {
  int _filterIndex = 0; // 0=All, 1=Live, 2=Upcoming, 3=Results
  late Future<List<ApiMatch>> _future;

  final _filters = ['All', 'Live', 'Upcoming', 'Results'];

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  @override
  void didUpdateWidget(_IntlFixturesTab old) {
    super.didUpdateWidget(old);
    if (old.league.id != widget.league.id) {
      _loadMatches();
    }
  }

  void _loadMatches() {
    setState(() {
      _future = _fetchFiltered();
    });
  }

  Future<List<ApiMatch>> _fetchFiltered() async {
    switch (_filterIndex) {
      case 1: // Live
        return ApiFootballService.fetchFixtures(
          leagueId: widget.league.id,
          season: widget.league.season,
          status: '1H-HT-2H-ET-BT-P-INT',
        );
      case 2: // Upcoming
        return ApiFootballService.fetchFixtures(
          leagueId: widget.league.id,
          season: widget.league.season,
          next: 10,
        );
      case 3: // Results
        return ApiFootballService.fetchFixtures(
          leagueId: widget.league.id,
          season: widget.league.season,
          last: 10,
        );
      default: // All — last 5 + next 10
        final results = await Future.wait([
          ApiFootballService.fetchFixtures(
            leagueId: widget.league.id,
            season: widget.league.season,
            last: 5,
          ),
          ApiFootballService.fetchFixtures(
            leagueId: widget.league.id,
            season: widget.league.season,
            next: 10,
          ),
        ]);
        return [...results[0], ...results[1]];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        _buildFilterBar(),

        // Matches list
        Expanded(
          child: FutureBuilder<List<ApiMatch>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoading();
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _buildError();
              }
              final matches = snapshot.data!;
              if (matches.isEmpty) {
                return _buildEmpty('No fixtures found');
              }

              // Group by round
              final grouped = <String, List<ApiMatch>>{};
              for (final m in matches) {
                final key = m.round ?? 'Matches';
                grouped.putIfAbsent(key, () => []).add(m);
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: grouped.length,
                itemBuilder: (context, i) {
                  final round = grouped.keys.elementAt(i);
                  final roundMatches = grouped[round]!;
                  return _RoundSection(
                    round: round,
                    matches: roundMatches,
                    accentColor: widget.league.accentColor,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 44,
      color: _kSurface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final isActive = _filterIndex == i;
          return GestureDetector(
            onTap: () {
              setState(() => _filterIndex = i);
              _loadMatches();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? widget.league.accentColor.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? widget.league.accentColor.withOpacity(0.4)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Text(
                _filters[i],
                style: TextStyle(
                  color: isActive
                      ? widget.league.accentColor
                      : Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: isActive
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(
          strokeWidth: 2, color: widget.league.accentColor),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: _kRed, size: 32),
          const SizedBox(height: 12),
          const Text('Failed to load fixtures',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 6),
          Text('Check your API key or connection',
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadMatches,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBlue.withOpacity(0.3)),
              ),
              child: const Text('Retry',
                  style: TextStyle(
                      color: _kBlue, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_soccer_rounded,
              color: Colors.grey.shade700, size: 36),
          const SizedBox(height: 12),
          Text(msg,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Round section ──
class _RoundSection extends StatelessWidget {
  final String round;
  final List<ApiMatch> matches;
  final Color accentColor;

  const _RoundSection({
    required this.round,
    required this.matches,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            round.replaceAll('Regular Season - ', 'Round '),
            style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
        ),
        ...matches.map((m) => _MatchCard(
            match: m, accentColor: accentColor)),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Single match card ──
class _MatchCard extends StatelessWidget {
  final ApiMatch match;
  final Color accentColor;

  const _MatchCard({required this.match, required this.accentColor});

  String _fmtTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final m = match;
    final isLive = m.isLive;
    final isFinished = m.isFinished;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isLive
            ? _kGreen.withOpacity(0.06)
            : _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLive
              ? _kGreen.withOpacity(0.25)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Time / Status
          SizedBox(
            width: 46,
            child: Column(
              children: [
                if (isLive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m.elapsed != null ? "${m.elapsed}'" : 'LIVE',
                      style: const TextStyle(
                          color: _kGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ] else if (isFinished) ...[
                  Text('FT',
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  Text(_fmtDate(m.date),
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 9)),
                ] else ...[
                  Text(_fmtTime(m.date),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Text(_fmtDate(m.date),
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 9)),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Match content
          Expanded(
            child: Column(
              children: [
                // Home team
                _teamRow(m.home, m.homeGoals,
                    winner: m.home.winner, isLeft: true),
                const SizedBox(height: 8),
                // Away team
                _teamRow(m.away, m.awayGoals,
                    winner: m.away.winner, isLeft: true),
              ],
            ),
          ),

          // Venue
          if (m.venueName != null && !isLive && !isFinished)
            SizedBox(
              width: 50,
              child: Text(
                m.venueName!,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 9),
              ),
            ),
        ],
      ),
    );
  }

  Widget _teamRow(ApiTeamRef team, int? goals,
      {bool? winner, required bool isLeft}) {
    final isWinner = winner == true;

    return Row(
      children: [
        // Logo
        Image.network(
          team.logoUrl,
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(
            width: 22,
            height: 22,
            child: Icon(Icons.shield_outlined,
                size: 16, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 8),
        // Name
        Expanded(
          child: Text(
            team.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isWinner ? Colors.white : Colors.white60,
              fontSize: 13,
              fontWeight: isWinner
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        ),
        // Score
        if (goals != null)
          Text(
            goals.toString(),
            style: TextStyle(
              color: isWinner
                  ? Colors.white
                  : Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   INTERNATIONAL STANDINGS TAB
// ════════════════════════════════════════════════════════════════════
class _IntlStandingsTab extends StatefulWidget {
  final IntlLeague league;
  const _IntlStandingsTab({required this.league});

  @override
  State<_IntlStandingsTab> createState() => _IntlStandingsTabState();
}

class _IntlStandingsTabState extends State<_IntlStandingsTab> {
  late Future<List<ApiStandingGroup>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_IntlStandingsTab old) {
    super.didUpdateWidget(old);
    if (old.league.id != widget.league.id) _load();
  }

  void _load() {
    setState(() {
      _future = ApiFootballService.fetchStandings(
        leagueId: widget.league.id,
        season: widget.league.season,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ApiStandingGroup>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.league.accentColor),
          );
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: _kRed, size: 32),
                const SizedBox(height: 12),
                const Text('No standings available',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _load,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: _kBlue.withOpacity(0.3)),
                    ),
                    child: const Text('Retry',
                        style: TextStyle(
                            color: _kBlue,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        }

        final groups = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: groups.length,
          itemBuilder: (context, i) => _StandingsTable(
            group: groups[i],
            groupIndex: i,
            accentColor: widget.league.accentColor,
          ),
        );
      },
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final ApiStandingGroup group;
  final int groupIndex;
  final Color accentColor;

  const _StandingsTable({
    required this.group,
    required this.groupIndex,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Group label (if multiple groups)
          if (groupIndex > 0 || group.rows.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withOpacity(0.06)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    group.rows.isNotEmpty &&
                            group.rows.first.description != null
                        ? 'Group ${String.fromCharCode(65 + groupIndex)}'
                        : 'Standings',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 26),
                const Expanded(
                  flex: 4,
                  child: Text('Club',
                      style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
                ..._colHeader(['P', 'W', 'D', 'L', 'GD', 'Pts']),
              ],
            ),
          ),

          // Rows
          ...group.rows.map((row) => _StandingRowWidget(
              row: row, accentColor: accentColor)),
        ],
      ),
    );
  }

  List<Widget> _colHeader(List<String> cols) {
    return cols.map((c) => SizedBox(
      width: 28,
      child: Text(c,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    )).toList();
  }
}

class _StandingRowWidget extends StatelessWidget {
  final ApiStandingRow row;
  final Color accentColor;

  const _StandingRowWidget(
      {required this.row, required this.accentColor});

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFB0BEC5);
    if (rank == 3) return const Color(0xFFBCAAA4);
    return Colors.grey.shade700;
  }

  Color? _rowAccentColor() {
    final desc = row.description?.toLowerCase() ?? '';
    if (desc.contains('champions league') ||
        desc.contains('promotion')) {
      return _kGreen;
    }
    if (desc.contains('relegation') || desc.contains('relegation play')) {
      return _kRed;
    }
    if (desc.contains('europa') || desc.contains('play')) {
      return _kAmber;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final rowColor = _rowAccentColor();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: rowColor != null
              ? BorderSide(color: rowColor, width: 3)
              : BorderSide.none,
          top: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 22,
            child: Text('${row.rank}',
                style: TextStyle(
                    color: _rankColor(row.rank),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),

          // Team
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Image.network(row.team.logoUrl,
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.shield_outlined,
                            size: 14, color: Colors.grey)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(row.team.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
          ),

          // Stats
          ...[row.played, row.won, row.drawn, row.lost,
              row.goalDiff, row.points]
              .asMap()
              .entries
              .map((e) => SizedBox(
                    width: 28,
                    child: Text(
                      e.value.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: e.key == 5
                            ? Colors.white
                            : Colors.grey.shade500,
                        fontSize: 11,
                        fontWeight: e.key == 5
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  )),

          // Form
          if (row.form != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(
                children: row.form!
                    .split('')
                    .take(5)
                    .map((c) {
                  Color fc;
                  if (c == 'W') fc = _kGreen;
                  else if (c == 'L') fc = _kRed;
                  else fc = _kAmber;
                  return Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(left: 2),
                    decoration: BoxDecoration(
                      color: fc.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: fc.withOpacity(0.5)),
                    ),
                    child: Center(
                      child: Text(c,
                          style: TextStyle(
                              color: fc,
                              fontSize: 7,
                              fontWeight: FontWeight.w800)),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//   LIVE PULSE INDICATOR
// ════════════════════════════════════════════════════════════════════
class _LivePulse extends StatefulWidget {
  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _kRed.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kRed.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: _kRed, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            const Text('LIVE',
                style: TextStyle(
                    color: _kRed,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}