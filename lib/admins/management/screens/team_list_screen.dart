import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../reusables/constants.dart';
import '../models/team_model.dart';
import '../services/team_service.dart';
import '../reusables/custom_progress_indicator.dart';

class TeamListScreen extends StatefulWidget {
  final TeamService teamService = TeamService();

  TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  final TextEditingController _searchController = TextEditingController();


  final Map<String, String> _coachNameCache = {};
  Future<String?> _getCoachName(String coachId) async {
  // Cache hit
  if (_coachNameCache.containsKey(coachId)) {
    return _coachNameCache[coachId];
  }

  try {
    final doc = await FirebaseFirestore.instance
        .collection('coaches')
        .doc(coachId)
        .get();

    if (!doc.exists) {
      _coachNameCache[coachId] = '—';
      return '—';
    }

    final name = doc.data()?['name'] as String?;
    _coachNameCache[coachId] = name ?? '—';
    return name ?? '—';
  } catch (_) {
    return '—';
  }
}



  final TeamService _teamService = TeamService();
  Timer? _debounce;
  List<Team> _filteredTeams = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() {});
    });
  }

  List<Team> _filterTeams(List<Team> teams, String query) {
    if (query.isEmpty) return teams;

    return teams
        .where(
          (t) => t.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin_panel'),
        ),
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search teams...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: StreamBuilder<List<Team>>(
        stream: widget.teamService.streamTeams(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: AppTextStyles.subheadingStyle,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No teams found',
                style: AppTextStyles.subheadingStyle,
              ),
            );
          }

          final teams = snapshot.data!;
          _filteredTeams = _filterTeams(teams, _searchController.text);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 40,
                columns: const [
                  DataColumn(label: Text('Team Name')),
                  DataColumn(label: Text('Coach')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _filteredTeams.map((team) {
                  return DataRow(
                    cells: [
                      DataCell(Text(team.name)),
                     DataCell(
                              team.coachId == null
                                  ? const Text('—')
                                  : FutureBuilder<String?>(
                                      future: _getCoachName(team.coachId!),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return const Text('Loading...');
                                        }
                                        return Text(snapshot.data ?? '—');
                                      },
                                    ),
                            ),
                     DataCell(
  Row(
    children: [
      IconButton(
        icon: const Icon(Icons.visibility, color: Colors.green),
        tooltip: 'View',
        onPressed: () {
          context.go(
            '/team_details',
            extra: team.id,
          );
        },
      ),
      IconButton(
        icon: const Icon(Icons.edit, color: Colors.blue),
        tooltip: 'Edit',
        onPressed: () {
          context.go('/edit_team/${team.id}');
        },
      ),
      IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        tooltip: 'Delete',
        onPressed: () {
          _confirmDeleteTeam(context, team, _teamService);
        },
      ),
    ],
  ),
),

                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/create_team'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> _confirmDeleteTeam(
  BuildContext context,
  Team team,
  TeamService teamService,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Team'),
      content: Text(
        'Are you sure you want to delete "${team.name}"?\n\n'
        'This will:\n'
        '• Remove the team\n'
        '• Unassign its players\n'
        '• Unassign its coach\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await teamService.deleteTeam(team.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete team: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

