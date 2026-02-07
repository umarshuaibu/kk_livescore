import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/constants/size.dart';
import 'package:kklivescoreadmin/constants/text_styles.dart';

/// MatchesTab
/// - Shows matches grouped by status in this order: Live, Scheduled, Postponed, Completed
/// - Accepts an optional [matchesStream]. If provided, the tab will use that stream.
/// - UI avoids exposing any raw document IDs or technical error messages.
/// - When network/data fails, friendly placeholders are shown instead of IDs or exceptions.
class MatchesTab extends StatefulWidget {
  final String leagueId;
  final Stream<QuerySnapshot>? matchesStream;

  const MatchesTab({
    super.key,
    required this.leagueId,
    this.matchesStream,
  });

  @override
  State<MatchesTab> createState() => _MatchesTabState();
  
}

class _MatchesTabState extends State<MatchesTab> {

  @override
  void initState() {
    super.initState();
    _loadNativeAd(); // ✅ correct place
  }


NativeAd? _nativeAd;
bool _isNativeAdLoaded = false;

void _loadNativeAd() {
  _nativeAd = NativeAd(
    adUnitId: 'ca-app-pub-7769762821516033/6501689818', // TEST
    factoryId: 'listTile',
    request: const AdRequest(),
    listener: NativeAdListener(
      onAdLoaded: (ad) {
        if (!mounted) return;
        setState(() => _isNativeAdLoaded = true);
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        debugPrint('Native ad failed: $error');
      },
    ),
  )..load();
}

@override
void dispose() {
  _nativeAd?.dispose();
  super.dispose();
}


  // Simple in-memory cache for team documents to reduce reads
  final Map<String, Map<String, dynamic>> _teamsCache = {};

  // Ordering for status groups
  final List<String> _statusOrder = ['live', 'scheduled', 'postponed', 'completed'];

  // Date/time formatting
  final DateFormat _dateFmt = DateFormat.yMMMMEEEEd();
  final DateFormat _timeFmt = DateFormat('hh:mm a');

static const int _adInterval = 6;

bool _shouldShowAd(int index) {
  return (index + 1) % _adInterval == 0;
}

  // Helper: get team document (cached)
  Future<Map<String, dynamic>?> _getTeam(String? teamId) async {
    if (teamId == null || teamId.trim().isEmpty) return null;
    if (_teamsCache.containsKey(teamId)) return _teamsCache[teamId];
    try {
      final snap = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>;
      _teamsCache[teamId] = data;
      return data;
    } catch (e) {
      // Log for debugging but do not expose technical details to user.
      debugPrint('Failed to fetch team $teamId: $e');
      return null;
    }
  }

Widget _nativeAdSlot() {
  final ad = NativeAd(
    adUnitId: 'ca-app-pub-3940256099942544/2247696110',
    factoryId: 'listTile',
    request: const AdRequest(),
    listener: NativeAdListener(
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
      },
    ),
  )..load();

