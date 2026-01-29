import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../reusables/constants.dart';
import '../models/coach_model.dart';
import '../services/coach_service.dart';
import '../reusables/custom_progress_indicator.dart';
import '../reusables/custom_dialog.dart';

class CoachListScreen extends StatefulWidget {
  final CoachService coachService = CoachService();

  CoachListScreen({super.key});

  @override
  State<CoachListScreen> createState() => _CoachListScreenState();
}

class _CoachListScreenState extends State<CoachListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Coach> _filteredCoaches = [];

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

  List<Coach> _filterCoaches(List<Coach> coaches, String query) {
    if (query.isEmpty) return coaches;

    return coaches
        .where(
          (c) => c.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  Future<void> _deleteCoach(Coach coach) async {
    final confirm = await CustomDialog.show(
      context,
      title: 'Confirm Delete',
      message: 'Are you sure you want to delete ${coach.name}?',
      type: DialogType.warning,
    );

    if (confirm != true) return;

    try {
      await widget.coachService.deleteCoach(coach.id);

      if (!mounted) return;
      CustomDialog.show(
        context,
        title: 'Deleted',
        message: '${coach.name} has been deleted.',
        type: DialogType.success,
      );
    } catch (e) {
      if (!mounted) return;
      CustomDialog.show(
        context,
        title: 'Error',
        message: 'Failed to delete coach: $e',
        type: DialogType.error,
      );
    }
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
            hintText: 'Search coaches...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
      ),
      body: StreamBuilder<List<Coach>>(
        stream: widget.coachService.streamCoaches(),
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
                'No coaches found',
                style: AppTextStyles.subheadingStyle,
              ),
            );
          }

          final coaches = snapshot.data!;
          _filteredCoaches =
              _filterCoaches(coaches, _searchController.text);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 40,
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Team')),
                  DataColumn(label: Text('Date of Birth')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _filteredCoaches.map((coach) {
                  return DataRow(
                    cells: [
                      DataCell(Text(coach.name)),
                      DataCell(Text(coach.teamName ?? '—')),
                      DataCell(
                        Text(
                          '${coach.dateOfBirth?.day}/${coach.dateOfBirth?.month}/${coach.dateOfBirth?.year}',
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Edit',
                              onPressed: () {
                                // GoRouter-safe (ID only)
                                context.go('/edit_coach/${coach.id}');

                              },
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => _deleteCoach(coach),
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
        onPressed: () => context.go('/create_coach'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: AppColors.whiteColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
