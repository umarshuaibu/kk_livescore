import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kklivescoreadmin/constants/colors.dart';
import 'package:kklivescoreadmin/constants/size.dart';
import 'package:kklivescoreadmin/league_manager/standings/standings_model.dart';
import 'package:kklivescoreadmin/league_manager/standings/standings_service.dart';
import 'group_table.dart';

class StandingsTab extends StatefulWidget {
  final String leagueId;
  const StandingsTab({super.key, required this.leagueId});

  @override
  State<StandingsTab> createState() => _StandingsTabState();
}

class _StandingsTabState extends State<StandingsTab> {
  final StandingsService _service = StandingsService();

  /// Track expanded/collapsed state per group
  final Map<String, bool> _groupExpanded = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _service.streamStandingsQuery(widget.leagueId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading standings'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // Group standings per group
        final Map<String, List<StandingModel>> groups = {};
        for (final d in docs) {
          final s = StandingModel.fromDoc(d);
          groups.putIfAbsent(s.group, () => []).add(s);

          // Initialize expand state if not set
          _groupExpanded.putIfAbsent(s.group, () => true);
        }

        final groupKeys = groups.keys.toList()..sort();

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final groupKey = groupKeys[index];
                    final standings = groups[groupKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // True sticky header using SliverPersistentHeader workaround
                        _StickyHeader(
                          groupKey: groupKey,
                          isExpanded: _groupExpanded[groupKey] ?? true,
                          onTap: () {
                            setState(() {
                              _groupExpanded[groupKey] =
                                  !(_groupExpanded[groupKey] ?? true);
                            });
                          },
                        ),

                        // Only show group table if expanded
                        if (_groupExpanded[groupKey] ?? true)
                          GroupTable(
                            leagueId: widget.leagueId,
                            standings: standings,
                          ),
                          SizedBox(width: eqW(8)),
                      ],
                    );
                  },
                  childCount: groupKeys.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

/// Sticky header widget
class _StickyHeader extends StatelessWidget {
  final String groupKey;
  final bool isExpanded;
  final VoidCallback onTap;

  const _StickyHeader({
    required this.groupKey,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 6.0),
            decoration: BoxDecoration(
         color: kGrey1,
         
              
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
            
              
              
              children: [
                Text(
                  'GROUP $groupKey',
                  style: const TextStyle(
                    color: kPrimaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    //color: Colors.white,
                    color: kPrimaryColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: eqW(8)),
              ],
            ),
          ),
        );
      },
    );
  }
}