  return Container(
    margin: EdgeInsets.symmetric(vertical: eqW(8), horizontal: eqW(6)),
    height: 90,
    decoration: BoxDecoration(
      color: kSecondaryColor,
      borderRadius: BorderRadius.circular(eqW(8)),
    ),
    child: AdWidget(ad: ad),
  );
}


  // Helper: build stream to use (prefer provided matchesStream; otherwise follow spec)
  Stream<QuerySnapshot> get _effectiveStream {
    if (widget.matchesStream != null) return widget.matchesStream!;
    // follows provided Firestore spec: collection name 'league'
    return FirebaseFirestore.instance
        .collection('league')
        .doc(widget.leagueId)
        .collection('matches')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _effectiveStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Friendly error message (no technical details)
          return Center(
            child: Padding(
              padding: EdgeInsets.all(eqW(12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Unable to load matches. Please check your connection and try again.', style: kText12White, textAlign: TextAlign.center),
                  SizedBox(height: eqW(8)),
                  ElevatedButton(
                    onPressed: () {
                      // Trigger rebuild / retry by calling setState
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Convert docs to list of maps with id (do not mutate original doc map)
        final docs = snapshot.data!.docs;
        final List<Map<String, dynamic>> matches = docs.map((d) {
          final raw = d.data() as Map<String, dynamic>? ?? {};
          final m = Map<String, dynamic>.from(raw);
          m['__id'] = d.id; // internal only; never shown in UI
          return m;
        }).toList();

        // Group matches by status
        final Map<String, List<Map<String, dynamic>>> grouped = {};
        for (var s in _statusOrder) grouped[s] = [];
        for (var m in matches) {
          final status = (m['status'] ?? 'scheduled').toString().toLowerCase();
          if (grouped.containsKey(status)) {
            grouped[status]!.add(m);
          } else {
            // unknown statuses go to scheduled bucket
            grouped['scheduled']!.add(m);
          }
        }

        // Sort each group by date ascending (most imminent first)
        for (var k in grouped.keys) {
          grouped[k]!.sort((a, b) {
            final aD = (a['date'] as Timestamp?)?.toDate();
            final bD = (b['date'] as Timestamp?)?.toDate();
            if (aD == null && bD == null) return 0;
            if (aD == null) return 1;
            if (bD == null) return -1;
            return aD.compareTo(bD);
          });
        }

        // Build expansion tiles in required order
        return ListView(
          padding: EdgeInsets.all(eqW(8)),
          children: _statusOrder.map((status) {
            final list = grouped[status]!;
            // Show header count in title
            final title = '${status.toUpperCase()} (${list.length})';
            return _buildStatusSection(status, title, list);
          }).toList(),
        );
      },
    );
  }

  // Build an expandable section for a particular status
  Widget _buildStatusSection(String status, String title, List<Map<String, dynamic>> items) {
    // Live should be expanded by default
    final initiallyExpanded = status == 'live';

    return Container(
      margin: EdgeInsets.symmetric(vertical: eqW(6)),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.symmetric(horizontal: eqW(12), vertical: eqW(8)),
        backgroundColor: kSecondaryColor,
        collapsedBackgroundColor: kSecondaryColor,
        title: Text(
          title,
          style: kText12White.copyWith(fontWeight: FontWeight.w600),
        ),
children: items.isEmpty
    ? [
        Padding(
          padding: EdgeInsets.all(eqW(12)),
          child: Text('No matches', style: kText12White),
        )
      ]
    : List.generate(items.length, (index) {
        final widgets = <Widget>[];

        widgets.add(_buildMatchItem(status, items[index]));

        // Insert native ad at interval
if (_shouldShowAd(index)) {
  widgets.add(_nativeAdSlot());
}



        return Column(
          mainAxisSize: MainAxisSize.min,
          children: widgets,
        );
      }),

      ),
    );
  }

  // Build the UI for each match item according to its status
  Widget _buildMatchItem(String status, Map<String, dynamic> match) {
    final teamAId = match['teamAId']?.toString();
    final teamBId = match['teamBId']?.toString();
    final dateTs = match['date'] as Timestamp?;
    final date = dateTs?.toDate();

    // Common lightweight row that will fetch team docs asynchronously
    return FutureBuilder<List<Map<String, dynamic>?>>(
      future: Future.wait([_getTeam(teamAId), _getTeam(teamBId)]),
      builder: (context, snap) {
        final teamA = (snap.data != null && snap.data!.isNotEmpty) ? snap.data![0] : null;
        final teamB = (snap.data != null && snap.data!.length > 1) ? snap.data![1] : null;

        // Build different layouts per status
        switch (status) {
          case 'scheduled':
            return _scheduledMatchItem(match, teamA, teamB, date);
          case 'postponed':
            return _postponedMatchItem(match, teamA, teamB, date);
          case 'completed':
            return _completedMatchItem(match, teamA, teamB, date);
          case 'live':
            return _liveMatchItem(match, teamA, teamB, date);
          default:
            return _scheduledMatchItem(match, teamA, teamB, date);
        }
      },
    );
  }

  // Scheduled match UI
  Widget _scheduledMatchItem(
    Map<String, dynamic> match,
    Map<String, dynamic>? teamA,
    Map<String, dynamic>? teamB,
    DateTime? date,
  ) {
    return InkWell(
      onTap: () => _openMatchDetails(match),
      child: Container(
        padding: EdgeInsets.all(eqW(10)),
        margin: EdgeInsets.symmetric(vertical: eqW(6), horizontal: eqW(6)),
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(eqW(8)),
        ),
        child: Column(
          children: [
            // Date and time row (centered badges)
            if (date != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _badge(_dateFmt.format(date)),
                  SizedBox(width: eqW(8)),
                  _badge(_timeFmt.format(date)),
                ],
              ),

            // Teams row
            SizedBox(height: eqW(8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _teamCompact(teamA, alignLeft: false),
                Text('vs', style: kText12White),
                _teamCompact(teamB, alignLeft: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Postponed match UI (muted / struck-through look)
  Widget _postponedMatchItem(
    Map<String, dynamic> match,
    Map<String, dynamic>? teamA,
    Map<String, dynamic>? teamB,
    DateTime? date,
  ) {
    final mutedColor = kGrey2;
    return InkWell(
      onTap: () => _openMatchDetails(match),
      child: Container(
        padding: EdgeInsets.all(eqW(10)),
        margin: EdgeInsets.symmetric(vertical: eqW(6), horizontal: eqW(6)),
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(eqW(8)),
        ),
        child: Opacity(
          opacity: 0.6, // muted appearance
          child: Column(
            children: [
              if (date != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_dateFmt.format(date), style: kText12White.copyWith(color: mutedColor)),
                    SizedBox(width: eqW(8)),
                    Text(_timeFmt.format(date), style: kText12White.copyWith(color: mutedColor)),
                  ],
                ),
              SizedBox(height: eqW(6)),

             Row(
  children: [
    // Team A (right-aligned, logo after text)
    Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: _teamCompact(
          teamA,
          alignLeft: false,
        ),
      ),
    ),

    // VS (perfectly centered)
    Padding(
      padding: EdgeInsets.symmetric(horizontal: eqW(12)),
      child: Text('vs', style: kText12White),
    ),

    // Team B (left-aligned, logo before text)
    Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: _teamCompact(
          teamB,
          alignLeft: true,
        ),
      ),
    ),
  ],
),


            ],
          ),
        ),
      ),
    );
  }

  // Completed match UI (show scores + badges)
  Widget _completedMatchItem(
    Map<String, dynamic> match,
    Map<String, dynamic>? teamA,
    Map<String, dynamic>? teamB,
    DateTime? date,
  ) {
    final scoreA = match['scoreA']?.toString() ?? '0';
    final scoreB = match['scoreB']?.toString() ?? '0';
    return InkWell(
      onTap: () => _openMatchDetails(match),
      child: Container(
        padding: EdgeInsets.all(eqW(10)),
        margin: EdgeInsets.symmetric(vertical: eqW(6), horizontal: eqW(6)),
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(eqW(8)),
        ),
        child: Column(
          children: [
            // Main row: teamA - score - teamB
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _teamCompact(teamA, alignLeft: false),
                Text('$scoreA  -  $scoreB', style: kText14White.copyWith(fontWeight: FontWeight.w700)),
                _teamCompact(teamB, alignLeft: true),
              ],
            ),
            SizedBox(height: eqW(8)),
            // Badges row: status, date, time
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _badge((match['status']?.toString() ?? 'completed').toUpperCase()),
                SizedBox(width: eqW(8)),
                if (date != null) _badge(_dateFmt.format(date)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Live match UI (similar to completed, but indicates Live)
  Widget _liveMatchItem(
    Map<String, dynamic> match,
    Map<String, dynamic>? teamA,
    Map<String, dynamic>? teamB,
    DateTime? date,
  ) {
    // Live should show real-time scores (these will update from the stream)
    final scoreA = match['scoreA']?.toString() ?? '0';
    final scoreB = match['scoreB']?.toString() ?? '0';
    return InkWell(
      onTap: () => _openMatchDetails(match, live: true),
      child: Container(
        padding: EdgeInsets.all(eqW(10)),
        margin: EdgeInsets.symmetric(vertical: eqW(6), horizontal: eqW(6)),
        decoration: BoxDecoration(
          color: kPrimaryColor,
          borderRadius: BorderRadius.circular(eqW(8)),
          border: Border.all(color: kMatchTimeColor, width: 1),
        ),
       child: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    /// =========================
    /// TEAMS + SCORE ROW
    /// =========================
    Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _teamCompact(teamA, alignLeft: false),
          ),
        ),

        SizedBox(
          width: eqW(70),
          child: Center(
            child: Text(
              '$scoreA  -  $scoreB',
              style: kText14White.copyWith(
                fontWeight: FontWeight.w700,
                color: kMatchTimeColor,
              ),
            ),
          ),
        ),

        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _teamCompact(teamB, alignLeft: true),
          ),
        ),
      ],
    ),

    SizedBox(height: eqW(8)),

    /// =========================
    /// STATUS / DATE / TIME BADGES
    /// FIXED: Using Wrap instead of Row to prevent overflow
    /// =========================
    Wrap(
      alignment: WrapAlignment.center,
      spacing: eqW(8),      // horizontal space between badges
      runSpacing: eqW(6),   // vertical space if it wraps to next line
      children: [
        _badge(
          'LIVE',
          color: kMatchTimeColor,
        ),

        if (date != null)
          _badge(_dateFmt.format(date)),

        if (date != null)
          _badge(_timeFmt.format(date)),
      ],
    ),
  ],
),

        ),
      );

  }

  // Compact team widget used in list items
  Widget _teamCompact(
    Map<String, dynamic>? team, {
    bool alignLeft = true,
    bool muted = false,
  }) {
    final name = (team != null && (team['abbr']?.toString().trim().isNotEmpty == true)) ? team['abbr'].toString() : 'Team';
    final logo = team?['logoUrl']?.toString();
    final txtStyle = muted ? kText10White.copyWith(color: kGrey2) : kText10White;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (alignLeft) _teamLogo(logo),
        SizedBox(width: eqW(6)),

        ConstrainedBox(
  constraints: BoxConstraints(maxWidth: eqW(90)),
  child: Text(
    name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: txtStyle,
    textAlign: alignLeft ? TextAlign.left : TextAlign.right,
  ),
),


        SizedBox(width: eqW(6)),
        if (!alignLeft) _teamLogo(logo),
      ],
    );
  }

  // team logo widget (small)
  Widget _teamLogo(String? url) {
    return Container(
      width: eqW(24),
      height: eqW(24),
      decoration: BoxDecoration(
        color: kGrey1.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: url == null || url.isEmpty
          ? Icon(Icons.shield, color: kGrey2, size: eqW(16))
          : ClipOval(
              child: Image.network(
                url,
                width: eqW(24),
                height: eqW(24),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.shield, color: kGrey2, size: eqW(16)),
              ),
            ),
    );
  }

  Widget _teamSide({
    required Map<String, dynamic>? team,
    required bool isLeftTeam,
  }) {
    return Align(
      alignment: isLeftTeam ? Alignment.centerRight : Alignment.centerLeft,
      child: _teamCompact(
        team,
        alignLeft: !isLeftTeam,
      ),
    );
  }

  // Small badge
  Widget _badge(String label, {Color? color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: eqW(8), vertical: eqW(4)),
      decoration: BoxDecoration(
        color: color ?? kSecondaryColor,
        borderRadius: BorderRadius.circular(eqW(12)),
      ),
      child: Text(label, style: kText10White),
    );
  }

  // Open match details page. For live matches we open a page that listens to real-time document.
  void _openMatchDetails(Map<String, dynamic> match, {bool live = false}) {
    final matchId = match['__id']?.toString();
    if (matchId == null || matchId.trim().isEmpty) {
      // If for some reason ID is missing, show friendly feedback instead of exposing internal values.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open match details at the moment.')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchDetailsPage(
          leagueId: widget.leagueId,
          matchId: matchId,
          initialMatchData: match,
        ),
      ),
    );
  }

Widget _nativeAdWidget() {
  if (!_isNativeAdLoaded || _nativeAd == null) {
    return const SizedBox.shrink();
  }

  return Container(
    margin: EdgeInsets.symmetric(vertical: eqW(8), horizontal: eqW(6)),
    decoration: BoxDecoration(
      color: kSecondaryColor,
      borderRadius: BorderRadius.circular(eqW(8)),
    ),
    height: 90, // stable height = no layout jump
    child: AdWidget(ad: _nativeAd!),
  );
}


}

/// MatchDetailsPage
/// - Shows the required sections separated by Divider:
///   Teams (names + logos), Group, Match date & time, Match status,
///   and for completed/live matches also show scores, yellow/red cards and substitutions.
/// - Subscribes to the single match document for real-time updates (so Live pages update).
/// - Does not expose sensitive IDs in the UI; uses friendly placeholders when data is missing.
class MatchDetailsPage extends StatefulWidget {
  final String leagueId;
  final String matchId;
  final Map<String, dynamic>? initialMatchData;

  const MatchDetailsPage({
    super.key,
    required this.leagueId,
    required this.matchId,
    this.initialMatchData,
  });

  @override
  State<MatchDetailsPage> createState() => _MatchDetailsPageState();
}

class _MatchDetailsPageState extends State<MatchDetailsPage> {
  Map<String, dynamic>? _teamA;
  Map<String, dynamic>? _teamB;

  late final Stream<DocumentSnapshot> _docStream;

  final DateFormat _dateFmt = DateFormat.yMMMMd();
  final DateFormat _timeFmt = DateFormat('hh:mm a');
  late BannerAd _bannerAd;
  bool _isBannerLoaded = false;


  @override
  void initState() {
    super.initState();
    _docStream = FirebaseFirestore.instance
        .collection('leagues')
        .doc(widget.leagueId)
        .collection('matches')
        .doc(widget.matchId)
        .snapshots();

         _bannerAd = BannerAd(
    adUnitId: 'ca-app-pub-3940256099942544/6300978111', // TEST banner
    size: AdSize.banner,
    request: const AdRequest(),
    listener: BannerAdListener(
      onAdLoaded: (_) {
        if (mounted) {
          setState(() => _isBannerLoaded = true);
        }
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        debugPrint('Match details banner failed: $error');
      },
    ),
  );

  _bannerAd.load();


    final initial = widget.initialMatchData;
    if (initial != null) {
      final a = initial['teamAId']?.toString();
      final b = initial['teamBId']?.toString();
      if (a != null && a.trim().isNotEmpty) {
        _fetchTeam(a).then((v) {
          if (mounted) setState(() => _teamA = v);
        });
      }
      if (b != null && b.trim().isNotEmpty) {
        _fetchTeam(b).then((v) {
          if (mounted) setState(() => _teamB = v);
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchTeam(String id) async {
    if (id.trim().isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance.collection('teams').doc(id).get();
      if (!snap.exists) return null;
      return snap.data() as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to fetch team $id: $e');
      return null;
    }
  }
@override
void dispose() {
  _bannerAd.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _docStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(eqW(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unable to load match details. Please check your connection.',
                      style: kText12White,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: eqW(8)),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
                
              ),
            ),
            
          );
        }

        if (!snap.hasData && widget.initialMatchData == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = (snap.data?.data() as Map<String, dynamic>?) ?? widget.initialMatchData ?? {};
        final teamAId = data['teamAId']?.toString();
        final teamBId = data['teamBId']?.toString();

        if (_teamA == null && teamAId != null && teamAId.trim().isNotEmpty) {
          _fetchTeam(teamAId).then((v) {
            if (mounted) setState(() => _teamA = v);
          });
        }
        if (_teamB == null && teamBId != null && teamBId.trim().isNotEmpty) {
          _fetchTeam(teamBId).then((v) {
            if (mounted) setState(() => _teamB = v);
          });
        }

        final status = (data['status']?.toString() ?? 'scheduled').toLowerCase();
        final date = (data['date'] as Timestamp?)?.toDate();

        return Scaffold(
          backgroundColor: kSecondaryColor,
          appBar: AppBar(
            title: const Text('Match Details'),
            backgroundColor: kPrimaryColor,
            foregroundColor: kWhiteColor,
          ),
          body: ListView(
            padding: EdgeInsets.all(eqW(12)),
            children: [
              /// TEAMS ROW (FIXED — NO OVERFLOW)
              Container(
                padding: EdgeInsets.all(eqW(10)),
                decoration: BoxDecoration(
                  color: kSecondaryColor,
                  borderRadius: BorderRadius.circular(eqW(6)),
                ),
                child: Row(
                  children: [
                    Expanded(child: _teamDetail(_teamA, alignRight: false)),
                    SizedBox(width: eqW(8)),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('VS', style: kText14White),
                        if (date != null)
                          Text(_timeFmt.format(date), style: kText10MatchTime),
                      ],
                    ),
                    SizedBox(width: eqW(8)),
                    Expanded(child: _teamDetail(_teamB, alignRight: true)),
                  ],
                ),
              ),

              SizedBox(height: eqW(12)),
              Divider(color: kGrey1),

              ListTile(
                dense: true,
                title: Text('Group', style: kText12White),
                subtitle: Text(data['group']?.toString() ?? '-', style: kText12White),
              ),
              Divider(color: kGrey1),

              ListTile(
                dense: true,
                title: Text('Date & Time', style: kText12White),
                subtitle: Text(
                  date != null ? '${_dateFmt.format(date)} • ${_timeFmt.format(date)}' : '-',
                  style: kText12White,
                ),
              ),
              Divider(color: kGrey1),

              ListTile(
                dense: true,
                title: Text('Status', style: kText12White),
                subtitle: Text(status.toUpperCase(), style: kText12White),
              ),
              Divider(color: kGrey1),

              if (status == 'completed' || status == 'live') ...[
                ListTile(
                  dense: true,
                  title: Text('Scores', style: kText12White),
                  subtitle: Text(
                    '${data['scoreA'] ?? '0'}  -  ${data['scoreB'] ?? '0'}',
                    style: kText14White,
                  ),
                ),
                Divider(color: kGrey1),
                ListTile(
                  dense: true,
                  title: Text('Yellow Cards', style: kText12White),
                  subtitle: Text('Coming soon', style: kText10GreyR),
                ),
                Divider(color: kGrey1),
                ListTile(
                  dense: true,
                  title: Text('Red Cards', style: kText12White),
                  subtitle: Text('Coming soon', style: kText10GreyR),
                ),
                Divider(color: kGrey1),
                ListTile(
                  dense: true,
                  title: Text('Substitutions', style: kText12White),
                  subtitle: Text('Coming soon', style: kText10GreyR),
                ),
                Divider(color: kGrey1),
              ] else ...[
                ListTile(
                  dense: true,
                  title: Text('Team Statistics (summary)', style: kText12White),
                  subtitle: Text('Coming soon', style: kText12White),
                ),
                Divider(color: kGrey1),
              ],
            ],
          ),
            bottomNavigationBar: _isBannerLoaded
      ? SizedBox(
          height: _bannerAd.size.height.toDouble(),
          width: _bannerAd.size.width.toDouble(),
          child: AdWidget(ad: _bannerAd),
        )
      : null,
        );
      },
    );
  }

  /// SAFE TEAM WIDGET (NO OVERFLOW)
  Widget _teamDetail(Map<String, dynamic>? team, {required bool alignRight}) {
    final name = team?['name']?.toString().trim().isNotEmpty == true
        ? team!['name'].toString()
        : 'Team';
    final logo = team?['logoUrl']?.toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          width: eqW(56),
          height: eqW(56),
          decoration: BoxDecoration(
            color: kSecondaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(eqW(8)),
          ),
          child: logo == null || logo.isEmpty
              ? Icon(Icons.shield, color: kGrey1)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(eqW(8)),
                  child: Image.network(
                    logo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.shield, color: kGrey1),
                  ),
                ),
        ),
        SizedBox(height: eqW(6)),
        Text(
          name,
          style: kText12White,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    
  }
  

}
